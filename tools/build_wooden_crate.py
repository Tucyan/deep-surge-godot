"""Blender background. Hand-built supply crate, independent of gameplay/old raft scenes."""
import bpy
import bmesh
import json
import math
import random
import struct
import sys
from pathlib import Path
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'asset-sources/wooden-crate-v1'; OUT.mkdir(parents=True,exist_ok=True)
RUNTIME=ROOT/'assets/models/props'; RUNTIME.mkdir(parents=True,exist_ok=True)
BLOCKOUT='--blockout' in sys.argv
rng=random.Random(35104)
scene=bpy.data.scenes.new('Wooden_Crate_v001'); bpy.context.window.scene=scene
bpy.context.window.view_layer=scene.view_layers[0]
scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
body=bpy.data.objects.new('CrateBody',None); scene.collection.objects.link(body)
lid=bpy.data.objects.new('CrateLid',None); scene.collection.objects.link(lid)
# Closed pose: lid origin lies on the rear hinge axis for future authoring.
lid.location=(0,.413,.716)
wood=[]
for label,color in [('Warm',(.36,.25,.13)),('Dark',(.25,.16,.08)),('Grey',(.39,.32,.22))]:
    mat=bpy.data.materials.new('MAT-Crate-Wood-'+label); mat.use_nodes=True
    p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.83
    wood.append(mat)
def simple_mat(name,color,rough,metal=0):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return mat
iron=simple_mat('MAT-Crate-AgedIron',(.065,.075,.075),.68,1)
rope=simple_mat('MAT-Crate-Hemp',(.34,.25,.14),.96)
board_info=[]

def attach(obj,parent):
    matrix=obj.matrix_world.copy();obj.parent=parent;obj.matrix_world=matrix

def plank(name,pos,length,width,thickness,rotation=(0,0,0),parent=body,variant=None):
    # Six sections and a chamfered eight-sided section produce actual bowed/worn geometry.
    w=width/2;t=thickness/2;b=min(.004,w*.12,t*.4)
    section=[(-w+b,-t),(w-b,-t),(w,-t+b),(w,t-b),(w-b,t),(-w+b,t),(-w,t-b),(-w,-t+b)]
    bow=rng.uniform(-.006,.006); phase=rng.uniform(0,math.tau)
    vertices=[]
    for j in range(7):
        u=j/6; offset=bow*math.sin(math.pi*u)
        waviness=.002*math.sin(u*math.tau+phase)
        for k,(yy,zz) in enumerate(section):
            chip=rng.uniform(-.003,.003) if j in [0,6] else 0
            vertices.append(((u-.5)*length+chip,yy+waviness,zz+offset))
    faces=[tuple(reversed(range(8))),tuple(range(48,56))]
    faces += [(j*8+k,j*8+(k+1)%8,(j+1)*8+(k+1)%8,(j+1)*8+k) for j in range(6) for k in range(8)]
    mesh=bpy.data.meshes.new('GEO-'+name);mesh.from_pydata(vertices,[],faces)
    uv=mesh.uv_layers.new(name='TimberAlongLength')
    mesh.update()
    seed=rng.uniform(.035,.11)
    for face in mesh.polygons:
        for li in face.loop_indices:
            v=mesh.vertices[mesh.loops[li].vertex_index].co
            # Per-board islands stay inside the bitmap, with no repeating-image seam.
            if abs(face.normal.x)>.75:
                xy=((v.y/width+.5)*.6+.2,(v.z/thickness+.5)*.6+.2)
            else:
                across=(v.z/thickness if abs(face.normal.z)<.5 else v.y/width)+.5
                xy=((v.x/length+.5)*.80+seed,across*.68+.14)
            uv.data[li].uv=xy
    obj=bpy.data.objects.new('GEO-'+name,mesh);scene.collection.objects.link(obj)
    obj.location=pos
    if isinstance(rotation,Matrix):obj.rotation_euler=rotation.to_euler()
    else:obj.rotation_euler=rotation
    obj.data.materials.append(wood[variant if variant is not None else rng.choices([0,1,2],[6,2,2])[0]])
    bpy.context.view_layer.update();attach(obj,parent)
    board_info.append({'name':obj.name,'length':length,'width':width,'bow':bow,'position':list(pos)})
    return obj

# Bottom, horizontal wall courses and slightly mismatched end panels.
for i in range(5):plank('Bottom-%d'%i,(0,(i-2)*.145,.044),.99,.151,.045)
for side in [-1,1]:
    for j in range(4):
        plank('Wall-%s-%d'%('Front' if side<0 else 'Back',j),(rng.uniform(-.009,.009),side*.365,.13+j*.158+rng.uniform(-.004,.004)),1.0+rng.uniform(-.025,.028),.158+rng.uniform(-.005,.005),.043,(side*math.pi/2,rng.uniform(-.006,.006),rng.uniform(-.006,.006)))
    for j in range(4):
        # Local long axis follows depth, face normal points out along X.
        rotation=Matrix(((0,0,1),(1,0,0),(0,1,0)))
        plank('End-%d-%d'%(side,j),(side*.496,rng.uniform(-.007,.007),.13+j*.158),.733+rng.uniform(-.018,.021),.159+rng.uniform(-.004,.004),.041,rotation)
for x in [-1,1]:
    for y in [-1,1]:
        rotation=Matrix(((0,1,0),(0,0,1),(1,0,0)))
        plank('CornerPost-%d-%d'%(x,y),(x*.472,y*.39,.383),.695+rng.uniform(-.015,.015),.073,.064,rotation,variant=1 if x*y<0 else 0)
# Reinforcing front diagonal, not a perfect symmetrical X.
a=Vector((-.42,-.410,.11));b=Vector((.42,-.410,.626));long=(b-a).normalized();normal=Vector((0,-1,0));across=normal.cross(long)
rotation=Matrix((long,across,normal)).transposed()
plank('FrontDiagonal',(a+b)/2,(b-a).length,.072,.028,rotation,variant=2)

for i in range(5):
    plank('LidPlank-%d'%i,(rng.uniform(-.012,.012),(i-2)*.158,.725+rng.uniform(-.005,.007)),1.078+rng.uniform(-.025,.022),.161+rng.uniform(-.004,.004),.045,(rng.uniform(-.004,.004),rng.uniform(-.005,.005),rng.uniform(-.006,.006)),lid)
for x in [-.32,.33]:plank('LidBatten-'+str(x),(x,0,.776),.835,.065,.035,(0,0,math.pi/2+rng.uniform(-.01,.01)),lid,variant=1)
bpy.context.view_layer.update()

if not BLOCKOUT:
    # Image textures with packed export-supported PBR nodes; long axis UV follows grain.
    tex=ROOT/'assets/textures/wooden-crate-v1'
    for mat,base in zip(wood,['wood-albedo','wood-dark-albedo','wood-grey-albedo']):
        nt=mat.node_tree;p=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
        for suffix,filename in [('base',base),('rough','wood-roughness'),('normal','wood-normal')]:
            node=nt.nodes.new('ShaderNodeTexImage');node.image=bpy.data.images.load(str(tex/(filename+'.png')),check_existing=True)
            node.image.colorspace_settings.name='sRGB' if suffix=='base' else 'Non-Color';node.image.pack()
            if suffix=='base':nt.links.new(node.outputs['Color'],p.inputs['Base Color'])
            elif suffix=='rough':nt.links.new(node.outputs['Color'],p.inputs['Roughness'])
            else:
                normal=nt.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.18
                nt.links.new(node.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs['Normal'],p.inputs['Normal'])
    def box(name,pos,size,mat,parent=body):
        bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
        obj=bpy.context.object;obj.name='GEO-'+name;obj.scale=size
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);obj.data.materials.append(mat)
        mod=obj.modifiers.new('WornEdges','BEVEL');mod.width=.003;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name);attach(obj,parent)
        return obj
    def rod(name,a,b,r,mat,parent=body,vertices=8):
        a=Vector(a);b=Vector(b)
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=(b-a).length,location=(a+b)/2)
        obj=bpy.context.object;obj.name='GEO-'+name;obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();obj.data.materials.append(mat)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);attach(obj,parent)
        return obj
    # Forged heads inset into the faces, with small placement variation.
    for side in [-1,1]:
        for j in range(4):
            for x in [-.468,.468]:
                z=.13+j*.158+rng.uniform(-.004,.004)
                rod('NailHead',(x,side*.421,z),(x,side*.427,z),.012,iron)
    for x in [-.32,.33]:
        for y in [-.29,.28]:rod('LidNail',(x,y,.791),(x,y,.799),.012,iron,lid)
        box('HingeBody',(x,.403,.676),(.068,.012,.074),iron)
        box('HingeLid',(x,.372,.750),(.068,.067,.010),iron,lid)
        rod('HingePin',(x-.050,.413,.716),(x+.050,.413,.716),.012,iron)
    box('LatchBody',(0,-.428,.635),(.070,.014,.082),iron)
    box('LatchTongue',(0,-.433,.699),(.046,.020,.093),iron,lid)
    box('LatchSlot',(0,-.446,.655),(.027,.008,.016),iron)
    for x,z in [(-.39,.13),(.39,.61)]:rod('BraceNail',(x,-.424,z),(x,-.431,z),.013,iron)
    # Drooping rope handles on both ends, with helical strand geometry.
    for side in [-1,1]:
        for y in [-.12,.12]:
            rod('HandleEye',(side*.526,y,.438),(side*.548,y,.438),.023,iron)
        for strand in range(3):
            vertices=[];faces=[];steps=32;sides=5
            for j in range(steps):
                t=j/(steps-1);theta=t*math.tau*5+strand*math.tau/3
                center=Vector((side*(.542+.040*math.sin(math.pi*t)),-.12+.24*t,.438-.105*math.sin(math.pi*t)))
                center+=Vector((.003*math.cos(theta),0,.003*math.sin(theta)))
                for k in range(sides):
                    a=k*math.tau/sides;vertices.append(tuple(center+Vector((.0045*math.cos(a),0,.0045*math.sin(a)))))
            for j in range(steps-1):
                for k in range(sides):faces.append((j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k))
            faces.extend([tuple(reversed(range(sides))),tuple(range((steps-1)*sides,steps*sides))])
            mesh=bpy.data.meshes.new('GEO-RopeStrand');mesh.from_pydata(vertices,[],faces);mesh.materials.append(rope)
            obj=bpy.data.objects.new('GEO-HandleRope',mesh);scene.collection.objects.link(obj);attach(obj,body)

# Merge material batches per body/lid, preserving a separately editable lid pivot.
for parent in [body,lid]:
    for mat in wood+[iron,rope]:
        batch=[o for o in list(scene.objects) if o.type=='MESH' and o.parent==parent and o.data.materials[0]==mat]
        if not batch:continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in batch:obj.select_set(True)
        bpy.context.view_layer.objects.active=batch[0]
        if len(batch)>1:bpy.ops.object.join()
        obj=bpy.context.object;obj.name='GEO-'+parent.name+'-'+mat.name.removeprefix('MAT-Crate-')
        # For hardware only; boards retain their authored directional UVs.
        if not obj.data.uv_layers:
            bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.cube_project(cube_size=1);bpy.ops.object.mode_set(mode='OBJECT')
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)

bpy.context.view_layer.update()
points=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
bottom=min(v.z for v in points)
body.location.z-=bottom;lid.location.z-=bottom
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='SELECT')
path=OUT/'crate_blockout.glb' if BLOCKOUT else RUNTIME/'wooden-crate.glb'
bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_yup=True,export_animations=False,export_tangents=not BLOCKOUT)
points=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
mn=[min(v[i] for v in points) for i in range(3)];mx=[max(v[i] for v in points) for i in range(3)]
report={'visual_seed':35104,'boards':board_info,'board_count':len(board_info),'scope':'standalone staged prop; no storage rules or installation','lid_pivot_blender':list(lid.location),'bounds_z_up':[mn,mx],'dimensions_y_up':[mx[0]-mn[0],mx[2]-mn[2],mx[1]-mn[1]]}
(OUT/('blockout-report.json' if BLOCKOUT else 'build-report.json')).write_text(json.dumps(report,indent=2))
if not BLOCKOUT:
    bpy.data.libraries.write(str(OUT/'wooden_crate_v001.blend'),{scene},fake_user=True)
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'wooden_crate_v001.blend'))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'wooden_crate_v001.blend'))
print('WOODEN CRATE '+('BLOCKOUT' if BLOCKOUT else 'FINAL')+':',len(board_info),'irregular timber boards',path.stat().st_size,'bytes')
if not BLOCKOUT and (ROOT/'assets/textures/stylized-wood-v1/wood-warm-albedo.png').exists():
    import runpy
    runpy.run_path(str(ROOT/'tools/apply_stylized_wood.py'),run_name='__main__')
