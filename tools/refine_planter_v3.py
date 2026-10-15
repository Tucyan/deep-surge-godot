"""Blender background: textured staggered planter, mature and separate seedling mesh."""
import bpy
import bmesh
import json
import math
import struct
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'asset-sources/planter-v3'; OUT.mkdir(parents=True,exist_ok=True)
TEX = ROOT/'assets/textures/planter-v3'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'asset-sources/planter-v2/planter_v002.blend'))
scene = bpy.context.scene; scene.name = 'Planter_Mature_v003'
wood = next(o for o in scene.objects if o.type=='MESH' and o.name.endswith('-Wood'))
soil = next(o for o in scene.objects if o.type=='MESH' and o.name.endswith('-Soil'))

# Separate connected plank components, then vary their top while keeping the base fixed.
mesh = wood.data
adj = [set() for _ in mesh.vertices]
for edge in mesh.edges:
    a,b = edge.vertices; adj[a].add(b); adj[b].add(a)
remaining = set(range(len(mesh.vertices))); islands = []
while remaining:
    todo = [min(remaining)]; found = set(todo); remaining.difference_update(todo)
    while todo:
        i = todo.pop()
        for j in adj[i] & remaining:
            remaining.remove(j); found.add(j); todo.append(j)
    islands.append(sorted(found))
tops = []
for i,indices in enumerate(islands):
    bottom = min(mesh.vertices[k].co.z for k in indices)
    top = max(mesh.vertices[k].co.z for k in indices)
    if top-bottom < .12: continue  # bottom slab
    delta = [-.012,.024,.049,.008,.037,-.006,.018,.055,.003,.030][len(tops)%10]
    for k in indices:
        v = mesh.vertices[k]; v.co.z += delta*(v.co.z-bottom)/(top-bottom)
    tops.append(top+delta)
assert len(tops)==10 and max(tops)-min(tops)>.05

def projected_uv(obj,kind):
    data = obj.data; data.update()
    uv = data.uv_layers.active or data.uv_layers.new(name='UVMap')
    for face in data.polygons:
        axis = max(range(3),key=lambda k:abs(face.normal[k]))
        for li in face.loop_indices:
            v = data.vertices[data.loops[li].vertex_index].co
            if kind=='soil': xy = (v.x*1.3,v.y*1.3)
            elif axis==2: xy = (v.x*1.9,v.y*1.9)
            elif axis==0: xy = (v.y*2.7,v.z*.95)
            else: xy = (v.x*2.7,v.z*.95)
            uv.data[li].uv = xy

for obj,kind in [(wood,'wood'),(soil,'soil')]:
    projected_uv(obj,kind)
    m = obj.data.materials[0]; m.name = 'MAT-PlanterV3-'+('Wood' if kind=='wood' else 'Soil')
    nt = m.node_tree; bsdf = next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    for suffix in ['albedo','roughness','normal']:
        node = nt.nodes.new('ShaderNodeTexImage'); node.image = bpy.data.images.load(str(TEX/(kind+'-'+suffix+'.png')))
        node.image.colorspace_settings.name = 'sRGB' if suffix=='albedo' else 'Non-Color'
        node.image.pack()
        if suffix=='albedo': nt.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
        elif suffix=='roughness': nt.links.new(node.outputs['Color'],bsdf.inputs['Roughness'])
        else:
            normal = nt.nodes.new('ShaderNodeNormalMap'); normal.inputs['Strength'].default_value = .40 if kind=='wood' else .45
            nt.links.new(node.outputs['Color'],normal.inputs['Color']); nt.links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])

seed_scene = bpy.data.scenes.new('Planter_Seedling_v003')
seed_scene.unit_settings.system = 'METRIC'; seed_scene.unit_settings.scale_length = 1
for original in [wood,soil]:
    o = original.copy(); o.data = original.data.copy(); seed_scene.collection.objects.link(o)
green = next(m for m in bpy.data.materials if m.name.endswith('-PlantGreen'))
light_green = next(m for m in bpy.data.materials if m.name.endswith('-PlantGreenLight'))
bpy.context.window.scene = seed_scene
seed_objects = []
def make(name,vertices,faces,mat):
    data=bpy.data.meshes.new(name); data.from_pydata(vertices,[],faces); data.materials.append(mat)
    obj=bpy.data.objects.new(name,data); seed_scene.collection.objects.link(obj); seed_objects.append(obj)
    return obj

for i,(x,y) in enumerate([(-.30,-.08),(0,-.08),(.30,-.08),(-.29,.30),(.02,.30),(.29,.30)]):
    height = [.15,.19,.17,.20,.16,.18][i]; angle = i*2.399
    origin = Vector((x,y,.60305))
    tip = origin+Vector((.012*math.cos(angle),.012*math.sin(angle),height))
    verts=[]
    for j in range(3):
        t=j/2; center=origin.lerp(tip,t); r=.010*(1-t*.5)
        for k in range(6):
            a=k*math.tau/6; verts.append(tuple(center+Vector((r*math.cos(a),r*math.sin(a),0))))
    faces=[tuple(reversed(range(6))),tuple(range(12,18))]
    faces += [(j*6+k,j*6+(k+1)%6,(j+1)*6+(k+1)%6,(j+1)*6+k) for j in range(2) for k in range(6)]
    make('GEO-SeedlingStem-%d'%i,verts,faces,green)
    # Paired rounded cotyledons, visibly unlike the mature pointed leaf canopy.
    for side in (0,1):
        a=angle+side*math.pi; direction=Vector((math.cos(a),math.sin(a),0)); across=Vector((-math.sin(a),math.cos(a),0))
        root=tip-Vector((0,0,.025)); length=.105+(i%2)*.012
        verts=[]
        for j in range(7):
            t=j/6; width=.049*math.sin(math.pi*t)**.65 if j not in (0,6) else .002
            center=root+direction*(length*t)+Vector((0,0,.033*math.sin(t*math.pi*.85)))
            for k in (-1,0,1): verts.append(tuple(center+across*(width*k)+Vector((0,0,.008*(1-abs(k))*math.sin(math.pi*t)))))
        faces=[(j*3+k,j*3+k+1,(j+1)*3+k+1,(j+1)*3+k) for j in range(6) for k in range(2)]
        make('GEO-SeedlingCotyledon-%d-%d'%(i,side),verts,faces,light_green)
    make('GEO-SeedlingBud-%d'%i,[tuple(tip),tuple(tip+Vector((.018,0,.04))),tuple(tip+Vector((0,.012,.055)))],[(0,1,2)],green)

# Two plant batches; keep source box/soil batches shared in appearance.
for mat in [green,light_green]:
    batch=[o for o in list(seed_scene.objects) if o.type=='MESH' and o.data.materials[0]==mat]
    bpy.ops.object.select_all(action='DESELECT')
    for o in batch:o.select_set(True)
    bpy.context.view_layer.objects.active=batch[0]; bpy.ops.object.join()
    o=bpy.context.object; o.name='GEO-Seedling-'+mat.name.rsplit('-',1)[-1]
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.cube_project(cube_size=1); bpy.ops.object.mode_set(mode='OBJECT')

for current,filename in [(scene,'planter.glb'),(seed_scene,'planter-seedling.glb')]:
    bpy.context.window.scene=current
    bpy.context.window.view_layer=current.view_layers[0]
    for obj in current.objects:
        if obj.type!='MESH': continue
        bm=bmesh.new(); bm.from_mesh(obj.data); bmesh.ops.triangulate(bm,faces=list(bm.faces)); bm.to_mesh(obj.data); bm.free()
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.update()
    path=ROOT/'assets/models/raft-modules'/filename
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_yup=True,export_animations=False,export_tangents=True)
    data=path.read_bytes(); doc=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
    assert len(doc['meshes'])==4 and len(doc['scenes'])==1, filename
bpy.data.libraries.write(str(OUT/'planter_v003.blend'),{scene,seed_scene},fake_user=True)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'planter_v003.blend'))
bpy.context.window.scene=bpy.data.scenes['Planter_Mature_v003']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'planter_v003.blend'))
(OUT/'build-report.json').write_text(json.dumps({'source':'asset-sources/planter-v2/planter_v002.blend','textures':'tools/generate_planter_textures.py','visual_seed':31527,'plank_tops_z':tops,'seedling_count':6,'mature_scene':'Planter_Mature_v003','seedling_scene':'Planter_Seedling_v003'},indent=2))
print('PLANTER V3: mature + 6 paired-leaf seedlings, staggered planks, packed PBR maps')
