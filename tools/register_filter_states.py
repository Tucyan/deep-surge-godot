"""Register only filter variants and their runtime visual mapping."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def register(manifest):
    source='asset-sources/filter-states-v1/filter_states_v001.blend'
    if not (ROOT/source).exists(): return
    for filename,stage in [('filter','ready'),('filter-waiting','waiting')]:
        p=ROOT/'assets/models/raft-modules'/(filename+'.glb')
        manifest['assets']['model.raft.module.'+filename]={
            'path':'res://'+p.relative_to(ROOT).as_posix(),'source':source,'version':2,
            'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'dependencies':[],
            'generator':'tools/refine_filter_states.py','production_stage':stage,
            'license':'project-authored; preserved v005 filter frame/tank with open receiving bucket',
            'units':'metres, Godot Y-up; bucket bottom .325, rim .59; ready water .552',
        }
    entry=manifest['assets'].get('model.raft-state')
    if entry:
        entry['sha256']=hashlib.sha256((ROOT/'presentation/raft_state_models.gd').read_bytes()).hexdigest()
        entry['version']=max(7,int(entry.get('version',0)))
        if source not in entry['source']: entry['source'].append(source)
        if 'model.raft.module.filter-waiting' not in entry['dependencies']: entry['dependencies'].append('model.raft.module.filter-waiting')
        entry['filter_mapping']='level 1 progress=0: waiting empty bucket; level 1 progress>=1 and all level 2/3: ready water, due to produce this voyage. Damaged retained, disabled.'

if __name__=='__main__':
    path=ROOT/'assets/manifest.json'; manifest=json.loads(path.read_text(encoding='utf-8'))
    register(manifest)
    path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
