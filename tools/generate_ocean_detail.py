"""Bake periodic mathematical signals into a replaceable RGBA water-detail asset.
R: broken directional curves; G: pore/grain field; B/A: fine slope U/V.
Independent NumPy PCG64 visual seed, no game random state or external artwork.
"""
import hashlib,json,pathlib
import numpy as np
from PIL import Image
root=pathlib.Path(__file__).resolve().parents[1];size=256;seed=20261013
rng=np.random.default_rng(seed)
def noise(cutoff):
    f=np.fft.fftfreq(size)*size;radius=np.hypot(f[:,None],f[None,:])
    s=np.fft.ifft2(np.fft.fft2(rng.normal(size=(size,size)))*np.exp(-(radius/cutoff)**2)*np.minimum(radius,1)).real
    return s/np.std(s)
y,x=np.mgrid[:size,:size]/size
coarse=noise(5);fine=noise(18)
phase=y*7+.18*np.sin(x*np.pi*4)+.07*coarse
line=np.clip((np.sin(phase*np.pi*2)-.86)/.14,0,1)
gate=np.clip(.55+noise(3)*.35,0,1)
flow=line*gate
pore=np.clip(.5+coarse*.13+fine*.055,0,1)
height=fine*.5+coarse*.15
dx=(np.roll(height,-1,1)-np.roll(height,1,1))*.9
dy=(np.roll(height,-1,0)-np.roll(height,1,0))*.9
rgba=np.stack([flow,pore,np.clip(.5+dx,0,1),np.clip(.5+dy,0,1)],axis=-1)
p=root/'assets/textures/ocean-detail-v1.png';Image.fromarray(np.uint8(rgba*255),'RGBA').save(p)
manifest_path=root/'assets/manifest.json';manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['assets']['texture.ocean.detail']={'path':'res://assets/textures/ocean-detail-v1.png','version':1,
    'source':'tools/generate_ocean_detail.py','sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
    'dimensions':[size,size],'crop':None,'dependencies':[],'visual_seed':seed,
    'channels':{'R':'broken flow curves','G':'foam pore/grain','B':'micro slope U','A':'micro slope V'},
    'license':'project-authored mathematical signals; no external images'}
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('DETAIL ASSET: 256x256 RGBA periodic signals, seed',seed,'bytes',p.stat().st_size)
