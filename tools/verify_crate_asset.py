"""Blender background: portable asset re-import, topology, UVs, bounds, lid isolation."""
import bpy
import json
import math
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
STYLIZED=(ROOT/'asset-sources/wooden-crate-v2/wooden_crate_v002.blend').exists()
OUT=ROOT/('asset-sources/wooden-crate-v2' if STYLIZED else 'asset-sources/wooden-crate-v1')
def bounds(scene):
    bpy.context.view_layer.update()
    pts=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
    assert pts and all(math.isfinite(x) for v in pts for x in v)
    return [[min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]]
def hierarchy(scene,name):
    return next(o for o in scene.objects if o.name.startswith(name) and o.type=='EMPTY')

path=ROOT/'assets/models/props/wooden-crate.glb'
data=path.read_bytes();magic,version,total=struct.unpack_from('<4sII',data)
assert magic==b'glTF' and version==2 and total==len(data) and total<15*1024*1024
length=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+length])
assert len(doc['scenes'])==1 and all('bufferView' in i for i in doc['images'])
assert all({'POSITION','NORMAL','TEXCOORD_0'}<=p['attributes'].keys() for m in doc['meshes'] for p in m['primitives'])
assert not doc.get('animations')
wood_mats=[m for m in doc['materials'] if 'Wood' in m['name']]
assert len(wood_mats)==3
assert all('baseColorTexture' in m['pbrMetallicRoughness'] for m in wood_mats)
if STYLIZED:assert all('normalTexture' not in m and abs(m['pbrMetallicRoughness']['roughnessFactor']-.9)<.01 for m in wood_mats)
else:assert all('normalTexture' in m for m in wood_mats)

bpy.ops.wm.open_mainfile(filepath=str(OUT/('wooden_crate_v002.blend' if STYLIZED else 'wooden_crate_v001.blend')))
scene=bpy.data.scenes['Wooden_Crate_v002' if STYLIZED else 'Wooden_Crate_v001'];bpy.context.window.scene=scene;bpy.context.window.view_layer=scene.view_layers[0]
expected=bounds(scene)
assert abs(expected[0][2])<1e-5
for name in ['CrateBody','CrateLid']:assert hierarchy(scene,name).children
build=json.loads((ROOT/'asset-sources/wooden-crate-v1/build-report.json').read_text())
assert build['board_count']==33 and max(b['bow'] for b in build['boards'])-min(b['bow'] for b in build['boards'])>.008

import_scene=bpy.data.scenes.new('CrateReimport');bpy.context.window.scene=import_scene;bpy.context.window.view_layer=import_scene.view_layers[0]
bpy.ops.import_scene.gltf(filepath=str(path));actual=bounds(import_scene)
assert all(abs(a-b)<1e-5 for aa,bb in zip(expected,actual) for a,b in zip(aa,bb))
tris=0
for o in import_scene.objects:
    if o.type!='MESH':continue
    mesh=o.data;mesh.calc_loop_triangles();tris+=len(mesh.loop_triangles)
    assert mesh.uv_layers and not o.modifiers
    assert all(abs(v.normal.length-1)<.01 for v in mesh.vertices)
    for t in mesh.loop_triangles:
        a,b,c=[mesh.vertices[i].co for i in t.vertices]
        assert (b-a).cross(c-a).length>1e-10,'Degenerate triangle'
    if 'Wood' in o.name:
        assert all(-.01<=uv.uv.x<=1.01 and -.01<=uv.uv.y<=1.01 for uv in mesh.uv_layers.active.data),'Repeating bitmap seam'
assert 2000<tris<15000
lid=hierarchy(import_scene,'CrateLid');body=hierarchy(import_scene,'CrateBody')
body_before=[(o.name,tuple(o.matrix_world.translation)) for o in body.children]
lid.rotation_euler.x=-.8;bpy.context.view_layer.update()
assert body_before==[(o.name,tuple(o.matrix_world.translation)) for o in body.children]
report={'result':'PASS','triangles':tris,'meshes':len(doc['meshes']),'materials':len(doc['materials']),
        'embedded_images':len(doc['images']),'bytes':len(data),'source_bounds_z_up':expected,
        'reimport_bounds_z_up':actual,'independent_lid':True,'no_degenerate_triangles':True,'uvs':True,
        'origin_at_base':True,'staged_not_gameplay':True}
(OUT/'validation.json').write_text(json.dumps(report,indent=2))
print('CRATE REIMPORT + NORMALS/UV + LID + GEOMETRY: PASS',json.dumps(report))
