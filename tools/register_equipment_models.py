"""Register staged art and import derivatives without changing gameplay factories."""
import json, hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def register(manifest):
    assets=manifest['assets']
    for key in ['shieldRack','generator','fishingNet']:
        path=ROOT/'assets/models/raft-modules'/f'{key}.glb'
        newer=ROOT/'asset-sources/stylized-wood-user-v2'/f'{key}_v002.blend'
        if newer.exists():
            model_key='model.raft.module.'+key
            deps=['texture.user-wood-v2.'+key]
            derived='texture.imported.user-wood-v2.'+model_key
            if derived in assets:deps.append(derived)
            assets[model_key].update({'path':'res://'+path.relative_to(ROOT).as_posix(),
              'source':'asset-sources/stylized-wood-user-v2/'+key+'_v002.blend','version':2,
              'sha256':sha(path),'dependencies':deps,'texture_style':'user-provided hand-painted '+key+' wood, roughness 0.90',
              'generator':'tools/apply_user_wood_v2.py'})
            continue
        deps=['texture.shared.stylized-wood.'+c+'-albedo' for c in ['warm','dark','grey']]
        for color in ['warm','dark','grey']:
            image=path.parent/(key+'_wood-'+color+'-albedo.png')
            if not image.exists():continue
            image_key='texture.raft.equipment.imported.'+key+'.wood-'+color+'-albedo'
            assets[image_key]={'path':'res://'+image.relative_to(ROOT).as_posix(),'version':1,'sha256':sha(image),
              'source':'Godot glTF embedded-image extraction: '+path.relative_to(ROOT).as_posix(),
              'dimensions':list(Image.open(image).size),'dependencies':['texture.shared.stylized-wood.'+color+'-albedo'],
              'license':'AI-generated image import derivative'}
            deps.append(image_key)
        assets['model.raft.module.'+key]={'path':'res://'+path.relative_to(ROOT).as_posix(),
          'source':'asset-sources/equipment-models-v1/'+key+'_v001.blend','version':1,'sha256':sha(path),
          'generator':['tools/build_equipment_set.py','tools/equipment_model_lib.py'],'dependencies':deps,
          'status':'staged-not-integrated','runtime_mapping':'AssetCatalog lookup and tests/equipment_models_visual.gd only; no gameplay equipment mapping',
          'license':'project-authored geometry; AI-generated shared hand-painted wood albedo'}
    crate=assets['model.prop.wooden-crate']
    wrapper=ROOT/'assets/models/props/storage-crate-module.tscn'
    assets['model.raft.module.crate']={'path':'res://'+wrapper.relative_to(ROOT).as_posix(),
      'source':[crate['source'],'assets/models/props/storage-crate-module.tscn'],'version':1,
      'sha256':sha(wrapper),'dependencies':['model.prop.wooden-crate'],'status':'staged-not-integrated',
      'runtime_mapping':'crate content ID; shared original GLB raised 0.17m to deck; visual fixture verified, gameplay rules unchanged','license':crate['license']}
    if (ROOT/'asset-sources/stylized-wood-user-v2/wooden_crate_v003.blend').exists():
        assets['model.raft.module.crate'].update({'source':['asset-sources/stylized-wood-user-v2/wooden_crate_v003.blend','assets/models/props/storage-crate-module.tscn'],
          'version':2,'dependencies':['model.prop.wooden-crate']})
    assets.pop('model.raft.module.storageBox',None)
    for name in ['build_equipment_set','equipment_model_lib']:
        path=ROOT/'tools'/f'{name}.py'
        assets['factory.raft.equipment.'+name]={'path':'res://'+path.relative_to(ROOT).as_posix(),'source':'project-authored Blender Python',
          'version':1,'sha256':sha(path),'dependencies':[],'status':'offline-generator','license':'project-authored'}
if __name__=='__main__':
    path=ROOT/'assets/manifest.json';manifest=json.loads(path.read_text(encoding='utf-8'));register(manifest)
    # Preserve the existing manifest's newline convention.
    newline='\r\n' if b'\r\n' in path.read_bytes() else '\n'
    path.write_bytes((json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').replace('\n',newline).encode('utf-8'))
