"""Register unified raft weathered wood texture, model exports and extracted images."""
import hashlib, json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def entry(path, source, version, deps, **more):
    return {
        'path': 'res://' + path.relative_to(ROOT).as_posix(),
        'source': source,
        'version': version,
        'sha256': digest(path),
        'dependencies': deps,
        'license': 'project-authored procedural weathered timber; unified with raft',
        **more
    }

def register(manifest):
    assets = manifest['assets']
    tex_path = ROOT / 'assets/textures/raft-wood/weathered_wood_albedo.png'
    assert Image.open(tex_path).size == (768, 768)
    shared_tid = 'texture.shared.raft-wood'
    assets[shared_tid] = entry(
        tex_path,
        'raft-model/textures/weathered_wood_albedo.png; byte-identical copy',
        1,
        [],
        dimensions=list(Image.open(tex_path).size),
        color_space='sRGB',
        processing='authentic raft weathered wood map; 768x768 sRGB'
    )

    def imported(model_id, path, version):
        found = path.parent / (path.stem + '_weathered_wood_albedo.png')
        assert found.exists(), ('Godot did not extract embedded source texture', found)
        tid = 'texture.imported.raft-wood.' + model_id
        assets[tid] = entry(
            found,
            'Godot GLB embedded-image extraction ' + path.relative_to(ROOT).as_posix(),
            version,
            [shared_tid],
            dimensions=list(Image.open(found).size),
            color_space='sRGB'
        )
        return tid

    def model(model_id, source_name, category, path, version):
        derived = imported(model_id, path, version)
        deps = [shared_tid, derived]
        if category == 'planter':
            deps += ['texture.raft.planter.soil-' + s for s in ['albedo', 'roughness', 'normal']]
        assets[model_id].update({
            'path': 'res://' + path.relative_to(ROOT).as_posix(),
            'source': 'asset-sources/raft-wood-unified-v1/' + source_name,
            'version': version,
            'sha256': digest(path),
            'dependencies': deps,
            'texture_style': 'unified raft weathered wood; exact weathered_wood_albedo; roughness 0.80',
            'license': 'project-authored geometry; raft weathered wood albedo',
            'generator': 'tools/fit_fishing_net_to_cell.py' if category == 'fishingNet' else 'tools/apply_raft_wood.py'
        })
        return deps

    model('model.prop.wooden-crate', 'wooden_crate_v004.blend', 'crate', ROOT / 'assets/models/props/wooden-crate.glb', 4)
    model('model.raft.module.planter', 'planter_v006.blend', 'planter', ROOT / 'assets/models/raft-modules/planter.glb', 6)
    model('model.raft.module.planter-seedling', 'planter_v006.blend', 'planter', ROOT / 'assets/models/raft-modules/planter-seedling.glb', 6)
    for key in ['shieldRack', 'generator', 'fishingNet']:
        version = 4 if key == 'fishingNet' else 3
        model('model.raft.module.' + key, key + f'_v{version:03d}.blend', key, ROOT / 'assets/models/raft-modules' / f'{key}.glb', version)

    wrapper = ROOT / 'assets/models/props/storage-crate-module.tscn'
    assets['model.raft.module.crate'].update({
        'source': ['asset-sources/raft-wood-unified-v1/wooden_crate_v004.blend', 'assets/models/props/storage-crate-module.tscn'],
        'version': 3,
        'dependencies': ['model.prop.wooden-crate'],
        'sha256': digest(wrapper)
    })

    root_state = assets.get('model.raft-state')
    if root_state:
        sources = root_state.setdefault('source', [])
        if isinstance(sources, str):
            root_state['source'] = [sources]
        if 'asset-sources/raft-wood-unified-v1/planter_v006.blend' not in root_state['source']:
            root_state['source'].insert(0, 'asset-sources/raft-wood-unified-v1/planter_v006.blend')
        root_state['wood_texture_version'] = 3

    for name in ['apply_raft_wood', 'register_raft_wood', 'verify_raft_wood']:
        path = ROOT / 'tools' / f'{name}.py'
        assets['factory.wood.raft-wood.' + name] = {
            'path': 'res://' + path.relative_to(ROOT).as_posix(),
            'source': 'project-authored unified raft wood material tooling',
            'version': 1,
            'sha256': digest(path),
            'dependencies': [],
            'status': 'offline-asset-pipeline',
            'license': 'project-authored'
        }

if __name__ == '__main__':
    path = ROOT / 'assets/manifest.json'
    manifest = json.loads(path.read_text(encoding='utf-8'))
    register(manifest)
    newline = '\r\n' if b'\r\n' in path.read_bytes() else '\n'
    path.write_bytes((json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').replace('\n', newline).encode('utf-8'))
    print('MANIFEST UPDATED WITH UNIFIED RAFT WOOD')
