import bpy,math,json
from pathlib import Path
from mathutils import Vector
ROOT=Path('C:/Users/ALmerb/Desktop/MyProgram/yongxian/deep-surge-godot')
OUT=ROOT/'assets/models/raft-modules';SRC=ROOT/'asset-sources/raft-blender-v1'
source=Path('C:/Users/ALmerb/Desktop/MyProgram/yongxian/raft-model/raft_v004.blend')
scene=bpy.data.scenes.new('Raft_Modules_v1');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
with bpy.data.libraries.load(str(source),link=False) as (a,b):
 b.objects=[n for n in a.objects if n.startswith(('GEO-Shelter','GEO-Canopy','GEO-SupplyCrate','GEO-Barrel','GEO-Planter','GEO-PlantStem','GEO-PlantLeaf','GEO-Lantern'))]
original=[o for o in b.objects if o and o.type=='MESH']
# Read-only source append: all exports are independent copies.
materials={}
def mat(name,color,rough=.76):
 if name in materials:return materials[name]
 m=bpy.data.materials.new('MAT-'+name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
 materials[name]=m;return m
wood=mat('WarmWeatheredWood',(.32,.19,.095));dark=mat('DarkTimber',(.12,.085,.05));iron=mat('AgedIron',(.18,.24,.26),.48);rope=mat('Hemp',(.48,.37,.20));cloth=mat('Linen',(.62,.57,.43));red=mat('OxideMark',(.46,.13,.08));water=mat('WaterBowl',(.12,.28,.34),.25)
modules={};current=None
def vec(p):return Vector((p[0],-p[2],p[1]))
def begin(name):
 global current
 current=bpy.data.collections.new('COL-'+name);scene.collection.children.link(current);modules[name]=current
 return current
def link(obj,name,material):
 obj.name='GEO-'+name
 for c in list(obj.users_collection):c.objects.unlink(obj)
 current.objects.link(obj)
 if material:obj.data.materials.append(material)
 return obj
def box(name,pos,size,material,bevel=.016):
 bpy.ops.mesh.primitive_cube_add(size=1,location=vec(pos));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);link(o,name,material)
 if bevel:
  mod=o.modifiers.new('EdgeWear','BEVEL');mod.width=bevel;mod.segments=2
 return o
def cyl(name,pos,r,h,material):
 bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=h,location=vec(pos));o=link(bpy.context.object,name,material)
 mod=o.modifiers.new('RimBevel','BEVEL');mod.width=.012;mod.segments=2;return o
def rod(name,a,b,r,material):
 a=vec(a);b=vec(b);bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=r,depth=(b-a).length,location=(a+b)*.5);o=link(bpy.context.object,name,material);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def reuse(prefixes,name,target,center):
 chosen=[o for o in original if o.name.startswith(tuple(prefixes))]
 copies=[]
 for o in chosen:
  c=o.copy();c.data=o.data.copy();current.objects.link(c);c.name='GEO-'+name+'-'+o.name;c.parent=None;c.matrix_world=o.matrix_world.copy();copies.append(c)
 bpy.context.view_layer.update();points=[c.matrix_world@Vector(v) for c in copies for v in c.bound_box]
 mn=Vector(tuple(min(p[i] for p in points) for i in range(3)));mx=Vector(tuple(max(p[i] for p in points) for i in range(3)))
 # Bounds in Blender XYZ; preserve sensible proportions, fit footprint exactly.
 extent=mx-mn;scale=Vector((target[0]/extent.x,target[2]/extent.y,target[1]/extent.z));anchor=Vector(((mn.x+mx.x)/2,(mn.y+mx.y)/2,mn.z))
 for c in copies:
  # Bake original evaluated modifiers/transforms before re-centering.
  dep=bpy.context.evaluated_depsgraph_get();mesh=bpy.data.meshes.new_from_object(c.evaluated_get(dep));oldmat=c.matrix_world.copy();c.modifiers.clear();c.data=mesh;c.matrix_world.identity()
  for v in mesh.vertices:v.co=Vector(tuple((oldmat@v.co-anchor)[i]*scale[i] for i in range(3)))+vec(center)
  for mi,m in enumerate(list(mesh.materials)):
   if m:
    key=m.name.lower()
    replacement=wood if 'wood' in key else dark if 'timber' in key else rope if any(k in key for k in ['rope','hemp','binding']) else cloth if any(k in key for k in ['canvas','cloth']) else iron if any(k in key for k in ['iron','metal']) else mat('PlantGreen',(.18,.31,.085)) if any(k in key for k in ['leaf','plant','green']) else mat('Soil',(.10,.055,.025)) if 'soil' in key else None
    if replacement:mesh.materials[mi]=replacement
   if m and m.use_nodes:
    p=m.node_tree.nodes.get('Principled BSDF')
    if p and p.inputs.get('Emission Strength'):p.inputs['Emission Strength'].default_value=0
 return copies
def floor(damaged=False,offset=(0,0,0)):
 def p(x,y,z):return (x+offset[0],y+offset[1],z+offset[2])
 for i in range(7):
  x=(i-3)*.325
  if damaged and i in (2,3,4):
   for side in (-1,1):box('BrokenPlank',p(x,.08,side*.65),(.30,.16,.70),wood)
  else:box('DeckPlank',p(x,.08,0),(.30,.16,2),wood)
  for z in (-.78,.78):cyl('DeckNail',p(x,.172,z),.021,.018,iron)
  # Long shallow cuts are exported geometry, not a missing procedural shader.
  for j in (0,1):box('WoodGrain',p(x+.07*(j-.5),.163,-.28+j*.6),(.012,.003,.38),dark,.002)
 for x in (-.70,.70):box('FloatBeam',p(x,-.10,0),(.30,.30,2.16),dark)
 for x in (-1.11,1.11):box('CellBinding',p(x,.09,0),(.06,.12,2.04),red if damaged else dark)
for name,broken in [('deck-intact',False),('deck-damaged',True)]:begin(name);floor(broken)
begin('root-decor');floor(offset=(-1.175,0,0));floor(offset=(1.175,0,0))
reuse(['GEO-ShelterCanvas','GEO-Canopy'],'ReusedCanopy',(1.92,1.60,1.63),(-1.175,.18,-.09))
for x in (-1.96,-.39):rod('CanopyPost',(x,.18,-.65),(x,1.66,-.65),.045,dark)
# Rebuilt crate uses the old wood/strap design with clean module-local transforms.
for dx,dz in [(1.38,.32),(.80,.48)]:
 for side in (-1,1):
  for j in range(4):box('CrateSlat',(dx+side*.38,.30+j*.14,dz),(.045,.125,.70),wood,.008)
  box('CrateEnd',(dx,.50,dz+side*.35),(.77,.52,.045),wood)
 for j in range(5):box('CrateLid',(dx+(j-2)*.145,.80,dz),(.137,.04,.72),wood,.006)
 for x in (-.27,.27):box('CrateBand',(dx+x,.53,dz),(.045,.59,.76),dark,.005)
 rod('CrateBrace',(dx-.32,.27,dz+.38),(dx+.32,.76,dz+.38),.026,dark)
reuse(['GEO-Barrel'],'ReusedBarrel',(.71,.88,.71),(.65,.18,-.41))
for x in (-2.23,2.23):rod('RootEdgeRope',(x,.31,-.96),(x,.31,.96),.025,rope)
begin('lamp');reuse(['GEO-LanternCap','GEO-LanternCage','GEO-LanternAmberGlass','GEO-LanternHandle'],'ReusedLamp',(.65,.88,.61),(0,.20,-.15));box('LampStand',(0,.24,-.15),(.73,.12,.67),dark)
begin('planter');reuse(['GEO-Planter','GEO-PlantStem','GEO-PlantLeaf'],'ReusedPlanter',(1.19,.95,.89),(0,.18,-.13))
begin('filter');box('FilterStand',(0,.25,-.13),(.98,.13,.87),wood)
for x in (-.34,.34):rod('FilterLeg',(x,.26,-.40),(x,1.28,-.40),.04,dark)
cyl('FilterTank',(0,1.01,-.33),.31,.46,iron);cyl('ClothFilter',(0,1.25,-.33),.315,.035,cloth)
for y in (.84,1.15):cyl('TankRim',(0,y,-.33),.325,.035,dark)
rod('WaterSpout',(.2,.88,-.33),(.34,.72,.10),.035,iron);cyl('Bucket',(.31,.44,.17),.255,.3,iron);cyl('WaterSurface',(.31,.595,.17),.21,.012,water)
begin('medkit');box('ClothBag',(0,.47,-.13),(.94,.50,.70),cloth,.07)
for x in (-.31,.31):box('BagStrap',(x,.48,-.13),(.065,.52,.72),rope,.008)
rod('HandleA',(-.14,.76,-.13),(-.14,.86,-.13),.03,dark);rod('HandleB',(.14,.76,-.13),(.14,.86,-.13),.03,dark);rod('Handle',(-.14,.86,-.13),(.14,.86,-.13),.03,dark)
box('MedicalCrossHorizontal',(0,.50,.225),(.27,.07,.024),red,.003);box('MedicalCrossVertical',(0,.50,.23),(.07,.27,.024),red,.003)
begin('crossbow')
for x in (-.29,.29):rod('Support',(x,.20,-.42),(x,.71,-.18),.04,dark)
rod('Stock',(0,.75,-.62),(0,.75,.42),.075,wood)
for side in (-1,1):
 rod('BowArm',(0,.78,-.33),(side*.35,.78,-.27),.045,dark);rod('BowTip',(side*.35,.78,-.27),(side*.61,.78,-.11),.03,wood);rod('BowString',(side*.61,.78,-.11),(0,.78,.30),.009,rope)
rod('Arrow',(0,.85,-.68),(0,.85,.05),.015,iron)
begin('spearRack')
for x in (-.49,.49):rod('RackPost',(x,.20,-.27),(x,1.20,-.27),.055,dark)
for y in (.43,1.0):box('RackBar',(0,y,-.27),(1.10,.1,.14),wood)
for x in (-.30,0,.30):
 rod('SpearShaft',(x,.22,.05),(x,1.36,-.24),.022,wood)
 bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=.10,radius2=0,depth=.32,location=vec((x,1.49,-.27)));link(bpy.context.object,'SpearTip',iron)
# Merge by material within each module; preserve stable glass naming for lamp state.
for name,col in modules.items():
 batches={}
 for o in list(col.objects):
  key=tuple(m.name for m in o.data.materials)
  if name=='lamp' and 'Glass' in o.name: key=('lamp-glass',)
  batches.setdefault(key,[]).append(o)
 for key,objects in batches.items():
  for o in objects:
   bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
   for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
  obj=bpy.context.object;obj.name='GEO-'+name+'-'+('Glass' if key==('lamp-glass',) else str(len(obj.data.polygons)))
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.cube_project(cube_size=1);bpy.ops.object.mode_set(mode='OBJECT')
# True Blender meshes, with UVs and baked bevels; Godot only instantiates them.
report={'source':str(source),'modules':{}}
for name,col in modules.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in col.objects:o.select_set(True)
 bpy.context.view_layer.objects.active=next(iter(col.objects))
 # Export each independent module, at origin.
 path=OUT/(name+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False)
 report['modules'][name]={'objects':len(col.objects),'bytes':path.stat().st_size}
# Source engineering file retains module collections, preview assembles linked mesh copies.
preview=bpy.data.scenes.new('Initial_123_456');bpy.context.window.scene=preview
layout=[('root-decor',(0,.13,-1.05)),('deck-intact',(3.525,.13,-1.05)),('deck-intact',(-1.175,.13,1.05)),('deck-intact',(1.175,.13,1.05)),('deck-intact',(3.525,.13,1.05))]
for name,offset in layout:
 for o in modules[name].objects:
  c=o.copy();c.data=o.data;preview.collection.objects.link(c);c.location+=vec(offset)
bpy.ops.object.select_all(action='DESELECT')
for o in preview.objects:
 if o.type=='MESH':o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(SRC/'raft_initial_v001.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False)
preview.world=bpy.data.worlds.new('RaftPreviewWorld');preview.world.use_nodes=True;preview.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.17,.22,1)
bpy.ops.object.camera_add(location=(11,-14,13));cam=bpy.context.object;cam.name='CAM-RaftPreview';cam.rotation_euler=(Vector((1,0,.4))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=10;preview.camera=cam
for name,pos,power,size in [('Key',(1,-5,9),1300,7),('Fill',(-5,2,5),700,5)]:
 bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object;light.name='LGT-'+name;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
preview.render.engine='CYCLES';preview.cycles.samples=12;preview.render.resolution_x=1000;preview.render.resolution_y=700;preview.render.resolution_percentage=100
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'raft_modules_v001.blend'))
preview.render.filepath=str(ROOT/'evidence/blender-raft-initial.png');bpy.ops.render.render(write_still=True)
(SRC/'export-report.json').write_text(json.dumps(report,indent=2))
print('RAFT MODULES EXPORTED',json.dumps(report))
# The legacy reuse path collapses planter transforms. Finish with the isolated,
# validated generator so a full raft rebuild cannot restore the broken runtime GLB.
import runpy
runpy.run_path(str(ROOT/'tools/rebuild_planter.py'),run_name='__main__')
runpy.run_path(str(ROOT/'tools/refine_planter_v3.py'),run_name='__main__')
runpy.run_path(str(ROOT/'tools/refine_filter_states.py'),run_name='__main__')
if (ROOT/'assets/textures/stylized-wood-v1/wood-warm-albedo.png').exists():
    runpy.run_path(str(ROOT/'tools/apply_stylized_wood.py'),run_name='__main__')
