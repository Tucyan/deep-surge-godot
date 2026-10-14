import json,pathlib,hashlib
root=pathlib.Path('.');p=root/'assets/manifest.json';m=json.loads(p.read_text(encoding='utf-8'))
for file in (root/'assets/models/raft-modules').glob('*.glb'):
 m['assets']['model.raft.module.'+file.stem]={'path':'res://'+file.as_posix(),'source':'asset-sources/raft-blender-v1/raft_modules_v005.blend','version':5 if file.stem=='root-decor' or file.stem.startswith('deck-') else 1,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'dependencies':[],'license':'project-authored Blender meshes; canopy/lamp/planter reused from original raft_v005.blend','units':'metres, Godot Y-up, module-local origin'}
p.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
