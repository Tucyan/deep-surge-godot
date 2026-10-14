"""Refine our own v001 source; preserve it and save v003 with a decorative lantern on the crate."""
import bpy
from pathlib import Path
from mathutils import Vector
root=Path('C:/Users/ALmerb/Desktop/MyProgram/yongxian/deep-surge-godot');src=root/'asset-sources/raft-blender-v1'
bpy.ops.wm.open_mainfile(filepath=str(src/'raft_modules_v001.blend'))
scene=bpy.data.scenes['Raft_Modules_v1'];bpy.context.window.scene=scene
col=bpy.data.collections['COL-root-decor'];lamp=bpy.data.collections['COL-lamp']
new=[]
for obj in lamp.objects:
 c=obj.copy();c.data=obj.data.copy();c.name='GEO-DecorativeLantern-'+('Glass' if 'Glass' in obj.name else obj.name)
 c.location=c.location*.65+Vector((1.38,-.32,.703));c.scale*=.65;col.objects.link(c);new.append(c)
 if 'Glass' in c.name:
  for i,m in enumerate(list(c.data.materials)):
   mat=m.copy();c.data.materials[i]=mat
   if mat.use_nodes:
    p=mat.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(1,.52,.14,1);p.inputs['Emission Strength'].default_value=.6
# Copy only new parts into the already inspected assembly preview.
preview=bpy.data.scenes['Initial_123_456']
for o in new:
 c=o.copy();c.data=o.data;preview.collection.objects.link(c);c.location+=Vector((0,1.05,.13))
bpy.ops.object.select_all(action='DESELECT')
for o in col.objects:o.select_set(True)
bpy.context.view_layer.objects.active=next(iter(col.objects))
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.cube_project(cube_size=1);bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/raft-modules/root-decor.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
bpy.context.window.scene=preview;bpy.ops.object.select_all(action='DESELECT')
for o in preview.objects:
 if o.type=='MESH':o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(src/'raft_initial_v003.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(src/'raft_modules_v003.blend'))
print('DECORATIVE LANTERN EXPORTED: cell 2; original v001 preserved')
