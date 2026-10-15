"""Prove all three exported models actually use the three imagegen originals."""
import hashlib
import io
import json
import struct
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
report={}
for relative in ['props/wooden-crate.glb','raft-modules/planter.glb','raft-modules/planter-seedling.glb']:
    path=ROOT/'assets/models'/relative;data=path.read_bytes()
    length=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+length]);binary=data[28+length:]
    colors=[]
    for material in doc['materials']:
        if not material['name'].startswith('MAT-StylizedWood-'):continue
        color=material['name'].rsplit('-',1)[-1].lower();colors.append(color)
        pbr=material['pbrMetallicRoughness']
        assert 'normalTexture' not in material and abs(pbr['roughnessFactor']-.9)<.01
        texture=doc['textures'][pbr['baseColorTexture']['index']]
        image=doc['images'][texture['source']];view=doc['bufferViews'][image['bufferView']]
        start=view.get('byteOffset',0);raw=binary[start:start+view['byteLength']]
        embedded=Image.open(io.BytesIO(raw)).convert('RGB')
        original=Image.open(ROOT/'assets/textures/stylized-wood-v1'/('wood-'+color+'-albedo.png')).convert('RGB')
        assert embedded.size==original.size and embedded.tobytes()==original.tobytes(),(relative,color)
    assert set(colors)=={'warm','dark','grey'} and len(colors)==3
    report[relative]={'result':'PASS','colors':colors,'embedded_pixels_match_original':True,'bytes':len(data),
                      'sha256':hashlib.sha256(data).hexdigest(),'wood_micro_normal':False}
manifest=json.loads((ROOT/'assets/manifest.json').read_text(encoding='utf-8'))['assets']
for key in ['model.prop.wooden-crate','model.raft.module.planter','model.raft.module.planter-seedling']:
    entry=manifest[key]
    assert hashlib.sha256((ROOT/entry['path'].removeprefix('res://')).read_bytes()).hexdigest()==entry['sha256']
    assert (ROOT/entry['source']).is_file()
    for dep in entry['dependencies']:
        item=manifest[dep];path=ROOT/item['path'].removeprefix('res://')
        assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],dep
(ROOT/'asset-sources/stylized-wood-v1/validation.json').write_text(json.dumps(report,indent=2))
print('STYLIZED WOOD: 3 COLORS x 3 MODELS / ORIGINAL PIXELS / HASHES: PASS')
