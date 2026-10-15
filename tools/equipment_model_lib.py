"""Blender-only modeling helpers for the sequential equipment art set."""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[1]

def material(name,color,rough=.82,metal=0,emission=0):
    mat=bpy.data.materials.new('MAT-Equipment-'+name);mat.use_nodes=True
    p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
    return mat

def palette():
    mats={}
    for color in ['warm','dark','grey']:
        mat=material('Wood-'+color,(.4,.25,.1),.90)
        p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        image=bpy.data.images.load(str(ROOT/'assets/textures/stylized-wood-v1'/('wood-'+color+'-albedo.png')),check_existing=True);image.pack();image.colorspace_settings.name='sRGB'
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;mat.node_tree.links.new(node.outputs['Color'],p.inputs['Base Color'])
        mats[color]=mat
    for key,color,rough,metal in [('iron',(.075,.095,.10),.7,1),('rim',(.21,.25,.25),.62,1),('brass',(.43,.26,.10),.6,1),('hemp',(.43,.34,.21),.95,0),('teal',(.025,.075,.07),.85,0),('rubber',(.025,.032,.028),.94,0),('ivory',(.62,.59,.43),.88,0),('cork',(.53,.25,.10),.96,0)]:
        mats[key]=material(key,color,rough,metal)
    mats['gauge']=material('WarmGauge',(.60,.32,.08),.7,0,.3)
    return mats

def uv_project(obj,long_axis=None):
    mesh=obj.data;mesh.update()
    mn=[min(v.co[i] for v in mesh.vertices) for i in range(3)];mx=[max(v.co[i] for v in mesh.vertices) for i in range(3)]
    span=[max(mx[i]-mn[i],1e-5) for i in range(3)]
    long_axis=max(range(3),key=lambda i:span[i]) if long_axis is None else long_axis
    uv=mesh.uv_layers.active or mesh.uv_layers.new(name='UVMap')
    for face in mesh.polygons:
        normal_axis=max(range(3),key=lambda i:abs(face.normal[i]))
        axes=[i for i in range(3) if i!=normal_axis]
        if long_axis in axes:axes.remove(long_axis);axes.insert(0,long_axis)
        for li in face.loop_indices:
            v=mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv=tuple((v[i]-mn[i])/span[i]*.76+.10 for i in axes)

def mesh(name,verts,faces,mat,long_axis=None):
    data=bpy.data.meshes.new('GEO-'+name);data.from_pydata(verts,[],faces);data.materials.append(mat)
    obj=bpy.data.objects.new('GEO-'+name,data);bpy.context.scene.collection.objects.link(obj)
    uv_project(obj,long_axis);return obj

def finish_primitive(obj,name,mat,bevel=0):
    obj.name='GEO-'+name;obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=obj.modifiers.new('SoftWornEdges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    uv_project(obj);return obj

def box(name,pos,size,mat,bevel=.012,rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    obj=bpy.context.object;obj.scale=size;obj.rotation_euler=rotation
    return finish_primitive(obj,name,mat,bevel)

def cylinder(name,a,b,r,mat,vertices=16,bevel=.005):
    a=Vector(a);b=Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=(b-a).length,location=(a+b)/2)
    obj=bpy.context.object;obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return finish_primitive(obj,name,mat,bevel)

def sphere(name,pos,scale,mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=pos)
    obj=bpy.context.object;obj.scale=scale
    return finish_primitive(obj,name,mat)

def beam(name,a,b,width,depth,mat):
    a=Vector(a);b=Vector(b)
    bpy.ops.mesh.primitive_cube_add(size=1,location=(a+b)/2)
    obj=bpy.context.object;obj.scale=(width,depth,(b-a).length);obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return finish_primitive(obj,name,mat,.01)

def tube(name,points,r,mat,sides=5,closed=False):
    points=[Vector(p) for p in points];verts=[];faces=[];previous_x=None
    for j,p in enumerate(points):
        tangent=(points[(j+1)%len(points)]-points[j-1 if j else (-1 if closed else 0)]) if j<len(points)-1 or closed else p-points[j-1]
        tangent.normalize();ref=Vector((0,0,1)) if abs(tangent.z)<.85 else Vector((0,1,0))
        x=(previous_x-tangent*previous_x.dot(tangent)).normalized() if previous_x is not None else tangent.cross(ref).normalized()
        if x.length<.5:x=tangent.cross(ref).normalized()
        previous_x=x.copy();y=tangent.cross(x).normalized()
        for k in range(sides):
            a=k*math.tau/sides;verts.append(tuple(p+r*(math.cos(a)*x+math.sin(a)*y)))
    for j in range(len(points) if closed else len(points)-1):
        nxt=(j+1)%len(points)
        for k in range(sides):faces.append((j*sides+k,j*sides+(k+1)%sides,nxt*sides+(k+1)%sides,nxt*sides+k))
    if not closed:faces += [tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))]
    return mesh(name,verts,faces,mat)

def panel(name,outline,depth,mat,frame=None):
    # Outline is in XZ, panel faces +/-Y. Closed, truly thick silhouette.
    verts=[(x,y,z) for y in [-depth/2,depth/2] for x,z in outline];n=len(outline)
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    obj=mesh(name,verts,faces,mat,2)
    if frame is not None:obj.matrix_world=frame
    return obj

def clip_x(poly,bound,keep_greater):
    result=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        inside_a=a[0]>=bound if keep_greater else a[0]<=bound
        inside_b=b[0]>=bound if keep_greater else b[0]<=bound
        if inside_a:result.append(a)
        if inside_a!=inside_b:
            t=(bound-a[0])/(b[0]-a[0]);result.append((bound,a[1]+(b[1]-a[1])*t))
    return result

def finalize(scene,asset_id,out_path,source_path):
    # Batched by material only; rule/data objects are never part of this scene.
    mats=set(m for o in scene.objects if o.type=='MESH' for m in o.data.materials)
    for mat in sorted(mats,key=lambda m:m.name):
        batch=[o for o in list(scene.objects) if o.type=='MESH' and o.data.materials[0]==mat]
        bpy.ops.object.select_all(action='DESELECT')
        for obj in batch:obj.select_set(True)
        bpy.context.view_layer.objects.active=batch[0]
        if len(batch)>1:bpy.ops.object.join()
        obj=bpy.context.object;obj.name='GEO-'+asset_id+'-'+mat.name.removeprefix('MAT-Equipment-')
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.normal_update()
        bm.to_mesh(obj.data);bm.free();obj.data.update()
    bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=str(out_path),export_format='GLB',use_active_scene=True,use_selection=True,export_apply=True,export_yup=True,export_animations=False)
    bpy.data.libraries.write(str(source_path),{scene},fake_user=True)
    bpy.ops.wm.open_mainfile(filepath=str(source_path))
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
