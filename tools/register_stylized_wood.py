"""Register imagegen wood and versioned material-only exports; preserve other assets."""
import hashlib
import json
import struct
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
def register(manifest):
    if not (ROOT/'asset-sources/planter-v4/planter_v004.blend').exists():return
    assets=manifest['assets'];textures=[]
    for color in ['warm','dark','grey']:
        p=ROOT/'assets/textures/stylized-wood-v1'/('wood-'+color+'-albedo.png')
        key='texture.shared.stylized-wood.'+color+'-albedo';textures.append(key)
        assets[key]={'path':'res://'+p.relative_to(ROOT).as_posix(),'source':'asset-sources/stylized-wood-v1/generation.json',
            'version':1,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'dimensions':list(Image.open(p).size),
            'dependencies':[],'provider':'built-in image_gen, hand-painted style-transfer','color_space':'sRGB',
            'license':'AI-generated for this project','processing':'original generated pixels; UV rotation/crop only, no raster edits'}
    sources=[('model.prop.wooden-crate','props/wooden-crate.glb','wooden-crate-v2/wooden_crate_v002.blend',2),
             ('model.raft.module.planter','raft-modules/planter.glb','planter-v4/planter_v004.blend',4),
             ('model.raft.module.planter-seedling','raft-modules/planter-seedling.glb','planter-v4/planter_v004.blend',4)]
    for key,relative,source,version in sources:
        p=ROOT/'assets/models'/relative;deps=textures.copy()
        data=p.read_bytes();length=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+length])
        assert all(m['name'].startswith('MAT-StylizedWood-') for m in doc['materials'] if 'Wood' in m['name']), 'Run apply_stylized_wood.py before registering newer wood sources'
        if 'planter' in key:deps += ['texture.raft.planter.soil-'+s for s in ['albedo','roughness','normal']]
        prefix='texture.prop.crate.imported.' if 'crate' in key else 'texture.raft.planter.imported.'+p.stem+'.'
        for color in ['warm','dark','grey']:
            image=p.parent/(p.stem+'_wood-'+color+'-albedo.png')
            if not image.exists():continue
            image_key=prefix+'wood-'+color+'-albedo'
            assets[image_key]={'path':'res://'+image.relative_to(ROOT).as_posix(),
                'source':'Godot glTF embedded-image extraction: '+p.relative_to(ROOT).as_posix(),
                'version':version,'sha256':hashlib.sha256(image.read_bytes()).hexdigest(),
                'dimensions':list(Image.open(image).size),'color_space':'sRGB',
                'dependencies':['texture.shared.stylized-wood.'+color+'-albedo'],'license':'AI-generated image import derivative'}
            deps.append(image_key)
        entry=assets.setdefault(key,{})
        entry.update({'path':'res://'+p.relative_to(ROOT).as_posix(),'source':'asset-sources/'+source,
            'version':version,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'dependencies':deps,
            'generator':'tools/apply_stylized_wood.py','wood_style':'imagegen hand-painted, warm/dark/grey, roughness 0.90, no photographic micro-normal',
            'license':'project-authored geometry; AI-generated hand-painted wood albedo'})
        if 'crate' in key:entry['status']='staged-not-integrated'
    entry=assets.get('model.raft-state')
    if entry:
        entry['version']=max(8,int(entry.get('version',0)))
        source='asset-sources/planter-v4/planter_v004.blend'
        if source not in entry['source']:entry['source'].insert(0,source)
        entry['wood_style']='shared imagegen hand-painted wood; planter geometry and production mapping unchanged'
    # Once v2 GLBs and Godot-extracted images exist, keep the user-provided
    # textures as the current mappings after this legacy material registrar.
    v2=ROOT/'asset-sources/stylized-wood-user-v2/planter_v005.blend'
    if v2.exists() and (ROOT/'assets/models/raft-modules/planter_wood-planter-albedo.png').exists():
        try:
            from register_user_wood_v2 import register as register_user_wood
        except ModuleNotFoundError:
            from tools.register_user_wood_v2 import register as register_user_wood
        register_user_wood(manifest)

if __name__=='__main__':
    path=ROOT/'assets/manifest.json';manifest=json.loads(path.read_text(encoding='utf-8'));register(manifest)
    path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
