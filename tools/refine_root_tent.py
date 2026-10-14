"""Refine only tent geometry in cell 1; preserve all other modules and v003 source."""
import bpy,bmesh,math,json
from mathutils import Vector
from pathlib import Path
root=Path('C:/Users/ALmerb/Desktop/MyProgram/yongxian/deep-surge-godot');src=root/'asset-sources/raft-blender-v1'
bpy.ops.wm.open_mainfile(filepath=str(src/'raft_modules_v003.blend'))
scene=bpy.data.scenes['Raft_Modules_v1'];bpy.context.window.scene=scene
col=bpy.data.collections['COL-root-decor'];removed=0
# In our material-merged source, tent faces are identified by cell-1 bounds and height.
for o in list(col.objects):
 if o.type!='MESH' or o.name.startswith('GEO-DecorativeLantern'):continue
 bm=bmesh.new();bm.from_mesh(o.data)
 faces=[f for f in bm.faces if all((o.matrix_world@v.co).x<-.12 for v in f.verts) and any((o.matrix_world@v.co).z>.35 for v in f.verts)]
 removed+=len(faces);bmesh.ops.delete(bm,geom=faces,context='FACES')
 loose=[v for v in bm.verts if not v.link_faces]
 if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
 bm.to_mesh(o.data);bm.free()
new=[]
def v(p):return Vector((p[0],-p[2],p[1]))
def material(name,rgb,rough=.9):
 m=bpy.data.materials.new('MAT-Tent-'+name);m.use_nodes=True;m.diffuse_color=(*rgb,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Roughness'].default_value=rough
 return m
canvas=material('WaxedLinen',(.55,.43,.27));patch=material('WeatheredPatch',(.35,.27,.16));seam=material('Hem',(.30,.22,.12));wood=bpy.data.materials['MAT-DarkTimber'];hemp=bpy.data.materials['MAT-Hemp']
def link(o,name,mat):
 o.name='GEO-Tent-'+name
 for c in list(o.users_collection):c.objects.unlink(o)
 col.objects.link(o);o.data.materials.append(mat);new.append(o);return o
def rod(name,a,b,r,mat):
 a=v(a);b=v(b);bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=r,depth=(b-a).length,location=(a+b)*.5)
 o=link(bpy.context.object,name,mat);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def sheet(name,points,faces,mat):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([v(p) for p in points],[],faces);mesh.update();o=bpy.data.objects.new('GEO-Tent-'+name,mesh);col.objects.link(o);o.data.materials.append(mat);new.append(o)
 mod=o.modifiers.new('CanvasThickness','SOLIDIFY');mod.thickness=.012;mod.offset=0
 for p in mesh.polygons:p.use_smooth=True
 return o
cx=-1.175
# Drape has a bowed edge, longitudinal folds and an uneven weighted hem.
def roof(side,u,t):
 z=-.76+t*1.52;x=cx+side*(.96*u)
 y=1.62-1.34*u-.075*math.sin(math.pi*u)+.017*math.sin(t*math.pi*10+u*3)*math.sin(math.pi*u)
 y+=.014*math.sin(t*math.pi*6)*u**5
 return(x,y,z)
for side in (-1,1):
 points=[roof(side,i/8,j/16) for i in range(9) for j in range(17)]
 faces=[(i*17+j,(i+1)*17+j,(i+1)*17+j+1,i*17+j+1) for i in range(8) for j in range(16)]
 sheet('Roof'+str(side),points,faces,canvas)
 for j in range(16):rod('BoundHem',roof(side,1,j/16),roof(side,1,(j+1)/16),.012,seam)
 for z in [-.76,.76]:rod('RoofRib',(cx,1.585,z),(cx+side*.93,.25,z),.024,wood)
for z in [-.72,.72]:rod('RidgePost',(cx,.19,z),(cx,1.60,z),.032,wood)
rod('RidgePole',(cx,1.60,-.83),(cx,1.60,.83),.032,wood)
# Back sealed; front split and pulled aside so it reads as an entrance.
sheet('Back',[(cx,1.60,-.75),(cx-.94,.28,-.75),(cx+.94,.28,-.75)],[(0,1,2)],canvas)
for side in [-1,1]:
 sheet('EntranceFlap'+str(side),[(cx,1.59,.77),(cx+side*.92,.28,.78),(cx+side*.47,.29,.86),(cx+side*.33,.93,.81)],[(0,1,2),(0,2,3)],canvas)
 rod('FlapTie',(cx+side*.53,.62,.84),(cx+side*.90,.43,.76),.012,hemp)
 # Ground ties terminate inside decorative cell, not in playable cells.
 for z in [-.67,.67]:
  rod('GuyRope',(cx+side*.88,.38,z),(cx+side*1.06,.20,z+.10),.012,hemp)
  rod('WoodPeg',(cx+side*1.06,.17,z+.10),(cx+side*1.06,.31,z+.10),.022,wood)
# Sewn patch sits on the right slope; no cut-out or floating decal.
pts=[]
for u,t in [(.36,.30),(.64,.30),(.64,.53),(.36,.53)]:
 x,y,z=roof(1,u,t);pts.append((x+.009,y+.018,z))
sheet('RepairPatch',pts,[(0,1,2,3)],patch)
for k in range(6):
 t=.31+k*.04;a=roof(1,.365,t);b=roof(1,.405,t)
 rod('PatchStitch',(a[0]+.012,a[1]+.03,a[2]),(b[0]+.012,b[1]+.03,b[2]+.022),.004,hemp)
# Rolled bed mat, contained underneath the entrance.
bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.105,depth=.64,location=v((cx,.30,.37)));o=link(bpy.context.object,'Bedroll',patch);o.rotation_euler.y=math.pi/2
for x in [cx-.20,cx+.20]:rod('BedrollStrap',(x,.29,.27),(x,.31,.47),.012,hemp)
# Bake/join only new tent geometry by material; leave root/cargo/lamp geometry unchanged.
batches={}
for o in new:batches.setdefault(o.data.materials[0].name,[]).append(o)
for name,objects in batches.items():
 for o in objects:
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
  for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name='GEO-Tent-'+name
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.cube_project(cube_size=1);bpy.ops.object.mode_set(mode='OBJECT')
# Assembly copies share the edited original meshes; add only new tent parts.
preview=bpy.data.scenes['Initial_123_456']
for o in col.objects:
 if not o.name.startswith('GEO-Tent-'):continue
 c=o.copy();c.data=o.data;preview.collection.objects.link(c);c.location+=Vector((0,1.05,.13))
bpy.ops.object.select_all(action='DESELECT')
for o in col.objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/raft-modules/root-decor.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
bpy.context.window.scene=preview;bpy.ops.object.select_all(action='DESELECT')
for o in preview.objects:
 if o.type=='MESH':o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(src/'raft_initial_v004.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(src/'raft_modules_v004.blend'))
preview.render.filepath=str(root/'evidence/blender-tent-v004.png');bpy.ops.render.render(write_still=True)
print('TENT REFINED',removed,'old faces replaced; cell 2 lamp/cargo preserved')
