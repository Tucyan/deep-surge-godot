"""Background Blender: compare the saved editable source against a GLB re-import."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
def bounds(scene):
    bpy.context.view_layer.update()
    pts = [o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
    return [[min(v[k] for v in pts) for k in range(3)], [max(v[k] for v in pts) for k in range(3)]]

v3 = ROOT/'asset-sources/planter-v3/planter_v003.blend'
path = v3 if v3.exists() else ROOT/'asset-sources/planter-v2/planter_v002.blend'
bpy.ops.wm.open_mainfile(filepath=str(path))
variants = [('Planter_Mature_v003','planter'),('Planter_Seedling_v003','planter-seedling')] if v3.exists() else [(bpy.context.scene.name,'planter')]
reports = {}
for scene_name,filename in variants:
    source_scene = bpy.data.scenes[scene_name]
    bpy.context.window.scene=source_scene; bpy.context.window.view_layer=source_scene.view_layers[0]
    source = bounds(source_scene)
    assert len(source_scene.objects)==4
    scene = bpy.data.scenes.new('PlanterRoundtrip-'+filename)
    bpy.context.window.scene=scene; bpy.context.window.view_layer=scene.view_layers[0]
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/raft-modules'/(filename+'.glb')))
    restored = bounds(scene)
    assert all(abs(a-b)<1e-5 for aa,bb in zip(source,restored) for a,b in zip(aa,bb))
    meshes = [o for o in scene.objects if o.type=='MESH']
    assert len(meshes)==4 and all(len(o.data.uv_layers)>0 for o in meshes)
    assert all(not o.modifiers for o in meshes)
    reports[filename]={'result':'PASS','source_bounds_z_up':source,'reimport_bounds_z_up':restored,
                       'mesh_batches':4,'uvs':True,'unapplied_modifiers':False}
(path.parent/'roundtrip-validation.json').write_text(json.dumps(reports,indent=2))
print('PLANTER BLENDER ROUNDTRIP: PASS',len(reports),'states')
