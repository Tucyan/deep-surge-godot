"""Technical contact sheets of untouched Godot captures for model review."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
keys=[('shieldRack','盾架'),('generator','发电机'),('fishingNet','捕捞网'),('crate','箱子（复用现有模型）')]
def sheet(name,views):
    w,h=550,430
    out=Image.new('RGB',(w*2,h*((len(keys)*len(views)+1)//2)),(48,60,67));draw=ImageDraw.Draw(out)
    for i,(key,label,view) in enumerate((k,l,v) for k,l in keys for v in views):
        source=Image.open(ROOT/'evidence'/f'equipment-v1-{key}-{view}.png').convert('RGB')
        source.thumbnail((w,400),Image.Resampling.LANCZOS)
        x=(i%2)*w;y=(i//2)*h
        out.paste(source,(x+(w-source.width)//2,y+30))
        draw.text((x+18,y+5),label+(' / '+view if view!='front' else ''),font=font,fill=(229,216,186))
    out.save(ROOT/'evidence'/f'equipment-v1-{name}.png')
sheet('overview',['front'])
sheet('qa',['back','top','bottom'])
print('EQUIPMENT CONTACT SHEETS: written from unaltered Godot renders')
