"""Build platform icon sizes from the approved candidate-04 ImageGen artwork."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'asset-sources/app-icon-sail-v1/source.png'
art = Image.open(ROOT / SOURCE).convert('RGBA')
output = ROOT / 'assets/icons'
output.mkdir(parents=True, exist_ok=True)
main = art.resize((1024, 1024), Image.Resampling.LANCZOS)
main.save(output / 'app-sail-v1.png')
main.save(output / 'app-sail-v1.ico', sizes=[(s, s) for s in [16, 24, 32, 48, 64, 128, 256]])
# Android's 108dp adaptive layer has a 72dp visible viewport. Keep the full
# square composition inside that viewport; launchers apply their own mask.
background = Image.new('RGBA', (432, 432), art.getpixel((0, 0)))
foreground = background.copy()
foreground.alpha_composite(art.resize((288, 288), Image.Resampling.LANCZOS), (72, 72))
foreground.save(output / 'app-sail-adaptive-v1.png')
background.save(output / 'app-sail-background-v1.png')
# Android themed icons use alpha only. Separate the bright sail/waves from
# the dark navy background, then apply the same adaptive safe-area padding.
value = art.convert('HSV').getchannel('V')
mask = value.point(lambda v: max(0, min(255, (v - 85) * 255 // 30)))
symbol = Image.new('RGBA', art.size, 'white')
symbol.putalpha(mask)
monochrome = Image.new('RGBA', (432, 432), (255, 255, 255, 0))
monochrome.alpha_composite(symbol.resize((288, 288), Image.Resampling.LANCZOS), (72, 72))
monochrome.save(output / 'app-sail-monochrome-v1.png')
path = ROOT / 'assets/manifest.json'
manifest = json.loads(path.read_text(encoding='utf-8'))
for asset_id, filename, mapping in [
    ('app.icon', 'app-sail-v1.png', 'project application/config/icon; Android legacy launcher icon'),
    ('app.icon.windows', 'app-sail-v1.ico', 'Windows Desktop application/icon; seven ICO sizes'),
    ('app.icon.android.foreground', 'app-sail-adaptive-v1.png', 'Android adaptive foreground; artwork 288px centered in 432px layer'),
    ('app.icon.android.background', 'app-sail-background-v1.png', 'Android adaptive background; source corner navy color'),
    ('app.icon.android.monochrome', 'app-sail-monochrome-v1.png', 'Android themed icon; sail/wave alpha mask, same adaptive padding'),
]:
    file = output / filename
    entry = {'path': 'res://assets/icons/' + filename, 'source': [SOURCE, 'asset-sources/app-icon-sail-v1/README.md'],
             'version': 1, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(),
             'dependencies': [] if asset_id == 'app.icon' else ['app.icon'],
             'license': 'project ImageGen artwork; user-approved candidate 04',
             'generator': 'tools/register_app_icon.py', 'mapping': mapping, 'visual_random': 'none'}
    if file.suffix == '.png': entry['dimensions'] = list(Image.open(file).size)
    manifest['assets'][asset_id] = entry
path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('APP ICON: generated PNG, ICO and Android adaptive layers; registered five assets')
