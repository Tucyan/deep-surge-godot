from pathlib import Path
import hashlib, json
from PIL import Image

root = Path(__file__).resolve().parents[1]
path = root / 'assets/manifest.json'
manifest = json.loads(path.read_text(encoding='utf-8'))
assets = manifest['assets']
source = 'user-supplied/media_1792149500191_7ef06e72.zip'
video_source = 'asset-sources/title-ui-v2/海浪和远方的云动态流动_无水印_2x超分辨率.mp4'
ids = []
for file in sorted((root / 'assets/title_ui').glob('*.png')):
    asset_id = 'texture.title.' + file.stem.replace('_', '-')
    ids.append(asset_id)
    assets[asset_id] = {'path': 'res://' + file.relative_to(root).as_posix(), 'source': source if file.name != 'ocean_poster.png' else 'user-supplied/media_1792149500191_7ef06e72.zip/封面ui/ChatGPT 图像 2026年10月15日 21_52_02-1.png', 'version': 5, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(), 'dimensions': list(Image.open(file).size), 'dependencies': [], 'license': 'user supplied title artwork'}
file = root / 'assets/title_ui/ocean_loop.ogv'
assets['video.title.ocean'] = {'path': 'res://assets/title_ui/ocean_loop.ogv', 'version': 1, 'source': video_source, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(), 'dependencies': [], 'license': 'user supplied video', 'encoding': 'FFmpeg 7.1 libtheora quality 7, 1704x960, yuv420p, silent; native Godot Theora loop'}
for asset_id, file, deps in [('ui.title.menu', 'presentation/title_menu.gd', ids + ['video.title.ocean']), ('ui.title.home', 'pages/flow_home.gd', ['ui.title.menu'])]:
    assets[asset_id] = {'path': 'res://' + file, 'source': file, 'version': 4, 'sha256': hashlib.sha256((root / file).read_bytes()).hexdigest(), 'dependencies': deps, 'license': 'project authored layout and existing-command routing; supplied title art', 'visual_random': 'none'}
shader = root / 'assets/shaders/title_board.gdshader'
assets['shader.title.board'] = {'path': 'res://assets/shaders/title_board.gdshader', 'source': 'assets/shaders/title_board.gdshader', 'version': 1, 'sha256': hashlib.sha256(shader.read_bytes()).hexdigest(), 'dependencies': ['texture.title.menu-board-source']}
assets['ui.title.menu']['dependencies'].append('shader.title.board')
edge = root / 'assets/shaders/title_button_edge.gdshader'
assets['shader.title.button-edge'] = {'path': 'res://assets/shaders/title_button_edge.gdshader', 'source': 'assets/shaders/title_button_edge.gdshader', 'version': 1, 'sha256': hashlib.sha256(edge.read_bytes()).hexdigest(), 'dependencies': [], 'trim_texels': 2.5}
assets['ui.title.menu']['dependencies'].append('shader.title.button-edge')
assets['ui.title.menu']['version'] = 4
debug_script = root / 'presentation/title_layout_debug.gd'
assets['ui.title.layout-debug'] = {'path': 'res://presentation/title_layout_debug.gd', 'source': 'presentation/title_layout_debug.gd', 'version': 1, 'sha256': hashlib.sha256(debug_script.read_bytes()).hexdigest(), 'dependencies': [], 'license': 'project-authored debug-only layout tool'}
assets['ui.title.menu']['layout'] = {'reference_size': [1672,941], 'buttons': {
 'start': [1125.0, 161.5, 435.0, 145.0],
 'continue': [1141.0, 281.0, 405.0, 135.0],
 'journal': [1141.0, 374.0, 405.0, 135.0],
 'shop': [1141.0, 467.0, 405.0, 135.0],
 'recall': [1141.0, 560.0, 405.0, 135.0],
 'quit': [1141.0, 653.0, 405.0, 135.0]}, 'logo': [100.0, 80.0, 600.0, 300.0]}
assets['ui.title.menu']['shade'] = {'texture': 'texture.title.menu-board-source', 'opacity': 0.0, 'reference_size': [1672,941], 'layer_order': ['poster','video','buttons']}
path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
folder = root / 'asset-sources/title-ui-v2'
inventory = {'files': {p.relative_to(folder).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob('*') if p.is_file() and p.name != 'inventory.json'}, 'runtime_assets': ids + ['video.title.ocean','ui.title.menu','ui.title.home'], 'notes': '2x video selected for runtime; 4x source archived; originals retained unchanged'}
(folder / 'inventory.json').write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('TITLE ASSETS REGISTERED', len(ids) + 3)
