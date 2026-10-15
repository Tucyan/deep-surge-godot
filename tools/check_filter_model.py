"""Check exported geometry and receiving-bucket clearance independent of import cache."""
import json
import math
import struct
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def inspect(filename):
    path=ROOT/'assets/models/raft-modules'/filename
    data=path.read_bytes(); magic,version,size=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and size==len(data)
    length=struct.unpack_from('<I',data,12)[0]; doc=json.loads(data[20:20+length]); binary=data[28+length:]
    def values(index):
        a=doc['accessors'][index]; view=doc['bufferViews'][a['bufferView']]
        width={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']]; fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
        offset=view.get('byteOffset',0)+a.get('byteOffset',0); stride=view.get('byteStride',struct.calcsize(fmt)*width)
        return [struct.unpack_from('<'+fmt*width,binary,offset+i*stride) for i in range(a['count'])]
    body=[]; bucket=[]; water=[]; floor=[]; edges=Counter(); triangles=0
    for node in doc['nodes']:
        assert node['name']!='Cube'
        assert not any(k in node for k in ['matrix','translation','rotation','scale'])
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            attrs=primitive['attributes']; assert {'POSITION','NORMAL','TEXCOORD_0'}<=attrs.keys()
            pos=values(attrs['POSITION']); normals=values(attrs['NORMAL'])
            assert all(math.isfinite(c) for v in pos for c in v)
            assert all(abs(sum(c*c for c in v)-1)<.01 for v in normals)
            is_water='WaterSurface' in node['name']; is_bucket='OpenBucket' in node['name']
            material=doc['materials'][primitive['material']]['name']
            (water if is_water else body).extend(pos)
            if is_bucket: bucket.extend(pos)
            if 'WarmWeatheredWood' in material: floor.extend(pos)
            indices=[v[0] for v in values(primitive['indices'])]; triangles+=len(indices)//3
            for i in range(0,len(indices),3):
                a,b,c=[pos[k] for k in indices[i:i+3]]
                u=[b[k]-a[k] for k in range(3)];v=[c[k]-a[k] for k in range(3)]
                cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                assert sum(x*x for x in cross)>1e-18,'Degenerate face'
                if is_bucket:
                    keys=[tuple(round(c,6) for c in p) for p in [a,b,c]]
                    for j in range(3):edges[tuple(sorted([keys[j],keys[(j+1)%3]]))]+=1
                    if all(abs(p[1]-.59)<1e-5 for p in [a,b,c]):
                        center=[sum(p[k] for p in [a,b,c])/3 for k in range(3)]
                        assert math.hypot(center[0]-.31,center[2]-.17)>.22,'Bucket opening capped'
    assert floor and bucket
    assert min(v[1] for v in bucket)-max(v[1] for v in floor)>.009,'Bucket/stand z-fighting'
    assert all(n==2 for n in edges.values()),'Bucket shell must be closed/manifold'
    assert 500<triangles<10000 and size<2*1024*1024
    return {'body':sorted(body),'water':water,'triangles':triangles,'bytes':size,'bucket_edges':len(edges)}

if __name__=='__main__':
    waiting=inspect('filter-waiting.glb'); ready=inspect('filter.glb')
    assert waiting['body']==ready['body'],'Frame/bucket geometry changed between stages'
    assert not waiting['water'] and ready['water']
    assert all(abs(v[1]-.552)<1e-5 for v in ready['water'])
    report={stage:{k:v for k,v in result.items() if k not in ['body','water']} for stage,result in [('waiting',waiting),('ready',ready)]}
    print('FILTER GEOMETRY + EMPTY/FULL + BUCKET CLEARANCE: PASS',json.dumps(report))
