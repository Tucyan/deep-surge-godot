"""Run in an isolated background Blender; does not touch the live user's scene."""
import bpy, json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models/raft-modules/slot-ghost.glb'
SOURCE=ROOT/'asset-sources/raft-interaction-v1/slot-ghost-v1.blend'
OUT.parent.mkdir(parents=True,exist_ok=True); SOURCE.parent.mkdir(parents=True,exist_ok=True)
scene=bpy.data.scenes.new('Raft_Slot_Ghost_v1'); bpy.context.window.scene=scene
collection=bpy.data.collections.new('COL-Raft-Slot-Ghost'); scene.collection.children.link(collection)
material=bpy.data.materials.new('MAT-Ghost-Blueprint'); material.use_nodes=True
node=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
node.inputs['Base Color'].default_value=(0.08,0.55,1.0,1)
node.inputs['Roughness'].default_value=.65
objects=[]
def beam(name,center,size):
    sx,sy,sz=(s/2 for s in size)
    verts=[(x+center[0],y+center[1],z+center[2]) for x,y,z in [(-sx,-sy,-sz),(sx,-sy,-sz),(sx,sy,-sz),(-sx,sy,-sz),(-sx,-sy,sz),(sx,-sy,sz),(sx,sy,sz),(-sx,sy,sz)]]
    mesh=bpy.data.meshes.new('GEO-'+name); mesh.from_pydata(verts,[],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    uv=mesh.uv_layers.new(name='UVMap')
    for loop in mesh.loops:
        co=mesh.vertices[loop.vertex_index].co
        uv.data[loop.index].uv=((co.x+1.12)/2.24,(co.y+1.0)/2.0)
    obj=bpy.data.objects.new('GEO-'+name,mesh); collection.objects.link(obj); obj.data.materials.append(material); objects.append(obj)
# Blender Z up -> GLB/Godot Y up; logical footprint 2.24 x 2.00 m.
for x in [-1.10,1.10]: beam('Rim-X', (x,0,.04),(.04,2.0,.08))
for y in [-.98,.98]: beam('Rim-Y',(0,y,.04),(2.24,.04,.08))
for i in range(5):
    x=-.88+i*.44
    for side in [-1,1]: beam('Plank-guide',(x+side*.19,0,.025),(.018,1.91,.035))
for x in [-.95,.95]:
    for y in [-.83,.83]: beam('Corner-upright',(x,y,.14),(.035,.035,.28))
beam('Plus-X',(0,0,.06),(.42,.045,.05)); beam('Plus-Y',(0,0,.06),(.045,.42,.05))
for o in bpy.context.selected_objects: o.select_set(False)
for o in objects: o.select_set(True)
bpy.context.view_layer.objects.active=objects[0]
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=False)
report={'source':str(SOURCE),'glb':str(OUT),'objects':len(objects),'triangles':sum(len(o.data.polygons)*2 for o in objects),'footprint_godot':[2.24,2.0],'runtime':'shared GLB meshes, blue/red/gold material override; no rule RNG'}
(SOURCE.parent/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
