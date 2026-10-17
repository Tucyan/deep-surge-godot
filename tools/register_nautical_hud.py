"""Register the 2026-10-17 nautical UI without rewriting unrelated asset hashes."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'assets/manifest.json'
data = json.loads(MANIFEST.read_text(encoding='utf-8'))
assets = data['assets']
source = ROOT / 'asset-sources/nautical-hud-v1'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

for name in ['compass', 'health', 'hunger', 'water', 'sanity']:
    path = ROOT / f'assets/ui/nautical/{name}.png'
    assets[f'texture.hud.nautical.{name}'] = {
        'path': 'res://' + path.relative_to(ROOT).as_posix(),
        'version': 1, 'sha256': digest(path), 'dimensions': list(Image.open(path).size),
        'source': 'asset-sources/nautical-hud-v1/icons-original.zip',
        'dependencies': [], 'license': 'user-supplied; no additional license assertion',
        'runtime_mapping': 'VoyageCompass' if name == 'compass' else f'SurgeStatusHUD/{name}',
        'processing': 'unchanged RGBA source; aspect-preserving rendering; mipmapped UI import',
    }

ap_art = ROOT / 'assets/ui/nautical/action-points.png'
assets['texture.hud.nautical.action-points'] = {
    'path': 'res://assets/ui/nautical/action-points.png', 'version': 1,
    'sha256': digest(ap_art), 'dimensions': list(Image.open(ap_art).size),
    'region': [130, 139, 1814, 454],
    'source': 'asset-sources/nautical-hud-v1/action-points-original.png',
    'dependencies': [], 'license': 'user-supplied; no additional license assertion',
    'runtime_mapping': 'SurgeActionPointHUD; aspect-preserving frame, live tokens and numbers; empty navy sample under dynamic label',
}

for asset_id, path, role in [
    ('ui.hand.stack-backplate', 'presentation/card_stack.gd', 'two independent left-exposed rear cards with 25 percent soft seam shadows; only front hovers'),
    ('ui.hud.nautical-frame', 'presentation/nautical_frame.gd', 'responsive navy/gold header and parchment body with fixed corner ornaments'),
    ('ui.hud.nautical-button-art', 'presentation/nautical_button_art.gd', 'independent long salvage and circular craft art; native Button text and input'),
    ('ui.hud.nautical-menu-icons', 'presentation/nautical_menu_icon.gd', 'procedural help, settings and home icons; accessible native button labels'),
]:
    assets[asset_id] = {
        'path': 'res://' + path, 'source': 'project-authored from user-supplied references in asset-sources/nautical-hud-v1',
        'version': 2 if asset_id == 'ui.hud.nautical-frame' else 1, 'sha256': digest(ROOT / path), 'role': role,
        'dependencies': ['ui.card.front'] if asset_id == 'ui.hand.stack-backplate' else (['ui.hud.nautical-frame'] if 'button-art' in asset_id else []),
        'license': 'project-authored procedural rendering based on user-supplied style reference',
        'visual_random': 'none', 'source_hash_verified_on': '2026-10-17',
    }

changed_paths = {
    'presentation/hand_layout.gd': 5,
    'presentation/settings_panel.gd': 7,
    'presentation/item_card.gd': 7,
    'presentation/hud/action_points_hud.gd': 3,
    'presentation/hud/status_hud.gd': 8,
    'pages/voyage_hud.gd': 21,
    'presentation/hand_fan.gd': 22,
    'presentation/hand_border.gd': 2,
}
for asset_id, entry in assets.items():
    path = entry.get('path', '').removeprefix('res://')
    if path not in changed_paths:
        continue
    entry['sha256'] = digest(ROOT / path)
    entry['version'] = max(entry.get('version', 1), changed_paths[path])
    entry['source_hash_verified_on'] = '2026-10-17'
    if path == 'presentation/hud/action_points_hud.gd':
        entry['dependencies'] = ['texture.hud.nautical.action-points', 'texture.hud.ap-orb-full', 'texture.hud.ap-orb-empty']
        entry['source'] = ['asset-sources/nautical-hud-v1/action-points-original.png', path]
        entry['runtime_mapping'] = '360x90 fixed-aspect widget flush with far left of fixed-height hand header; real AP/night budget'
    if path == 'presentation/hud/status_hud.gd':
        entry['dependencies'] = [f'texture.hud.nautical.{n}' for n in ['health', 'hunger', 'water', 'sanity']]
        entry['source'] = ['asset-sources/nautical-hud-v1/icons-original.zip', path]
        entry['runtime_mapping'] = 'single row health/satiety/water/sanity; fixed 72-unit tracks; hide all tracks when space is insufficient and retain icon/current/max'
    if asset_id == 'ui.item-card':
        entry['dependencies'] = ['ui.card.front', 'card.*']
        entry['role'] = 'clean card face: bottom contact shadow; outlined light quantity text without backing; raised name; native Button retains action/input'
        entry['visible_face_horizontal_bounds_px'] = [80, 945]
        entry['visible_face_source_width_px'] = 1024
    if asset_id == 'ui.hand.border':
        entry['dependencies'] = ['ui.hud.nautical-frame']
        entry['role'] = '70-percent-opacity parchment fill below all hand cards; trim and cards retain full opacity'
    if asset_id == 'ui.hand.layout':
        entry['runtime_mapping'] = 'local hand-layout.cfg: auto_sort, stack_resources, order and validated hover_mode spread/raise; legacy defaults spread; no GameState changes'
    if asset_id == 'ui.settings-panel':
        entry['runtime_mapping'] = 'game preferences HandHoverMode: spread occluders or raise front layer; save local hand preferences; compact short-screen settings'
    if asset_id == 'ui.hand.stack-quantity':
        entry['role'] = 'right-side StackQuantity Label; weight-800 light glyphs, font size 23, dark outline size 6; no backing'
    if asset_id == 'ui.hand.fan':
        entry['runtime_mapping'] = 'card height 97 percent of body excluding fixed-height header; hover and selected raise preserve sibling draw order; hover clearance uses visible frame width excluding transparent margins and shadow, threshold 5 percent; no battle-selection requirement or experimental rear layers'
        entry['dependencies'] = list(dict.fromkeys([d for d in entry.get('dependencies', []) if d != 'shader.ui.hand-glass'] + ['ui.hand.stack-backplate','ui.hand.layout']))
    if asset_id == 'ui.hud.voyage-adapter':
        entry['dependencies'] = list(dict.fromkeys(entry.get('dependencies', []) + ['ui.hud.nautical-frame', 'ui.hud.nautical-button-art', 'ui.hud.nautical-menu-icons', 'texture.hud.nautical.compass']))
        entry['runtime_mapping'] = 'unified navigation header; environment strip below heading; parchment hand tray; adaptive operation panel; independent long/round native buttons'
    if asset_id in ['ui.craft.circle-entry', 'ui.battle.salvage']:
        entry['dependencies'] = list(dict.fromkeys(entry.get('dependencies', []) + ['ui.hud.nautical-button-art']))

MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
inventory = {
    'source_files': {p.name: digest(p) for p in source.iterdir() if p.suffix in ['.png', '.zip']},
    'notes': 'All five icons and the AP artwork are unmodified. AP uses an AtlasTexture crop. Reference sheets are source-only and excluded by .gdignore. Button shapes are recreated separately with native geometry; reference sheets are not runtime backgrounds. No game RNG or rule changes.',
}
(source / 'inventory.json').write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('NAUTICAL HUD ASSETS: registered 5 supplied icons, AP artwork, 4 procedural components and affected UI hashes')
