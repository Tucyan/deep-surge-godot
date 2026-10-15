"""System Python pixel verification, without adding packages to Blender."""
import json, struct, io, hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
report_path=ROOT/'asset-sources/equipment-models-v1/validation.json'
report=json.loads(report_path.read_text())
manifest=json.loads((ROOT/'assets/manifest.json').read_text(encoding='utf-8'))['assets']
for key in ['shieldRack','generator','fishingNet']:
    path=ROOT/'assets/models/raft-modules'/f'{key}.glb';data=path.read_bytes()
    length=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+length]);binary=data[28+length:]
    for color in ['warm','dark','grey']:
        mat=next(m for m in doc['materials'] if m['name']=='MAT-Equipment-Wood-'+color)
        img=doc['images'][doc['textures'][mat['pbrMetallicRoughness']['baseColorTexture']['index']]['source']];view=doc['bufferViews'][img['bufferView']]
        embedded=Image.open(io.BytesIO(binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])).convert('RGBA')
        original=Image.open(ROOT/'assets/textures/stylized-wood-v1'/f'wood-{color}-albedo.png').convert('RGBA')
        assert embedded.size==original.size and embedded.tobytes()==original.tobytes(),(key,color,'Changed texture pixels')
    entry=manifest['model.raft.module.'+key]
    assert entry['sha256']==hashlib.sha256(data).hexdigest() and entry['status']=='staged-not-integrated'
    assert all(dep in manifest for dep in entry['dependencies'])
    report[key]['shared_texture_pixels_unchanged']=True
for key in [k for k in manifest if k.startswith(('model.raft.module.shieldRack','model.raft.module.generator','model.raft.module.fishingNet','model.raft.module.crate','texture.raft.equipment.imported.','factory.raft.equipment.'))]:
    entry=manifest[key];path=ROOT/entry['path'].removeprefix('res://')
    assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'],key
    assert all(dep in manifest for dep in entry['dependencies']),key
    if 'dimensions' in entry:assert list(Image.open(path).size)==entry['dimensions'],key
report_path.write_text(json.dumps(report,indent=2)+'\n')
print('EQUIPMENT SHARED TEXTURE PIXELS + ASSET HASHES: PASS')
