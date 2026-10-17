"""Verify each live GLB carries the authentic raft wood texture unchanged."""
import io, json, struct, hashlib
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'asset-sources/raft-wood-unified-v1'
records = json.loads((OUT / 'application-report.json').read_text())
manifest = json.loads((ROOT / 'assets/manifest.json').read_text(encoding='utf-8'))['assets']

expected_texture = Image.open(ROOT / 'assets/textures/raft-wood/weathered_wood_albedo.png').convert('RGBA')
expected_sha = hashlib.sha256((ROOT / 'assets/textures/raft-wood/weathered_wood_albedo.png').read_bytes()).hexdigest()

raft_texture_sha = hashlib.sha256((ROOT / 'assets/models/raft_weathered_wood_albedo.png').read_bytes()).hexdigest()
assert expected_sha == raft_texture_sha, "Shared wood texture must be byte-identical to raft wood texture"

mapping = {
    'wooden-crate': 'crate',
    'planter': 'planter',
    'planter-seedling': 'planter',
    'shieldRack': 'shieldRack',
    'generator': 'generator',
    'fishingNet': 'fishingNet'
}

for stem, category in mapping.items():
    path = ROOT / 'assets/models/props/wooden-crate.glb' if stem == 'wooden-crate' else ROOT / 'assets/models/raft-modules' / f'{stem}.glb'
    data = path.read_bytes()
    length = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20+length])
    binary = data[28+length:]
    
    wood_count = 0
    for mat in doc['materials']:
        if 'Wood' not in mat['name']:
            continue
        wood_count += 1
        pbr = mat['pbrMetallicRoughness']
        assert abs(pbr['roughnessFactor'] - 0.80) < 0.005, (stem, mat['name'], pbr['roughnessFactor'])
        factor = pbr.get('baseColorFactor', [1, 1, 1, 1])
        assert all(abs(x - 1) < 0.001 for x in factor), (stem, mat['name'], factor)
        texture_index = pbr['baseColorTexture']['index']
        image = doc['images'][doc['textures'][texture_index]['source']]
        assert image['name'] == 'weathered_wood_albedo'
        view = doc['bufferViews'][image['bufferView']]
        embedded = Image.open(io.BytesIO(binary[view.get('byteOffset', 0):view.get('byteOffset', 0)+view['byteLength']])).convert('RGBA')
        assert embedded.size == expected_texture.size and embedded.tobytes() == expected_texture.tobytes(), (stem, mat['name'], 'Embedded wood differs from raft texture')
    
    assert wood_count > 0, (stem, "No wood materials found")
    report_key = stem + '.glb'
    assert report_key in records and records[report_key]['uv_unchanged']
    assert records[report_key]['geometry_unchanged'] is (stem != 'fishingNet')
    
    # Check extracted file by Godot
    extracted_path = path.parent / (path.stem + '_weathered_wood_albedo.png')
    assert extracted_path.exists(), f"Godot extracted file missing: {extracted_path}"
    assert hashlib.sha256(extracted_path.read_bytes()).hexdigest() == expected_sha, f"Extracted file differs: {extracted_path}"

print('UNIFIED RAFT WOOD PIXELS + MATERIAL ROUGHNESS 0.80 + GEOMETRY/UV INTEGRITY + GODOT EXTRACTION: PASS')
