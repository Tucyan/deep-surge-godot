"""Apply one untouched user-provided painterly wood map per object category."""
import bpy, json, hashlib
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from equipment_model_lib import ROOT

OUT=ROOT/'asset-sources/stylized-wood-user-v2'
OUT.mkdir(parents=True,exist_ok=True)
REPORT={}

def signature(scene):
    bpy.context.view_layer.update()
    geometry=sorted(tuple(round(c,8) for c in obj.matrix_world@v.co) for obj in scene.objects if obj.type=='MESH' for v in obj.data.vertices)
    uvs=[]
    for obj in scene.objects:
        if obj.type!='MESH' or not obj.data.uv_layers:continue
        uv=obj.data.uv_layers.active
        uvs.extend((obj.name,round(x.uv.x,8),round(x.uv.y,8)) for x in uv.data)
    def sha(values):return hashlib.sha256(json.dumps(values,separators=(',',':')).encode()).hexdigest()
    return sha(geometry),sha(uvs)

def use_image(category):
    image_path=ROOT/'assets/textures/stylized-wood-user-v2'/f'wood-{category}-albedo.png'
    image=bpy.data.images.load(str(image_path),check_existing=False)
    image.name='UserWoodV2-'+category;image.colorspace_settings.name='sRGB';image.pack()
    for mat in bpy.data.materials:
        if 'Wood' not in mat.name or not mat.use_nodes:continue
        nodes=mat.node_tree.nodes;principled=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
        if principled is None:continue
        principled.inputs['Base Color'].default_value=(1,1,1,1)
        principled.inputs['Roughness'].default_value=.90
        texture=next((n for n in nodes if n.type=='TEX_IMAGE'),None)
        if texture is None:
            texture=nodes.new('ShaderNodeTexImage');mat.node_tree.links.new(texture.outputs['Color'],principled.inputs['Base Color'])
        texture.image=image
    return image

def set_scene(scene,name):
    bpy.context.window.scene=scene;bpy.context.window.view_layer=scene.view_layers[0];scene.name=name
    bpy.context.view_layer.update()

def export(scene,path):
    bpy.context.window.scene=scene;bpy.context.window.view_layer=scene.view_layers[0]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in scene.objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=next(o for o in scene.objects if o.type=='MESH')
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_active_scene=True,use_selection=True,export_apply=True,export_yup=True,export_animations=False)
    assert path.stat().st_size<15*1024*1024,path

def save_source(scenes,path,active):
    bpy.data.libraries.write(str(path),set(scenes),fake_user=True)
    bpy.ops.wm.open_mainfile(filepath=str(path));scene=bpy.data.scenes[active]
    bpy.context.window.scene=scene;bpy.context.window.view_layer=scene.view_layers[0]
    bpy.ops.wm.save_as_mainfile(filepath=str(path))

def apply(source,scene_names,category,targets,out_source):
    bpy.ops.wm.open_mainfile(filepath=str(source))
    image=use_image(category);scenes=[]
    new_names=[s.rsplit('_',1)[0]+'_v'+f'{int(s.rsplit("_",1)[1][1:])+1:03d}' for s in scene_names]
    for old_name,new_name,target in zip(scene_names,new_names,targets):
        scene=bpy.data.scenes[old_name];set_scene(scene,new_name);before=signature(scene)
        export(scene,target)
        after=signature(scene);assert before==after,(old_name,'geometry or UV changed')
        scenes.append(scene)
        REPORT[target.name]={'category':category,'texture':'assets/textures/stylized-wood-user-v2/wood-'+category+'-albedo.png',
          'texture_sha256':hashlib.sha256((ROOT/'assets/textures/stylized-wood-user-v2'/f'wood-{category}-albedo.png').read_bytes()).hexdigest(),
          'geometry_signature':before[0],'uv_signature':before[1],'geometry_unchanged':True,'uv_unchanged':True,
          'bytes':target.stat().st_size,'glb_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'roughness':.90}
    save_source(scenes,out_source,scenes[0].name)

apply(ROOT/'asset-sources/wooden-crate-v2/wooden_crate_v002.blend',
 ['Wooden_Crate_v002'],'crate',
 [ROOT/'assets/models/props/wooden-crate.glb'],OUT/'wooden_crate_v003.blend')
apply(ROOT/'asset-sources/planter-v4/planter_v004.blend',
 ['Planter_Mature_v004','Planter_Seedling_v004'],'planter',
 [ROOT/'assets/models/raft-modules/planter.glb',ROOT/'assets/models/raft-modules/planter-seedling.glb'],OUT/'planter_v005.blend')
for key in ['shieldRack','generator','fishingNet']:
    apply(ROOT/'asset-sources/equipment-models-v1'/f'{key}_v001.blend',
      ['Equipment_'+key+'_v001'],key,[ROOT/'assets/models/raft-modules'/f'{key}.glb'],
      OUT/f'{key}_v002.blend')
(OUT/'application-report.json').write_text(json.dumps(REPORT,indent=2)+'\n')
print('USER WOOD V2 APPLIED; geometry and UV signatures preserved for all six GLBs')
