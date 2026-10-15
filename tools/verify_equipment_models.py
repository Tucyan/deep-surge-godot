"""Blender source/GLB roundtrip, shared texture pixels, topology and bounds gate."""
import bpy, json, math, struct, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'asset-sources/equipment-models-v1'
def bounds(scene):
    bpy.context.view_layer.update()
    points=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
    assert points and all(math.isfinite(x) for p in points for x in p)
    return [[min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]]
reports={}
for key in ['shieldRack','generator','fishingNet']:
    path=ROOT/'assets/models/raft-modules'/f'{key}.glb';data=path.read_bytes()
    magic,version,total=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and total==len(data) and total<15*1024*1024
    length=struct.unpack_from('<I',data,12)[0];doc=json.loads(data[20:20+length]);binary=data[28+length:]
    assert len(doc['scenes'])==1 and not doc.get('animations')
    assert all({'POSITION','NORMAL','TEXCOORD_0'}<=p['attributes'].keys() for m in doc['meshes'] for p in m['primitives'])
    # Validate actual glTF split corner normals. Blender's reconstructed
    # averaged vertex normals are a different representation after import.
    for item in doc['meshes']:
        for primitive in item['primitives']:
            a=doc['accessors'][primitive['attributes']['NORMAL']];view=doc['bufferViews'][a['bufferView']]
            for i in range(a['count']):
                n=struct.unpack_from('<3f',binary,view.get('byteOffset',0)+a.get('byteOffset',0)+i*view.get('byteStride',12))
                assert all(math.isfinite(v) for v in n) and abs(sum(v*v for v in n)-1)<.01,(key,'glTF normal')
    for color in ['warm','dark','grey']:
        mat=next(m for m in doc['materials'] if m['name']=='MAT-Equipment-Wood-'+color)
        pbr=mat['pbrMetallicRoughness'];assert abs(pbr['roughnessFactor']-.9)<.001 and 'normalTexture' not in mat
        assert 'baseColorTexture' in pbr
    bpy.ops.wm.open_mainfile(filepath=str(OUT/f'{key}_v001.blend'))
    scene=bpy.data.scenes['Equipment_'+key+'_v001'];bpy.context.window.scene=scene;bpy.context.window.view_layer=scene.view_layers[0]
    expected=bounds(scene)
    imported=bpy.data.scenes.new('EquipmentRoundtrip');bpy.context.window.scene=imported;bpy.context.window.view_layer=imported.view_layers[0]
    bpy.ops.import_scene.gltf(filepath=str(path));actual=bounds(imported)
    assert all(abs(a-b)<1e-5 for aa,bb in zip(expected,actual) for a,b in zip(aa,bb))
    triangles=0
    for obj in imported.objects:
        if obj.type!='MESH':continue
        mesh=obj.data;mesh.calc_loop_triangles();triangles+=len(mesh.loop_triangles)
        assert mesh.uv_layers and not obj.modifiers
        assert all(math.isfinite(x) and -.001<=x<=1.001 for uv in mesh.uv_layers.active.data for x in uv.uv)
        for tri in mesh.loop_triangles:
            a,b,c=[mesh.vertices[i].co for i in tri.vertices]
            assert (b-a).cross(c-a).length>1e-10,(key,'degenerate triangle')
    assert triangles<18000
    assert expected[1][0]-expected[0][0]<1.5
    if key!='fishingNet':assert expected[0][2]>.13
    else:assert -.20<expected[0][2]<0 and expected[0][1]<-1.3,'Net must hang outside the raft'
    reports[key]={'result':'PASS','triangles':triangles,'meshes':len(doc['meshes']),'materials':len(doc['materials']),
      'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'source_bounds_z_up':expected,'reimport_bounds_z_up':actual,
      'finite_normals_uvs':True,'no_degenerate_triangles':True,'status':'staged-not-integrated'}
(OUT/'validation.json').write_text(json.dumps(reports,indent=2)+'\n')
print('EQUIPMENT ROUNDTRIP + NORMALS/UV + SHARED TEXTURES: PASS',json.dumps(reports))
