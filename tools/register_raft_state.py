import hashlib,json,pathlib
root=pathlib.Path(__file__).resolve().parents[1];p=root/'assets/manifest.json'
m=json.loads(p.read_text(encoding='utf-8'));file='presentation/raft_state_models.gd'
m['assets']['model.raft-state']={'path':'res://'+file,'source':['asset-sources/raft-blender-v1/raft_modules_v005.blend',file],'version':5,'sha256':hashlib.sha256((root/file).read_bytes()).hexdigest(),'dependencies':['shader.raft.wet-wood']+['model.raft.module.'+n for n in ['deck-intact','deck-damaged','deck-intact-2','deck-intact-3','deck-damaged-2','deck-damaged-3','root-decor','lamp','filter','planter','medkit','crossbow','spearRack']],'license':'project-authored Blender meshes; source raft_v005.blend reuse; runtime instantiation only','coordinates':'Godot metres, Y up; one cell 2.35 x 2.1; geometry owned by VoyageWorld cache','mapping':'cell.id/x/y/status + equipment.id/level/fuel; detached omitted, damaged retained and disabled','visual_random':'Blender local seed 5100; coordinate variant (x+2*y)%3; independent of game RNG','decorative_root':'new layout x=0,1 y=0; four playable cells at 3,4,5,6; expanded legacy saves retain left-side root'}
from register_planter_model import register
register(m)
p.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
