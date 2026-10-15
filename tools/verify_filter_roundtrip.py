"""Background Blender: compare editable filter scenes with each GLB re-import."""
import bpy
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'asset-sources/filter-states-v1'

def bounds(scene):
    bpy.context.view_layer.update()
    points=[o.matrix_world@v.co for o in scene.objects if o.type=='MESH' for v in o.data.vertices]
    return [[min(v[k] for v in points) for k in range(3)],[max(v[k] for v in points) for k in range(3)]]

bpy.ops.wm.open_mainfile(filepath=str(OUT/'filter_states_v001.blend'))
report={}
for stage,filename in [('waiting','filter-waiting.glb'),('ready','filter.glb')]:
    original=bpy.data.scenes['Filter_'+stage+'_v001']
    bpy.context.window.scene=original; bpy.context.window.view_layer=original.view_layers[0]
    expected=bounds(original)
    scene=bpy.data.scenes.new('FilterRoundtrip-'+stage)
    bpy.context.window.scene=scene; bpy.context.window.view_layer=scene.view_layers[0]
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/raft-modules'/filename))
    actual=bounds(scene)
    assert all(abs(a-b)<1e-5 for aa,bb in zip(expected,actual) for a,b in zip(aa,bb))
    meshes=[o for o in scene.objects if o.type=='MESH']
    assert len(meshes)==(5 if stage=='waiting' else 6)
    assert all(o.data.uv_layers and not o.modifiers for o in meshes)
    report[stage]={'result':'PASS','bounds_z_up':actual,'meshes':len(meshes),'uvs':True}
(OUT/'roundtrip-validation.json').write_text(json.dumps(report,indent=2))
print('FILTER BLENDER ROUNDTRIP: PASS (2 states)')
