"""Deterministic PBR bitmap sources; no downloads or gameplay RNG."""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/textures/planter-v3'


def generate():
    OUT.mkdir(parents=True,exist_ok=True)
    rng = np.random.default_rng(31527)
    size = 512
    y,x = np.mgrid[0:1:complex(size),0:1:complex(size)]
    def noise(scale):
        a = (rng.random((scale,scale))*255).astype('uint8')
        return np.asarray(Image.fromarray(a).resize((size,size),Image.Resampling.BICUBIC))/255-.5
    warp = x + .013*np.sin(y*17+x*9)+.008*np.sin(y*39+x*14)
    grain = .5+.5*np.sin(warp*220 + 2*np.sin(warp*49))
    fiber = np.power(.5+.5*np.sin(warp*610 + y*5),10)
    broad = .6*noise(9)+.22*noise(30)
    height = .52+.15*grain-.10*fiber+.08*broad
    shade = .93+.13*grain-.13*fiber+.25*broad+.025*noise(256)
    for cx,cy in [(.29,.31),(.75,.72)]:
        r = np.sqrt(((x-cx)/.075)**2+((y-cy)/.18)**2)
        knot = np.exp(-r*r*.8)
        shade -= .14*knot*(.6+.4*np.sin(r*17))
        height -= .06*knot
    wood = np.clip(shade[...,None]*np.array([141,105,68])[None,None,:],0,255)
    soil_height = .5+.36*noise(24)+.22*noise(75)+.12*noise(256)
    grit = noise(256)
    soil = np.clip((.75+.7*soil_height+.12*grit)[...,None]*np.array([67,43,26])[None,None,:],0,255)
    def save(name, data):
        Image.fromarray(np.clip(data,0,255).astype('uint8')).save(OUT/(name+'.png'))
    def normal(h,strength):
        dy,dx = np.gradient(h)
        n = np.stack((-dx*strength,-dy*strength,np.ones_like(h)),axis=2)
        n /= np.linalg.norm(n,axis=2,keepdims=True)
        return (n*.5+.5)*255
    save('wood-albedo',wood); save('wood-roughness',207+22*grain+12*broad)
    save('wood-normal',normal(height,32))
    save('soil-albedo',soil); save('soil-roughness',235+15*grit)
    save('soil-normal',normal(soil_height,14))
    print('PLANTER TEXTURES: 6 deterministic 512x512 PNGs, seed 31527')


if __name__ == '__main__': generate()
