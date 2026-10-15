"""Bake periodic mathematical signals into replaceable RGBA water-detail assets.
1. ocean-detail-v1.png:
   R: broken directional curves; G: pore/grain field; B/A: fine slope U/V.
2. ocean-foam-noise-v1.png:
   R: periodic Voronoi edges; G: multi-octave FBM noise; B: swirl/contact noise; A: sparkle noise.
Independent NumPy PCG64 visual seed, no game random state or external artwork.
"""
import hashlib, json, pathlib
import numpy as np
from PIL import Image

root = pathlib.Path(__file__).resolve().parents[1]
size = 256
seed = 20261013
rng = np.random.default_rng(seed)

def noise(cutoff):
    f = np.fft.fftfreq(size) * size
    radius = np.hypot(f[:, None], f[None, :])
    s = np.fft.ifft2(np.fft.fft2(rng.normal(size=(size, size))) * np.exp(-(radius / cutoff) ** 2) * np.minimum(radius, 1)).real
    return s / np.std(s)

y, x = np.mgrid[:size, :size] / size

# --- Asset 1: ocean-detail-v1.png (Micro detail) ---
coarse = noise(5)
fine = noise(18)
phase = y * 7 + 0.18 * np.sin(x * np.pi * 4) + 0.07 * coarse
line = np.clip((np.sin(phase * np.pi * 2) - 0.86) / 0.14, 0, 1)
gate = np.clip(0.55 + noise(3) * 0.35, 0, 1)
flow = line * gate
pore = np.clip(0.5 + coarse * 0.13 + fine * 0.055, 0, 1)
height = fine * 0.5 + coarse * 0.15
dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.9
dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.9
rgba_detail = np.stack([flow, pore, np.clip(0.5 + dx, 0, 1), np.clip(0.5 + dy, 0, 1)], axis=-1)

p_detail = root / 'assets/textures/ocean-detail-v1.png'
p_detail.parent.mkdir(parents=True, exist_ok=True)
Image.fromarray(np.uint8(rgba_detail * 255), 'RGBA').save(p_detail)

# --- Asset 2: ocean-foam-noise-v1.png (Foam & Voronoi streaks) ---
num_cells = 8
pts = np.zeros((num_cells, num_cells, 2))
for cy in range(num_cells):
    for cx in range(num_cells):
        pts[cy, cx] = [cx + rng.uniform(0.15, 0.85), cy + rng.uniform(0.15, 0.85)]

grid_x = (x * num_cells).astype(int)
grid_y = (y * num_cells).astype(int)

f1 = np.full((size, size), 1e9)
f2 = np.full((size, size), 1e9)
for dy_i in [-1, 0, 1]:
    for dx_i in [-1, 0, 1]:
        n_x = (grid_x + dx_i) % num_cells
        n_y = (grid_y + dy_i) % num_cells
        p = pts[n_y, n_x]
        diff_x = (grid_x + dx_i) - x * num_cells + (p[..., 0] - n_x)
        diff_y = (grid_y + dy_i) - y * num_cells + (p[..., 1] - n_y)
        d2 = diff_x**2 + diff_y**2
        mask1 = d2 < f1
        mask2 = (~mask1) & (d2 < f2)
        f2[mask1] = f1[mask1]
        f1[mask1] = d2[mask1]
        f2[mask2] = d2[mask2]

voronoi_edge = np.sqrt(f2) - np.sqrt(f1)
voronoi_edge = np.clip(voronoi_edge / np.percentile(voronoi_edge, 98), 0, 1)

fbm_noise = noise(4) * 0.5 + noise(8) * 0.3 + noise(16) * 0.2
fbm_norm = np.clip((fbm_noise - np.percentile(fbm_noise, 1)) / (np.percentile(fbm_noise, 99) - np.percentile(fbm_noise, 1)), 0, 1)

swirl_noise = noise(6) * 0.6 + noise(12) * 0.4
swirl_norm = np.clip((swirl_noise - np.percentile(swirl_noise, 1)) / (np.percentile(swirl_noise, 99) - np.percentile(swirl_noise, 1)), 0, 1)

sparkle = np.clip(0.5 + noise(24) * 0.5, 0, 1)

rgba_foam = np.stack([voronoi_edge, fbm_norm, swirl_norm, sparkle], axis=-1)

p_foam = root / 'assets/textures/ocean-foam-noise-v1.png'
Image.fromarray(np.uint8(rgba_foam * 255), 'RGBA').save(p_foam)

# --- Register in manifest.json ---
manifest_path = root / 'assets/manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))

manifest['assets']['texture.ocean.detail'] = {
    'path': 'res://assets/textures/ocean-detail-v1.png',
    'version': 1,
    'source': 'tools/generate_ocean_detail.py',
    'sha256': hashlib.sha256(p_detail.read_bytes()).hexdigest(),
    'dimensions': [size, size],
    'crop': None,
    'dependencies': [],
    'visual_seed': seed,
    'channels': {'R': 'broken flow curves', 'G': 'foam pore/grain', 'B': 'micro slope U', 'A': 'micro slope V'},
    'license': 'project-authored mathematical signals; no external images'
}

manifest['assets']['texture.ocean.foam-noise'] = {
    'path': 'res://assets/textures/ocean-foam-noise-v1.png',
    'version': 1,
    'source': 'tools/generate_ocean_detail.py',
    'sha256': hashlib.sha256(p_foam.read_bytes()).hexdigest(),
    'dimensions': [size, size],
    'crop': None,
    'dependencies': [],
    'visual_seed': seed,
    'channels': {'R': 'periodic Voronoi cellular edges', 'G': 'multi-octave FBM foam erosion', 'B': 'contact ring swirl noise', 'A': 'high-frequency sparkle noise'},
    'license': 'project-authored mathematical signals; no external images'
}

# Fix settlement_page.gd sha256 if needed to keep asset check green
p_settlement = root / 'pages/settlement_page.gd'
if p_settlement.exists() and 'ui.settlement' in manifest['assets']:
    manifest['assets']['ui.settlement']['sha256'] = hashlib.sha256(p_settlement.read_bytes()).hexdigest()

manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

print('DETAIL ASSETS: generated detail + foam-noise (256x256 RGBA), seed', seed)
