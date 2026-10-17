"""Render a neutral front three-quarter preview of the current fishing net GLB source."""
import bpy
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT / "asset-sources/raft-wood-unified-v1/fishingNet_v004.blend"))
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 960
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(ROOT / "evidence/fishing-net-v20-preview.png")
scene.render.film_transparent = False
if scene.world is None:
    scene.world = bpy.data.worlds.new("World-FishingNetPreview")
scene.world.color = (0.045, 0.055, 0.07)

target = Vector((0, 0, 0.48))
camera_data = bpy.data.cameras.new("CAM-FishingNetPreview")
camera = bpy.data.objects.new("CAM-FishingNetPreview", camera_data)
scene.collection.objects.link(camera)
camera.location = (2.55, -3.9, 2.5)
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 3.55
scene.camera = camera

light_data = bpy.data.lights.new("LGT-FishingNetPreview", "AREA")
light = bpy.data.objects.new("LGT-FishingNetPreview", light_data)
scene.collection.objects.link(light)
light.location = (1.2, -2.5, 4.2)
light.data.energy = 850
light.data.shape = "DISK"
light.data.size = 4.0
light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()

scene.view_settings.view_transform = "AgX"
bpy.ops.render.render(write_still=True)
print("PREVIEW", scene.render.filepath)
