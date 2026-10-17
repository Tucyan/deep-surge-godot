"""Center and fit the fishing net inside one raft tile, then export v004."""
import bpy, hashlib, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "asset-sources/raft-wood-unified-v1/fishingNet_v003.blend"
OUTPUT_SOURCE = ROOT / "asset-sources/raft-wood-unified-v1/fishingNet_v004.blend"
OUTPUT_GLB = ROOT / "assets/models/raft-modules/fishingNet.glb"
REPORT = ROOT / "asset-sources/raft-wood-unified-v1/application-report.json"
CELL_HALF_X = 2.35 / 2
CELL_HALF_Z = 2.10 / 2
FIT = 0.92

bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
meshes = [obj for obj in scene.objects if obj.type == "MESH"]
points = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
center_y = (min(p.y for p in points) + max(p.y for p in points)) / 2
for obj in meshes:
    inverse = obj.matrix_world.inverted()
    for vertex in obj.data.vertices:
        world = obj.matrix_world @ vertex.co
        world.x *= FIT
        world.y = (world.y - center_y) * FIT
        vertex.co = inverse @ world
    obj.data.update()

scene.name = "Equipment_fishingNet_v004"
scene_name = scene.name
bpy.context.view_layer.update()
points = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
bounds = [(min(p[i] for p in points), max(p[i] for p in points)) for i in range(3)]
assert max(abs(bounds[0][0]), abs(bounds[0][1])) < CELL_HALF_X
assert max(abs(bounds[1][0]), abs(bounds[1][1])) < CELL_HALF_Z

bpy.ops.object.select_all(action="DESELECT")
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.export_scene.gltf(filepath=str(OUTPUT_GLB), export_format="GLB", use_active_scene=True,
                           use_selection=True, export_apply=True, export_yup=True, export_animations=False)
bpy.data.libraries.write(str(OUTPUT_SOURCE), {scene}, fake_user=True)
bpy.ops.wm.open_mainfile(filepath=str(OUTPUT_SOURCE))
bpy.context.window.scene = bpy.data.scenes[scene_name]
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_SOURCE))

report = json.loads(REPORT.read_text(encoding="utf-8"))
glb = OUTPUT_GLB.read_bytes()
report[OUTPUT_GLB.name] = {
    "texture": "assets/textures/raft-wood/weathered_wood_albedo.png",
    "geometry_unchanged": False,
    "uv_unchanged": True,
    "fit_factor": FIT,
    "centered_blender_y": round(center_y, 6),
    "bounds_blender_xyz": [[round(a, 6), round(b, 6)] for a, b in bounds],
    "cell_spacing_godot_xz": [2.35, 2.1],
    "bytes": len(glb),
    "glb_sha256": hashlib.sha256(glb).hexdigest(),
    "roughness": 0.80,
}
REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("FISHING NET CELL FIT PASS", json.dumps(report[OUTPUT_GLB.name], ensure_ascii=False))
