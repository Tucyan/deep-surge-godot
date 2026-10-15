"""Blender background: preserve filter design, replace solid bucket with open two-state bucket."""
import bpy
import bmesh
import json
import math
import struct
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'asset-sources/filter-states-v1'; OUT.mkdir(parents=True,exist_ok=True)
runtime = ROOT/'assets/models/raft-modules'
backup = OUT/'filter-before.glb'
if not backup.exists(): backup.write_bytes((runtime/'filter.glb').read_bytes())
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'asset-sources/raft-blender-v1/raft_modules_v005.blend'))
original_scene = bpy.data.scenes['Raft_Modules_v1']
bpy.context.window.scene = original_scene
bpy.context.window.view_layer = original_scene.view_layers[0]
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
source_parts = []
for o in bpy.data.collections['COL-filter'].objects:
    if o.type!='MESH' or any('Water' in m.name for m in o.data.materials): continue
    evaluated = o.evaluated_get(deps)
    mesh = bpy.data.meshes.new_from_object(evaluated,depsgraph=deps)
    matrix = evaluated.matrix_world.copy()
    for v in mesh.vertices: v.co = matrix@v.co
    if any('AgedIron' in m.name for m in mesh.materials):
        # Only the original solid receiving bucket lies below z=0.63; tank/spout stay.
        bm=bmesh.new(); bm.from_mesh(mesh)
        low=[v for v in bm.verts if v.co.z < .63]
        assert low and len(low)<len(bm.verts)
        bmesh.ops.delete(bm,geom=low,context='VERTS'); bm.to_mesh(mesh); bm.free()
    source_parts.append((o.name,mesh))
assert len(source_parts)==4

water=bpy.data.materials.new('MAT-Filter-CleanWater'); water.use_nodes=True
p=next(n for n in water.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
p.inputs['Base Color'].default_value=(.08,.39,.48,1); p.inputs['Roughness'].default_value=.22
inside=bpy.data.materials.new('MAT-Filter-BucketInterior'); inside.use_nodes=True
p=next(n for n in inside.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
p.inputs['Base Color'].default_value=(.065,.095,.105,1); p.inputs['Roughness'].default_value=.8
iron=next(m for _,mesh in source_parts for m in mesh.materials if 'AgedIron' in m.name)

def bucket_mesh():
    mesh=bpy.data.meshes.new('GEO-Filter-OpenBucket')
    verts=[]; faces=[]; mats=[]; n=24
    # bottom outside, upper outside, upper inside, lower inside.
    for r,z in [(.255,.325),(.255,.59),(.229,.59),(.229,.35)]:
        for i in range(n):
            a=i*math.tau/n; verts.append((.31+r*math.cos(a),-.17+r*math.sin(a),z))
    for ring in range(3):
        for i in range(n):
            j=(i+1)%n; faces.append((ring*n+i,ring*n+j,(ring+1)*n+j,(ring+1)*n+i)); mats.append(0 if ring<2 else 1)
    faces.append(tuple(reversed(range(n)))); mats.append(0)
    faces.append(tuple(range(3*n,4*n))); mats.append(1)
    mesh.from_pydata(verts,[],faces); mesh.materials.append(iron); mesh.materials.append(inside)
    for face,mi in zip(mesh.polygons,mats):face.material_index=mi
    return mesh

scenes=[]
for stage,filename in [('waiting','filter-waiting.glb'),('ready','filter.glb')]:
    scene=bpy.data.scenes.new('Filter_'+stage+'_v001'); scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
    bpy.context.window.scene=scene; bpy.context.window.view_layer=scene.view_layers[0]
    for name,mesh in source_parts:
        o=bpy.data.objects.new(name,mesh.copy()); o.matrix_world=Matrix.Identity(4); scene.collection.objects.link(o)
    o=bpy.data.objects.new('GEO-Filter-OpenBucket',bucket_mesh()); scene.collection.objects.link(o)
    if stage=='ready':
        # Water is a visible volume indicator, not an already-awarded inventory item.
        verts=[(.31,-.17,.552)]+[(.31+.226*math.cos(i*math.tau/32),-.17+.226*math.sin(i*math.tau/32),.552) for i in range(32)]
        faces=[(0,i+1,(i+1)%32+1) for i in range(32)]
        mesh=bpy.data.meshes.new('GEO-Filter-WaterSurface'); mesh.from_pydata(verts,[],faces); mesh.materials.append(water)
        o=bpy.data.objects.new('GEO-Filter-WaterSurface',mesh); scene.collection.objects.link(o)
    bpy.ops.object.select_all(action='SELECT')
    for o in scene.objects:
        bpy.context.view_layer.objects.active=o
        bm=bmesh.new(); bm.from_mesh(o.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bmesh.ops.triangulate(bm,faces=list(bm.faces)); bm.to_mesh(o.data); bm.free()
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.cube_project(cube_size=1); bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='SELECT')
    path=runtime/filename
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_active_scene=True,use_selection=True,export_apply=True,export_yup=True,export_animations=False)
    data=path.read_bytes(); doc=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
    assert len(doc['scenes'])==1 and len(doc['meshes'])==(5 if stage=='waiting' else 6)
    scenes.append(scene)
bpy.data.libraries.write(str(OUT/'filter_states_v001.blend'),set(scenes),fake_user=True)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'filter_states_v001.blend'))
bpy.context.window.scene=bpy.data.scenes['Filter_ready_v001']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'filter_states_v001.blend'))
(OUT/'build-report.json').write_text(json.dumps({'source':'asset-sources/raft-blender-v1/raft_modules_v005.blend','bucket_outer_radius':.255,'bucket_inner_radius':.229,'bucket_bottom_y':.325,'bucket_top_y':.59,'bucket_inner_bottom_y':.35,'ready_water_y':.552,'waiting_water':False,'rule_random':False},indent=2))
print('FILTER TWO STATES: open empty bucket / visible ready water; originals preserved')
