"""Register exact user-supplied wood maps, new exports and extracted images."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE_NAMES={'shieldRack':'codex-clipboard-7561b5b3-a303-4a45-b14c-62b6d840cb1d.png',
 'generator':'codex-clipboard-9c868ac2-1b59-4e5a-a7cc-8e6891a3941f.png',
 'fishingNet':'codex-clipboard-ed90a699-225c-46e1-b9f2-fc4e39ba55f0.png',
 'crate':'codex-clipboard-7eef2b67-668b-44f2-aa62-18915d63f945.png',
 'planter':'codex-clipboard-869670b9-78f1-4a4f-886e-18b61ccbf30f.png'}
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def entry(path,source,version,deps,**more):
 return {'path':'res://'+path.relative_to(ROOT).as_posix(),'source':source,'version':version,'sha256':digest(path),
         'dependencies':deps,'license':'user-provided texture; project-authored model',**more}
def register(manifest):
 assets=manifest['assets'];user_textures={}
 for key,original_name in SOURCE_NAMES.items():
  path=ROOT/'assets/textures/stylized-wood-user-v2'/f'wood-{key}-albedo.png'
  assert Image.open(path).size==(1254,1254)
  tid='texture.user-wood-v2.'+key
  assets[tid]=entry(path,'user attachment '+original_name+'; byte-identical copy',2,[],
    dimensions=list(Image.open(path).size),color_space='sRGB',processing='original PNG pixels; no resizing, recoloring, filtering, or compression')
  user_textures[key]=tid
 def imported(model,key,path,filename,version):
  found=path.parent/(path.stem+'_wood-'+key+'-albedo.png')
  assert found.exists(),('Godot did not extract embedded source texture',found)
  tid='texture.imported.user-wood-v2.'+model
  assets[tid]=entry(found,'Godot GLB embedded-image extraction '+path.relative_to(ROOT).as_posix(),version,[user_textures[key]],
    dimensions=list(Image.open(found).size),color_space='sRGB')
  return tid
 def model(model_id,source_name,category,path,version):
  tid=user_textures[category];derived=imported(model_id,category,path,source_name,version)
  deps=[tid,derived]
  if category=='planter':deps += ['texture.raft.planter.soil-'+s for s in ['albedo','roughness','normal']]
  assets[model_id].update({'path':'res://'+path.relative_to(ROOT).as_posix(),
    'source':'asset-sources/stylized-wood-user-v2/'+source_name,'version':version,'sha256':digest(path),
    'dependencies':deps,'texture_style':'user-supplied warm hand-painted wave grain; exact source pixels; roughness 0.90',
    'license':'project-authored geometry; user-provided wood albedo','generator':'tools/apply_user_wood_v2.py'})
  return deps
 model('model.prop.wooden-crate','wooden_crate_v003.blend','crate',ROOT/'assets/models/props/wooden-crate.glb',3)
 model('model.raft.module.planter','planter_v005.blend','planter',ROOT/'assets/models/raft-modules/planter.glb',5)
 model('model.raft.module.planter-seedling','planter_v005.blend','planter',ROOT/'assets/models/raft-modules/planter-seedling.glb',5)
 for key in ['shieldRack','generator','fishingNet']:
  model('model.raft.module.'+key,key+'_v002.blend',key,ROOT/'assets/models/raft-modules'/f'{key}.glb',2)
 wrapper=ROOT/'assets/models/props/storage-crate-module.tscn';crate=assets['model.prop.wooden-crate']
 assets['model.raft.module.crate'].update({'source':['asset-sources/stylized-wood-user-v2/wooden_crate_v003.blend','assets/models/props/storage-crate-module.tscn'],
   'version':2,'dependencies':['model.prop.wooden-crate'],'sha256':digest(wrapper)})
 root_state=assets.get('model.raft-state')
 if root_state:
  sources=root_state.setdefault('source',[])
  if isinstance(sources,str):root_state['source']=[sources]
  if 'asset-sources/stylized-wood-user-v2/planter_v005.blend' not in root_state['source']:
   root_state['source'].insert(0,'asset-sources/stylized-wood-user-v2/planter_v005.blend')
  root_state['wood_texture_version']=2
 for name in ['apply_user_wood_v2','register_user_wood_v2']:
  path=ROOT/'tools'/f'{name}.py'
  assets['factory.wood.user-v2.'+name]={'path':'res://'+path.relative_to(ROOT).as_posix(),
   'source':'project-authored material application and provenance tooling','version':2,
   'sha256':digest(path),'dependencies':[],'status':'offline-asset-pipeline','license':'project-authored'}
 # Remove stale extraction entries from the replaced live models; original v1
 # texture sources remain in their own source folder and manifest entries.
 for tid in list(assets):
  if tid.startswith(('texture.prop.crate.imported.wood-','texture.raft.planter.imported.planter.wood-',
                     'texture.raft.planter.imported.planter-seedling.wood-', 'texture.raft.equipment.imported.')):
   assets.pop(tid,None)
if __name__=='__main__':
 path=ROOT/'assets/manifest.json';manifest=json.loads(path.read_text(encoding='utf-8'));register(manifest)
 newline='\r\n' if b'\r\n' in path.read_bytes() else '\n'
 path.write_bytes((json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').replace('\n',newline).encode('utf-8'))
