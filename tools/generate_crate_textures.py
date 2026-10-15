"""Authored weathered timber PBR bitmaps, fixed visual seed 35104."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/textures/wooden-crate-v1'
def generate():
    OUT.mkdir(parents=True,exist_ok=True)
    rng=np.random.default_rng(35104); n=512
    y,x=np.mgrid[0:1:complex(n),0:1:complex(n)]
    def noise(size):
        return np.asarray(Image.fromarray((rng.random((size,size))*255).astype('uint8')).resize((n,n),Image.Resampling.BICUBIC))/255-.5
    coarse=noise(12); fine=noise(100)
    fibers=np.asarray(Image.fromarray((rng.random((200,8))*255).astype('uint8')).resize((n,n),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(.65)))/255-.5
    warp=y+.006*np.sin(x*9+y*7)+.004*np.sin(x*19+y*12)+.01*noise(5)
    lines=(.5+.5*np.sin(warp*170+1.2*np.sin(warp*37)))**3
    value=1.0-.09*lines+.18*fibers+.24*coarse+.025*fine
    height=.55-.035*lines+.035*fibers+.04*coarse
    for cx,cy in [(.23,.34),(.77,.71)]:
        radius=np.sqrt(((x-cx)/.14)**2+((y-cy)/.045)**2)
        mask=np.exp(-radius*radius*.6)
        value-=.20*mask*(.65+.35*np.sin(radius*18));height-=.055*mask
    # Sparse, directional cracks, avoiding a uniform striped plastic look.
    for cx,cy,length in [(.43,.18,.18),(.66,.52,.24),(.12,.89,.16)]:
        distance=y-cy-.003*np.sin((x-cx)*40)
        crack=np.exp(-(distance/.0018)**2)*np.exp(-((x-cx)/length)**8)
        value-=.18*crack; height-=.025*crack
    def save(name,a):Image.fromarray(np.clip(a,0,255).astype('uint8')).save(OUT/(name+'.png'))
    for name,color in [('wood-albedo',[139,102,65]),('wood-dark-albedo',[113,83,54]),('wood-grey-albedo',[141,122,94])]:
        save(name,value[...,None]*np.array(color)[None,None,:])
    save('wood-roughness',211+18*coarse+16*lines)
    dy,dx=np.gradient(height); normal=np.stack((-dx*14,-dy*14,np.ones_like(x)),axis=2)
    normal/=np.linalg.norm(normal,axis=2,keepdims=True)
    save('wood-normal',(normal*.5+.5)*255)
    print('CRATE TEXTURES: 5 x 512 PNG, visual seed 35104')
if __name__=='__main__':generate()
