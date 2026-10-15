"""Blender background: imagegen hand-painted wood on crate and both planter stages."""
import bpy
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
TEX=ROOT/'assets/textures/stylized-wood-v1'
REPORT=ROOT/'asset-sources/stylized-wood-v1'; REPORT.mkdir(parents=True,exist_ok=True)

def geometry(scene):
    bpy.context.view_layer.update()
    points=sorted(tuple(round(c,7) for c in o.matrix_world@v.co) for o in scene.objects if o.type=='MESH' for v in o.data.vertices)
    return hashlib.sha256(json.dumps(points).encode()).hexdigest()

def wood_materials():
    materials=[]
    for color in ['warm','dark','grey']:
        mat=bpy.data.materials.new('MAT-StylizedWood-'+color.title());mat.use_nodes=True
        bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        bsdf.inputs['Roughness'].default_value=.90
        bsdf.inputs['Metallic'].default_value=0
        image=bpy.data.images.load(str(TEX/('wood-'+color+'-albedo.png')),check_existing=True)
        image.colorspace_settings.name='sRGB';image.pack()
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=image
        mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
        # No unrelated procedural micro-normal: painterly color carries the grain.
        materials.append(mat)
    return materials

def activate(scene):
    bpy.context.window.scene=scene;bpy.context.window.view_layer=scene.view_layers[0]
    bpy.context.view_layer.update()

def export(scene,path,backup):
    if not backup.exists():backup.write_bytes(path.read_bytes())
    activate(scene);bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_active_scene=True,use_selection=True,export_apply=True,export_yup=True,export_animations=False)
    assert path.stat().st_size<15*1024*1024

def save(scenes,path,active):
    bpy.data.libraries.write(str(path),set(scenes),fake_user=True)
    bpy.ops.wm.open_mainfile(filepath=str(path));activate(bpy.data.scenes[active])
    bpy.ops.wm.save_as_mainfile(filepath=str(path))

reports={}
# Existing crate geometry, hinge and per-board directional UVs are preserved exactly.
folder=ROOT/'asset-sources/wooden-crate-v2';folder.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'asset-sources/wooden-crate-v1/wooden_crate_v001.blend'))
scene=bpy.data.scenes['Wooden_Crate_v001'];activate(scene);before=geometry(scene)
materials=wood_materials();mapping=dict(zip(['Warm','Dark','Grey'],materials))
for obj in scene.objects:
    if obj.type!='MESH':continue
    for i,mat in enumerate(obj.data.materials):
        if mat and 'Wood' in mat.name:obj.data.materials[i]=mapping[mat.name.rsplit('-',1)[-1]]
assert geometry(scene)==before
scene.name='Wooden_Crate_v002'
path=ROOT/'assets/models/props/wooden-crate.glb'
export(scene,path,folder/'wooden-crate-before.glb')
reports['crate']={'geometry_unchanged':True,'geometry_signature':before,'bytes':path.stat().st_size,'source':'asset-sources/wooden-crate-v2/wooden_crate_v002.blend'}
save([scene],folder/'wooden_crate_v002.blend',scene.name)

# Per connected plank: grain U follows height on walls, horizontal on the bottom.
folder=ROOT/'asset-sources/planter-v4';folder.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'asset-sources/planter-v3/planter_v003.blend'))
materials=wood_materials();scenes=[]
for old_name,new_name,filename in [('Planter_Mature_v003','Planter_Mature_v004','planter.glb'),('Planter_Seedling_v003','Planter_Seedling_v004','planter-seedling.glb')]:
    scene=bpy.data.scenes[old_name];activate(scene);before=geometry(scene)
    obj=next(o for o in scene.objects if o.type=='MESH' and any('Wood' in m.name for m in o.data.materials))
    mesh=obj.data;mesh.materials.clear()
    for mat in materials:mesh.materials.append(mat)
    adj=[set() for v in mesh.vertices]
    for edge in mesh.edges:
        a,b=edge.vertices;adj[a].add(b);adj[b].add(a)
    remaining=set(range(len(mesh.vertices)));components=[]
    while remaining:
        start=min(remaining);remaining.remove(start);todo=[start];found=[start]
        while todo:
            for key in adj[todo.pop()] & remaining:
                remaining.remove(key);todo.append(key);found.append(key)
        components.append(found)
    assert len(components)==11
    vertex_component={key:i for i,c in enumerate(components) for key in c}
    bounds=[([min(mesh.vertices[k].co[a] for k in c) for a in range(3)],[max(mesh.vertices[k].co[a] for k in c) for a in range(3)]) for c in components]
    uv=mesh.uv_layers.active;mesh.update()
    palette=[0,2,0,1,0,0,2,0,1,0,0]
    for face in mesh.polygons:
        index=vertex_component[face.vertices[0]];mn,mx=bounds[index]
        face.material_index=palette[index%len(palette)]
        sizes=[max(mx[a]-mn[a],.001) for a in range(3)]
        wall=sizes[2]>.12;axis=max(range(3),key=lambda a:abs(face.normal[a]))
        for li in face.loop_indices:
            v=mesh.vertices[mesh.loops[li].vertex_index].co
            unit=[(v[a]-mn[a])/sizes[a] for a in range(3)]
            if wall and axis!=2:
                along=1-unit[2] if index%2 else unit[2]
                cross=unit[1] if axis==0 else unit[0]
                xy=(along*(.66+(index%4)*.035)+.035+(index%3)*.045,
                    cross*(.34+(index%3)*.04)+.08+((index*7)%11)/11*.42)
            else:xy=(unit[0]*.80+.06,unit[1]*.70+.12)
            uv.data[li].uv=xy
    assert geometry(scene)==before
    scene.name=new_name;scenes.append(scene)
    path=ROOT/'assets/models/raft-modules'/filename
    export(scene,path,folder/(filename.removesuffix('.glb')+'-before.glb'))
    reports[filename]={'geometry_unchanged':True,'geometry_signature':before,'bytes':path.stat().st_size,'plank_count':11,'source':'asset-sources/planter-v4/planter_v004.blend'}
save(scenes,folder/'planter_v004.blend','Planter_Mature_v004')
(REPORT/'application-report.json').write_text(json.dumps(reports,indent=2))
print('STYLIZED IMAGEGEN WOOD APPLIED: crate + mature/seedling planter; geometry unchanged')
