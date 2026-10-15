"""Regression checks on exported geometry, independent of Blender/import caches."""
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def inspect(path):
    data = path.read_bytes()
    magic, version, size = struct.unpack_from('<4sII', data)
    assert magic == b'glTF' and version == 2 and size == len(data)
    length = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20 + length])
    binary = data[28 + length:]

    def values(index):
        a = doc['accessors'][index]
        view = doc['bufferViews'][a['bufferView']]
        width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[a['type']]
        fmt = {5126: 'f', 5125: 'I', 5123: 'H', 5121: 'B'}[a['componentType']]
        stride = view.get('byteStride', struct.calcsize(fmt) * width)
        offset = view.get('byteOffset', 0) + a.get('byteOffset', 0)
        return [struct.unpack_from('<' + fmt * width, binary, offset + i * stride)
                for i in range(a['count'])]

    groups = {'wood': [], 'soil': [], 'plant': []}
    triangles = 0
    wood_edges = {}
    assert all(n.get('name') != 'Cube' for n in doc['nodes']), 'Unexpected startup cube'
    for n in doc['nodes']:
        assert not any(k in n for k in ('matrix', 'translation', 'rotation', 'scale')), 'Bake transforms'
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            attrs = p['attributes']
            assert {'POSITION', 'NORMAL', 'TEXCOORD_0'} <= attrs.keys()
            positions = values(attrs['POSITION'])
            assert all(math.isfinite(c) for v in positions for c in v)
            assert all(abs(sum(c*c for c in v)-1) < .01 for v in values(attrs['NORMAL']))
            indices = [x[0] for x in values(p['indices'])]
            for i in range(0, len(indices), 3):
                a,b,c = [positions[k] for k in indices[i:i+3]]
                u = [b[k]-a[k] for k in range(3)]; v = [c[k]-a[k] for k in range(3)]
                cross = [u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                assert sum(x*x for x in cross) > 1e-18, 'Degenerate triangle'
            triangles += len(indices)//3
            name = doc['materials'][p['material']]['name'].lower()
            group = 'soil' if 'soil' in name else 'wood' if 'wood' in name else 'plant' if 'plantgreen' in name else None
            assert group, name
            groups[group].extend(positions)
            if group == 'wood':
                keys = [tuple(round(c,6) for c in v) for v in positions]
                for i in range(0,len(indices),3):
                    a,b,c = [keys[k] for k in indices[i:i+3]]
                    for start,end in [(a,b),(b,c),(c,a)]:
                        wood_edges.setdefault(start,set()).add(end); wood_edges.setdefault(end,set()).add(start)
    bounds = {}
    for name, points in groups.items():
        assert points, name
        bounds[name] = [[min(v[k] for v in points) for k in range(3)],
                        [max(v[k] for v in points) for k in range(3)]]
    wood, soil, plant = [bounds[n] for n in ('wood','soil','plant')]
    assert 1.0 < wood[1][0]-wood[0][0] < 1.3, 'Collapsed planter walls'
    assert .65 < wood[1][2]-wood[0][2] < 1.0, 'Collapsed planter depth'
    assert .17 < wood[0][1] < .20, 'Wrong deck clearance'
    assert soil[0][1] <= plant[0][1] <= soil[1][1], 'Floating stems'
    for axis in (0,2):
        assert wood[0][axis] < soil[0][axis] < soil[1][axis] < wood[1][axis], 'Soil outside box'
        assert soil[0][axis] < (plant[0][axis]+plant[1][axis])/2 < soil[1][axis], 'Plants outside soil'
    assert 500 < triangles < 10000
    remaining = set(wood_edges); plank_tops = []
    while remaining:
        first = min(remaining); remaining.remove(first); todo = [first]; points = [first]
        while todo:
            for key in wood_edges[todo.pop()] & remaining:
                remaining.remove(key); todo.append(key); points.append(key)
        low = min(v[1] for v in points); high = max(v[1] for v in points)
        if high-low > .12: plank_tops.append(high)
    return {'triangles': triangles, 'bounds_y_up': bounds, 'plank_tops_y':sorted(plank_tops),'bytes': len(data)}


if __name__ == '__main__':
    mature = inspect(ROOT/'assets/models/raft-modules/planter.glb')
    seedling_path = ROOT/'assets/models/raft-modules/planter-seedling.glb'
    if seedling_path.exists():
        seedling = inspect(seedling_path)
        assert mature['bounds_y_up']['wood'] == seedling['bounds_y_up']['wood']
        assert mature['bounds_y_up']['soil'] == seedling['bounds_y_up']['soil']
        assert len(mature['plank_tops_y']) == 10
        assert max(mature['plank_tops_y'])-min(mature['plank_tops_y']) > .05, 'Planks need different heights'
        assert mature['bounds_y_up']['plant'][1][1]-seedling['bounds_y_up']['plant'][1][1] > .25
        for path in [ROOT/'assets/models/raft-modules/planter.glb',seedling_path]:
            data = path.read_bytes(); length = struct.unpack_from('<I',data,12)[0]; doc = json.loads(data[20:20+length])
            assert len(doc['meshes'])==4 and len(doc['images'])==6
            assert all('bufferView' in image for image in doc['images']), 'Embed textures'
            for material in doc['materials']:
                if any(k in material['name'] for k in ['Wood','Soil']):
                    assert 'baseColorTexture' in material['pbrMetallicRoughness'] and 'normalTexture' in material
        print('PLANTER TWO STATES + EMBEDDED PBR: PASS',json.dumps({'mature':mature,'seedling':seedling}))
    else:
        print('PLANTER GEOMETRY: PASS',json.dumps(mature))
