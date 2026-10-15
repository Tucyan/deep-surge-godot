"""Keep the independent planter source mapping when registering raft assets."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def register(manifest):
    v3 = ROOT/'asset-sources/planter-v3/planter_v003.blend'
    if v3.exists():
        dependencies = []
        for kind in ['wood','soil']:
            for suffix in ['albedo','roughness','normal']:
                file = ROOT/'assets/textures/planter-v3'/(kind+'-'+suffix+'.png')
                asset_id = 'texture.raft.planter.'+kind+'-'+suffix
                dependencies.append(asset_id)
                manifest['assets'][asset_id] = {
                    'path':'res://'+file.relative_to(ROOT).as_posix(),
                    'source':'tools/generate_planter_textures.py','version':1,
                    'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),
                    'dimensions':[512,512], 'dependencies':[],
                    'license':'project-authored deterministic procedural bitmap',
                    'visual_seed':31527,'color_space':'sRGB' if suffix=='albedo' else 'Non-Color',
                }
        for name,stage in [('planter','mature'),('planter-seedling','seedling')]:
            file = ROOT/'assets/models/raft-modules'/(name+'.glb')
            manifest['assets']['model.raft.module.'+name] = {
                'path':'res://'+file.relative_to(ROOT).as_posix(),
                'source':'asset-sources/planter-v3/planter_v003.blend','version':3,
                'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),
                'dependencies':dependencies.copy(),'growth_stage':stage,
                'generator':'tools/refine_planter_v3.py',
                'license':'project-authored, original raft_v004 planter with new seedling mesh',
                'units':'metres, Y up, base y=0.18; box footprint 1.19 x 0.89',
            }
        entry = manifest['assets'].get('model.raft-state')
        if entry:
            entry['sha256'] = hashlib.sha256((ROOT/'presentation/raft_state_models.gd').read_bytes()).hexdigest()
            entry['version'] = max(6,int(entry.get('version',0)))
            entry['source'] = ['asset-sources/planter-v3/planter_v003.blend','asset-sources/raft-blender-v1/raft_modules_v005.blend','presentation/raft_state_models.gd']
            if 'model.raft.module.planter-seedling' not in entry['dependencies']: entry['dependencies'].append('model.raft.module.planter-seedling')
            entry['planter_mapping'] = 'Only level 1 with progress=0 is seedling; level 1 progress>=1 and all level 2/3 are mature (due to produce this voyage). Damaged retains shape, disabled.'
        from register_filter_states import register as register_filter
        register_filter(manifest)
        return
    source = ROOT/'asset-sources/planter-v2/planter_v002.blend'
    if not source.exists():
        return
    file = ROOT/'assets/models/raft-modules/planter.glb'
    manifest['assets']['model.raft.module.planter'] = {
        'path': 'res://assets/models/raft-modules/planter.glb',
        'source': 'asset-sources/planter-v2/planter_v002.blend',
        'version': 2, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(),
        'dependencies': [],
        'license': 'project-authored; original raft-model/raft_v004.blend planter parts',
        'generator': 'tools/rebuild_planter.py',
        'units': 'metres, Godot Y-up; base y=0.18; footprint 1.19 x 0.89',
    }


if __name__ == '__main__':
    path = ROOT/'assets/manifest.json'
    manifest = json.loads(path.read_text(encoding='utf-8'))
    register(manifest)
    path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
