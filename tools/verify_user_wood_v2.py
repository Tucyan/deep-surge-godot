"""Check each live GLB carries only its assigned user texture unchanged."""
import io,json,struct,hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'asset-sources/stylized-wood-user-v2'
records=json.loads((OUT/'application-report.json').read_text())
assets=json.loads((ROOT/'assets/manifest.json').read_text(encoding='utf-8'))['assets']
mapping={'wooden-crate':'crate','planter':'planter','planter-seedling':'planter','shieldRack':'shieldRack','generator':'generator','fishingNet':'fishingNet'}
for stem,category in mapping.items():
 path=(ROOT/'assets/models/props/wooden-crate.glb' if stem=='wooden-crate' else ROOT/'assets/models/raft-modules'/f'{stem}.glb')
 data=path.read_bytes();length=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+length]);binary=data[28+length:]
 assigned=Image.open(ROOT/'assets/textures/stylized-wood-user-v2'/f'wood-{category}-albedo.png').convert('RGBA')
 texture_ids=set();wood_count=0
 for mat in doc['materials']:
  if 'Wood' not in mat['name']:continue
  wood_count+=1;pbr=mat['pbrMetallicRoughness'];assert abs(pbr['roughnessFactor']-.90)<.005
  factor=pbr.get('baseColorFactor',[1,1,1,1]);assert all(abs(x-1)<.001 for x in factor),(stem,mat['name'],factor)
  texture_index=pbr['baseColorTexture']['index'];texture_ids.add(texture_index)
  image=doc['images'][doc['textures'][texture_index]['source']];view=doc['bufferViews'][image['bufferView']]
  embedded=Image.open(io.BytesIO(binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])).convert('RGBA')
  assert embedded.size==assigned.size and embedded.tobytes()==assigned.tobytes(),(stem,mat['name'],'wood pixels differ from assigned attachment')
 # glTF may embed identical PNG bytes once per Blender material slot; each
 # referenced texture above must still decode to the one assigned input.
 assert wood_count,(stem,wood_count)
 report_key=stem+'.glb'
 assert report_key in records and records[report_key]['geometry_unchanged'] and records[report_key]['uv_unchanged']
 texture_id='texture.user-wood-v2.'+category
 assert assets[texture_id]['sha256']==hashlib.sha256((ROOT/'assets/textures/stylized-wood-user-v2'/f'wood-{category}-albedo.png').read_bytes()).hexdigest()
print('USER WOOD PIXELS + ASSIGNMENTS + MATERIAL ROUGHNESS + GEOMETRY/UV RECORDS: PASS')
