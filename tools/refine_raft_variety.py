"""Versioned Blender deck variants and interior lantern; visual seed never touches rules."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]; S=R/'asset-sources/raft-blender-v1'; O=R/'assets/models/raft-modules'
bpy.ops.wm.open_mainfile(filepath=str(S/'raft_modules_v004.blend'))
scene=bpy.data.scenes['Raft_Modules_v1'];bpy.context.window.scene=scene
preview=bpy.data.scenes['Initial_123_456']
print('INSPECT',[(c.name,len(c.objects)) for c in scene.collection.children])
# Three deterministic plank profiles, all contained within the cell's contact footprint.
def profile(x,y,z,k,cx=0):
 i=max(0,min(6,round((x-cx)/.325)+3));rng=random.Random(5100+k*97+i*13)
 shift=rng.uniform(-.03,.03)+(0 if k==0 else (.045 if i%2 else -.045) if k==1 else (i-3)*.018);length=rng.uniform(.94,1.015);tilt=rng.uniform(-.012,.012)
 return Vector((x+.009*math.sin(y*3+i+k),y*length+shift,z+tilt*math.cos(y*1.2)))
def refine(col,k,root=False):
 for o in col.objects:
  if o.type!='MESH':continue
  # Work in module space, preserving higher props, tent and lantern.
  world=[o.matrix_world@v.co for v in o.data.vertices];inv=o.matrix_world.inverted()
  woodslots=[i for i,m in enumerate(o.data.materials) if m and 'WarmWeatheredWood' in m.name]
  palette={}
  for slot in woodslots:
   base=o.data.materials[slot]
   for i in range(7):
    m=base.copy();m.name=f'MAT-DeckWood-{k}-{i}';f=[.91,1.04,.97,1.08,.94,1.01,.98][(i+k*2)%7]
    p=m.node_tree.nodes.get('Principled BSDF');c=base.diffuse_color;m.diffuse_color=(c[0]*f,c[1]*f,c[2]*f,1);p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Roughness'].default_value=.73+.025*((i+k)%5)
    palette[(slot,i)]=len(o.data.materials);o.data.materials.append(m)
  for p in o.data.polygons:
   pts=[world[i] for i in p.vertices]
   if p.material_index in woodslots and max(v.z for v in pts)<.185:
    x=sum(v.x for v in pts)/len(pts);cx=(-1.175 if x<0 else 1.175) if root else 0
    i=max(0,min(6,round((x-cx)/.325)+3));p.material_index=palette[(p.material_index,i)]
  for v,w in zip(o.data.vertices,world):
   if w.z>.19:continue
   cx=(-1.175 if w.x<0 else 1.175) if root else 0
   q=profile(w.x,w.y,w.z,(0 if cx<0 else 1) if root else k,cx)
   if o.data.materials and 'DarkTimber' in o.data.materials[0].name and .155<w.z<.17 and abs(w.x-cx)<1.06:
    i=max(0,min(6,round((w.x-cx)/.325)+3));center=.28 if w.y>0 else -.32
    q.y=center+(q.y-center)*(.65+.12*((i+k)%5));q.x+=.012*math.sin(i*2+k)
   v.co=inv@q
  o.data.update()
def export(col,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in col.objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(O/(name+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_animations=False)
# Independent copies before modifying the base; each has its own mesh/material palette.
cols={}
for status in ['intact','damaged']:
 original=bpy.data.collections['COL-deck-'+status]
 for k in [1,2]:
  name='deck-'+status+'-'+str(k+1);c=bpy.data.collections.new('COL-'+name);scene.collection.children.link(c)
  for o in original.objects:
   n=o.copy();n.data=o.data.copy();c.objects.link(n)
  cols[name]=(c,k)
 cols['deck-'+status]=(original,0)
for name,(c,k) in cols.items():refine(c,k);export(c,name)
root=bpy.data.collections['COL-root-decor'];refine(root,0,True)
# Small lantern inside the entrance. Reuse exact metal/glass mesh and warm emission.
for o in bpy.data.collections['COL-lamp'].objects:
 n=o.copy();n.data=o.data.copy();n.name='GEO-TentLantern-'+('Glass' if 'Glass' in o.name else o.name);root.objects.link(n)
 for v in n.data.vertices:v.co=n.matrix_world@v.co*.43+Vector((-1.50,-.40,.15))
 n.matrix_world.identity()
 for i,m in enumerate(list(n.data.materials)):
  if 'Glass' in n.name:
   m=m.copy();n.data.materials[i]=m;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(1,.52,.14,1);p.inputs['Emission Strength'].default_value=.6
 c=n.copy();c.data=n.data;preview.collection.objects.link(c);c.location+=Vector((0,1.05,.13))
export(root,'root-decor')
# Replace preview deck meshes with the coordinate-selected variants.
for o in list(preview.objects):
 if o.type=='MESH' and o.name.startswith('GEO-deck-intact'):bpy.data.objects.remove(o,do_unlink=True)
for x,y in [(2,0),(0,1),(1,1),(2,1)]:
 k=(x+y*2)%3;name='deck-intact'+('' if k==0 else '-'+str(k+1))
 for o in cols[name][0].objects:
  c=o.copy();c.data=o.data;preview.collection.objects.link(c);c.location+=Vector(((x-.5)*2.35,-(y-.5)*2.1,.13))
bpy.context.window.scene=preview;bpy.ops.object.select_all(action='DESELECT')
for o in preview.objects:
 if o.type=='MESH':o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(S/'raft_initial_v005.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(S/'raft_modules_v005.blend'))
preview.render.filepath=str(R/'evidence/blender-raft-v005.png');bpy.ops.render.render(write_still=True)
print('V005 COMPLETE: three intact/damaged profiles, subtle per-plank palette, tent lantern')
