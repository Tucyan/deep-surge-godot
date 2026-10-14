import pathlib,json,struct,numpy as np
root=pathlib.Path('.');report={}
for path in sorted((root/'assets/models/raft-modules').glob('*.glb')):
 data=path.read_bytes();magic,version,total=struct.unpack_from('<4sII',data);assert magic==b'glTF' and total==len(data)
 jl=struct.unpack_from('<I',data,12)[0];g=json.loads(data[20:20+jl]);binary=data[28+jl:];tri=0
 for mesh in g['meshes']:
  for p in mesh['primitives']:
   assert all(k in p['attributes'] for k in ['POSITION','NORMAL','TEXCOORD_0']),path
   tri+=g['accessors'][p['indices']]['count']//3
 assert len(data)<15*1024**2 and tri>0
 report[path.stem]={'triangles':tri,'meshes':len(g['meshes']),'bytes':len(data),'normals_uvs':True}
(root/'asset-sources/raft-blender-v1/glb-validation.json').write_text(json.dumps(report,indent=2))
print('BLENDER GLB: PASS',len(report),'modules',sum(v['triangles'] for v in report.values()),'total asset triangles')
