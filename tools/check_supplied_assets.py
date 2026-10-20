"""File/manifest/GLB integrity checks independent from the Godot asset loader."""
import json,pathlib,hashlib,struct,zipfile
from PIL import Image
ROOT=pathlib.Path(__file__).resolve().parents[1]; SOURCE=ROOT/'asset-sources/user-pack-20261012'
manifest=json.loads((ROOT/'assets/manifest.json').read_text(encoding='utf-8'))['assets']
count=0
for id,d in manifest.items():
    if not d.get('path') or not d.get('sha256'): continue
    p=ROOT/d['path'].removeprefix('res://')
    assert p.exists(), (id,p)
    assert hashlib.sha256(p.read_bytes()).hexdigest()==d['sha256'],f'Hash mismatch: {id}'
    for source, expected_hash in d.get('source_hashes', {}).items():
        source_path=ROOT/source.removeprefix('res://')
        assert source_path.is_file(),f'Missing registered source: {id}/{source}'
        assert hashlib.sha256(source_path.read_bytes()).hexdigest()==expected_hash,f'Source hash mismatch: {id}/{source}'
    if p.suffix.lower()=='.png':
        im=Image.open(p); assert list(im.size)==d['dimensions'],f'Dimensions: {id}'
        if d.get('region'):
            x,y,w,h=d['region'];assert x>=0 and y>=0 and x+w<=im.width and y+h<=im.height,f'Atlas region: {id}'
    count+=1
for inventory_file in ['image-inventory.json','ui-inventory.json']:
    inventory=json.loads((SOURCE/inventory_file).read_text(encoding='utf-8'))
    for d in inventory:
        p=ROOT/d['file']; assert hashlib.sha256(p.read_bytes()).hexdigest()==d['sha256']
        assert Image.open(p).mode=='RGBA',p
data=(ROOT/'assets/models/supplied-ocean.glb').read_bytes()
magic,version,size=struct.unpack_from('<4sII',data);assert magic==b'glTF' and version==2 and size==len(data)
length,kind=struct.unpack_from('<I4s',data,12);assert kind==b'JSON'
gltf=json.loads(data[20:20+length]);assert len(gltf['meshes'])==1
primitive=gltf['meshes'][0]['primitives'][0];assert len(primitive['targets'])==15
assert 'TEXCOORD_0' in primitive['attributes'] and 'NORMAL' in primitive['attributes']
positions=gltf['accessors'][primitive['attributes']['POSITION']]['count'];assert positions==10201,positions
assert size<15*1024*1024
print(f'FILE ASSETS: PASS ({count} hashed bindings, 20 original PNGs, GLB {size} bytes / {positions} vertices / 15 morphs)')
