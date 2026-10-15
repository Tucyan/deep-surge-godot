"""Run with Blender --background --python; rebuild only the planter from intact parts."""
import bpy
import json
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent/'raft-model/raft_v004.blend'
OUT = ROOT/'asset-sources/planter-v2'
OUT.mkdir(parents=True, exist_ok=True)
runtime = ROOT/'assets/models/raft-modules/planter.glb'
backup = OUT/'planter-before.glb'
if not backup.exists():
    backup.write_bytes(runtime.read_bytes())

# Background process only. Never modify the user's running Blender or original file.
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
originals = [o for o in bpy.context.scene.objects if o.type == 'MESH'
             and o.name.startswith(('GEO-Planter','GEO-PlantStem','GEO-PlantLeaf'))]
assert len(originals) == 55, len(originals)
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
snapshots = []
# Capture ALL evaluated world transforms before creating or resetting any objects.
for o in originals:
    evaluated = o.evaluated_get(deps)
    mesh = bpy.data.meshes.new_from_object(evaluated, depsgraph=deps)
    matrix = evaluated.matrix_world.copy()
    for v in mesh.vertices:
        v.co = matrix @ v.co
    snapshots.append((o.name, mesh))
points = [v.co.copy() for _, mesh in snapshots for v in mesh.vertices]
mn = Vector(tuple(min(v[k] for v in points) for k in range(3)))
mx = Vector(tuple(max(v[k] for v in points) for k in range(3)))
anchor = Vector(((mn.x+mx.x)/2, (mn.y+mx.y)/2, mn.z))
scale = Vector((1.19/(mx.x-mn.x), .89/(mx.y-mn.y), .95/(mx.z-mn.z)))
offset = Vector((0,.13,.18))  # Blender Z-up; Godot offset (0,.18,-.13).

scene = bpy.data.scenes.new('Planter_v002')
scene.unit_settings.system = 'METRIC'; scene.unit_settings.scale_length = 1
bpy.context.window.scene = scene
materials = {}
for name,color in [('Wood',(.32,.19,.095)),('Soil',(.10,.055,.025)),
                   ('PlantGreen',(.18,.31,.085)),('PlantGreenLight',(.27,.40,.12))]:
    m = bpy.data.materials.new('MAT-PlanterV2-'+name); m.use_nodes = True
    m.diffuse_color = (*color,1)
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*color,1)
    p.inputs['Roughness'].default_value = .82
    m.use_backface_culling = False
    materials[name] = m
objects = []
for name,mesh in snapshots:
    for v in mesh.vertices:
        v.co = Vector(tuple((v.co[k]-anchor[k])*scale[k] for k in range(3)))+offset
    kind = 'Soil' if 'Soil' in name else ('PlantGreenLight' if int(name.rsplit('_',1)[-1])%2 == 0
             else 'PlantGreen') if 'Leaf' in name else 'PlantGreen' if 'Stem' in name else 'Wood'
    mesh.materials.clear(); mesh.materials.append(materials[kind])
    for p in mesh.polygons: p.material_index = 0
    o = bpy.data.objects.new(name,mesh); scene.collection.objects.link(o)
    o.matrix_world = Matrix.Identity(4); objects.append(o)

# Close the bottom beneath the soil, with overlap into the four sides.
bpy.ops.mesh.primitive_cube_add(size=1, location=(0,.13,.205))
base = bpy.context.object; base.name = 'GEO-PlanterBase'
base.scale = (1.10,.79,.05); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
base.data.materials.append(materials['Wood']); objects.append(base)

# Join only objects of the same material in this dedicated scene.
for mat in materials.values():
    batch = [o for o in list(scene.objects) if o.type == 'MESH' and o.data.materials[0] == mat]
    bpy.ops.object.select_all(action='DESELECT')
    for o in batch: o.select_set(True)
    bpy.context.view_layer.objects.active = batch[0]
    if len(batch) > 1:
        bpy.ops.object.join()
    obj = bpy.context.object; obj.name = 'GEO-PlanterV2-'+mat.name.rsplit('-',1)[-1]
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=1); bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=str(runtime), export_format='GLB',use_selection=True,
                          export_apply=True,export_yup=True,export_animations=False)
# Save just this scene and its dependencies, not the original raft scenes.
bpy.data.libraries.write(str(OUT/'planter_v002.blend'),{scene},fake_user=True)
# Normalize the isolated library as a regular editable project with UI scene data.
bpy.ops.wm.open_mainfile(filepath=str(OUT/'planter_v002.blend'))
assert len([o for o in bpy.context.scene.objects if o.type == 'MESH']) == 4
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'planter_v002.blend'))
(OUT/'build-report.json').write_text(json.dumps({'source':'raft-model/raft_v004.blend',
    'source_parts':len(originals),'stem_count':11,'leaf_count':33,
    'target_dimensions_y_up':[1.19,.95,.89], 'base_y':.18,
    'runtime':'assets/models/raft-modules/planter.glb',
    'transform_policy':'snapshot evaluated world meshes first; one common scale and offset'},indent=2))
print('PLANTER REBUILD COMPLETE',runtime.stat().st_size)
