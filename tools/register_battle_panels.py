"""Register the four user-supplied battle panels, without altering their pixels."""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = root / "asset-sources/battle-ui-panels-v1"
target = root / "assets/battle_ui/panels_v1"
target.mkdir(parents=True, exist_ok=True)
manifest = root / "assets/manifest.json"
data = json.loads(manifest.read_text(encoding="utf-8"))
ids = []
for role, filename in [("monster", "01_left_circle_panel.png"),
                       ("intent", "02_top_center_panel.png"),
                       ("preview", "03_bottom_center_panel.png"),
                       ("log", "04_right_side_panel.png")]:
    path = target / filename
    shutil.copyfile(source / filename, path)
    asset_id = f"texture.battle.panel.{role}"
    ids.append(asset_id)
    data["assets"][asset_id] = {
        "path": "res://" + path.relative_to(root).as_posix(),
        "source": (source / filename).relative_to(root).as_posix(),
        "source_archive": "deep_surge_ui_panels (1).zip",
        "version": 1,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "dimensions": list(Image.open(path).size),
        "dependencies": [],
        "license": "user-supplied artwork; original pixels preserved",
        "runtime_mapping": f"BattleHUDView {role}; proportional fit; decoration ignores mouse",
    }
path = root / "pages/battle_hud_view.gd"
data["assets"]["ui.battle.panels"] = {
    "path": "res://pages/battle_hud_view.gd",
    "source": "project-authored supplied-panel adapter",
    "version": 1,
    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    "dependencies": ids,
    "runtime_mapping": "monster / intent / preview / combat log; original battle actions and hand retained",
}
manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("Registered four battle panel textures and UI adapter")
