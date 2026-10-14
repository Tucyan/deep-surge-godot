"""Derive rectangular sprites from archived imagegen sheet; preserve RGBA pixels."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'asset-sources/story-ui-v1/ui-sheet.png'
OUTPUT = ROOT / 'assets/story_ui'
OUTPUT.mkdir(parents=True, exist_ok=True)
sheet = Image.open(SOURCE).convert('RGBA')
regions = {'dialogue': (0, 0, 2117, 520), 'choice': (0, 520, 1270, 743), 'toolbar': (1270, 520, 2117, 743)}
records = {}
for name, region in regions.items():
    piece = sheet.crop(region)
    bounds = piece.getchannel('A').getbbox()
    if bounds is None:
        raise ValueError(f'Empty sprite {name}')
    piece = piece.crop(bounds)
    target = OUTPUT / f'{name}-v1.png'
    piece.save(target)
    records[f'ui.story.{name}'] = {
        'path': 'res://' + target.relative_to(ROOT).as_posix(), 'version': 1,
        'source': SOURCE.relative_to(ROOT).as_posix(), 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'crop': [region[0]+bounds[0], region[1]+bounds[1], piece.width, piece.height],
        'dimensions': list(piece.size), 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
        'dependencies': [], 'show_label': False, 'license': 'AI-generated using built-in imagegen; style reference user-provided homepage',
    }
records['ui.story.layout'] = {'path': 'res://pages/story_page.gd', 'version': 1,
    'source': 'programmatic layout, font configuration and button states', 'reference_size': [1600, 900],
    'dependencies': list(records) + ['texture.title.ocean-poster'], 'visual_seed': None, 'sha256': hashlib.sha256((ROOT / 'pages/story_page.gd').read_bytes()).hexdigest()}
inventory = {'schema': 1, 'assets': records, 'source_dimensions': list(sheet.size), 'alpha': 'original RGBA preserved; rectangular crop only'}
(SOURCE.parent / 'inventory.json').write_text(json.dumps(inventory, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
manifest_path = ROOT / 'assets/manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['assets'].update(records)
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({key: value.get('dimensions') for key, value in records.items()}, ensure_ascii=False))
