from pathlib import Path
import hashlib, json
from PIL import Image

root = Path(__file__).resolve().parents[1]
path = root / 'assets/manifest.json'
manifest = json.loads(path.read_text(encoding='utf-8'))
assets = manifest['assets']
source = 'asset-sources/title-ui-v2/deep_surge_title_ui_13_assets.zip'
video_source = 'asset-sources/title-ui-v2/海浪和远方的云动态流动_无水印_2x超分辨率.mp4'
ids = []
for file in sorted((root / 'assets/title_ui').glob('*.png')):
    asset_id = 'texture.title.' + file.stem.replace('_', '-')
    ids.append(asset_id)
    assets[asset_id] = {'path': 'res://' + file.relative_to(root).as_posix(), 'source': video_source if file.name == 'ocean_poster.png' else ('asset-sources/title-ui-v2/menu_board_source.png' if file.name == 'menu_board_source.png' else source), 'version': 1, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(), 'dimensions': list(Image.open(file).size), 'dependencies': [], 'license': 'user supplied title artwork/video'}
for name in ['01_start_game','02_continue','03_journal','04_shop','06_exit']:
    record = assets['texture.title.' + (name + '_light').replace('_','-')]
    record['source'] = 'asset-sources/title-buttons-light-v3/original.zip'
    record['version'] = 3
assets['texture.title.05-rewind-light-v4']['source'] = 'asset-sources/title-rewind-v4/05_rewind_light_v4.png'
assets['texture.title.05-rewind-light-v4']['version'] = 4
assets['texture.title.05-rewind-light-v4']['license'] = 'AI-generated from user supplied rewind button; imagegen'
file = root / 'assets/title_ui/ocean_loop.ogv'
assets['video.title.ocean'] = {'path': 'res://assets/title_ui/ocean_loop.ogv', 'version': 1, 'source': video_source, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(), 'dependencies': [], 'license': 'user supplied video', 'encoding': 'FFmpeg 7.1 libtheora quality 7, 1704x960, yuv420p, silent; native Godot Theora loop'}
for asset_id, file, deps in [('ui.title.menu', 'presentation/title_menu.gd', ids + ['video.title.ocean']), ('ui.title.home', 'pages/flow_home.gd', ['ui.title.menu'])]:
    assets[asset_id] = {'path': 'res://' + file, 'source': file, 'version': 1, 'sha256': hashlib.sha256((root / file).read_bytes()).hexdigest(), 'dependencies': deps, 'license': 'project authored layout and existing-command routing; supplied title art', 'visual_random': 'none'}
shader = root / 'assets/shaders/title_board.gdshader'
assets['shader.title.board'] = {'path': 'res://assets/shaders/title_board.gdshader', 'source': 'assets/shaders/title_board.gdshader', 'version': 1, 'sha256': hashlib.sha256(shader.read_bytes()).hexdigest(), 'dependencies': ['texture.title.menu-board-source']}
assets['ui.title.menu']['dependencies'].append('shader.title.board')
edge = root / 'assets/shaders/title_button_edge.gdshader'
assets['shader.title.button-edge'] = {'path': 'res://assets/shaders/title_button_edge.gdshader', 'source': 'assets/shaders/title_button_edge.gdshader', 'version': 1, 'sha256': hashlib.sha256(edge.read_bytes()).hexdigest(), 'dependencies': [], 'trim_texels': 2.5}
assets['ui.title.menu']['dependencies'].append('shader.title.button-edge')
assets['ui.title.menu']['version'] = 3
debug_script = root / 'presentation/title_layout_debug.gd'
assets['ui.title.layout-debug'] = {'path': 'res://presentation/title_layout_debug.gd', 'source': 'presentation/title_layout_debug.gd', 'version': 1, 'sha256': hashlib.sha256(debug_script.read_bytes()).hexdigest(), 'dependencies': [], 'license': 'project-authored debug-only layout tool'}
assets['ui.title.menu']['layout'] = {'reference_size': [1672,941], 'buttons': {
 'start': [1050.0,280.0,450.0,151.363647460938],
 'continue': [1040.0,378.0,450.0,151.363647460938],
 'journal': [1038.0,476.0,450.0,151.363647460938],
 'shop': [1066.09997558594,580.0,450.0,151.363647460938],
 'recall': [1100.30004882813,678.0,450.0,151.363647460938],
 'quit': [1160.0,770.0,450.0,151.363647460938]}, 'logo': [850.0,-85.0,750.0,474.811828613281]}
assets['ui.title.menu']['shade'] = {'texture': 'texture.title.menu-board-source', 'opacity': 0.78, 'mask': 'retain supplied grey region only', 'reference_size': [1672,941], 'layer_order': ['poster','video','shade','logo','buttons']}
path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
folder = root / 'asset-sources/title-ui-v2'
inventory = {'files': {p.relative_to(folder).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob('*') if p.is_file() and p.name != 'inventory.json'}, 'runtime_assets': ids + ['video.title.ocean','ui.title.menu','ui.title.home'], 'notes': '2x video selected for runtime; 4x source archived; originals retained unchanged'}
(folder / 'inventory.json').write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('TITLE ASSETS REGISTERED', len(ids) + 3)
