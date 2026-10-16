"""Register the supplied lighthouse, transparent logo and continuous-rail frame."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'assets/manifest.json'
data = json.loads(MANIFEST.read_text(encoding='utf-8'))
assets = data['assets']
VIDEO_SOURCE = 'user-supplied/月下灯塔与星海航行_无水印_2x超分辨率.mp4'
FRAME_SOURCE = 'user-supplied/深潮_矩形框_无缝修复版.zip'


def register(asset_id, relative, source, **extra):
    file = ROOT / relative
    entry = dict(path='res://' + relative, source=source, version=3,
                 sha256=hashlib.sha256(file.read_bytes()).hexdigest(),
                 dependencies=[], license='user supplied; no additional license assertion')
    if file.suffix == '.png':
        entry['dimensions'] = list(Image.open(file).size)
    entry.update(extra)
    assets[asset_id] = entry


register('video.title.ocean', 'assets/title_ui/lighthouse_loop.ogv', VIDEO_SOURCE,
         encoding='FFmpeg 7.1 libtheora q7, 2240x960, yuv420p, silent, native Godot loop; preserves source 21:9')
register('texture.title.ocean-poster', 'assets/title_ui/lighthouse_poster.png', VIDEO_SOURCE + '#first-frame')
register('texture.title.logo-v3', 'assets/title_ui/deep_surge_logo_v3.png',
         'user-supplied/codex-clipboard-1a3fb0cf-cad3-4cca-9f6f-47f243db5f95.png')
register('reference.title.home-v3', 'assets/title_ui/home_reference_v3.png',
         'user-supplied/codex-clipboard-9025ac56-b4bf-4858-946f-0ba88d58115d.png', runtime=False)
frame_ids = []
for file in sorted((ROOT / 'assets/title_ui/frame_v3').glob('*.png')):
    asset_id = 'texture.title.frame-v3.' + file.stem.replace('_', '-')
    frame_ids.append(asset_id)
    register(asset_id, file.relative_to(ROOT).as_posix(), FRAME_SOURCE + '/' + file.name)
register('ui.title.frame-v3', 'presentation/title_frame.gd', 'project-authored',
         dependencies=frame_ids, visual_random='none',
         runtime_mapping='Four continuous rails below 16 uniformly scaled motifs; quarter points at 25%/75%')
entry = assets['ui.title.menu']
register('ui.title.logo-backdrop', 'presentation/title_logo_backdrop.gd', 'project-authored',
         runtime_mapping='Circular black 70% opacity; child behind TitleLogo; inherits movement, scale and visibility',
         visual_random='none')
entry.update(version=7, sha256=hashlib.sha256((ROOT / 'presentation/title_menu.gd').read_bytes()).hexdigest())
entry['dependencies'] = [dep for dep in entry['dependencies'] if dep != 'shader.title.board']
for dep in ['ui.title.frame-v3', 'texture.title.logo-v3', 'texture.title.ocean-poster', 'ui.title.logo-backdrop']:
    if dep not in entry['dependencies']:
        entry['dependencies'].append(dep)
entry['layout'] = dict(reference_size=[1672, 941], logo=[140, 80, 650, 487.5],
                       buttons='Right anchored; original aspect and UI scale retained', landscape_aspects=['3:2', '21:9'])
entry['shade'] = dict(opacity=0, layer_order=['poster', 'video', 'logo/buttons', 'continuous-frame'])
for entry in assets.values():
    if entry.get('path') in ['res://presentation/display_settings.gd', 'res://presentation/settings_panel.gd']:
        entry['sha256'] = hashlib.sha256((ROOT / entry['path'][6:]).read_bytes()).hexdigest()
MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('TITLE V3 REGISTERED:', len(frame_ids), 'frame textures')
