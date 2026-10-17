"""Register geometry-based close/reset controls without refreshing unrelated art."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main():
    manifest = ROOT / "assets/manifest.json"
    data = json.loads(manifest.read_text(encoding="utf-8"))
    assets = data["assets"]
    assets.setdefault("ui.controls.utility-icons", {
        "path": "res://presentation/utility_button_art.gd", "version": 1,
        "source": "presentation/utility_button_art.gd", "dependencies": [],
        "license": "project-authored geometry; no external icon font or texture",
        "visual_random": "none",
    })
    assets["ui.controls.utility-icons"]["runtime_mapping"] = "CloseX: centered rounded-stroke X in 44px rounded square; ResetRaftView: 56px circle with curved arrow; SettingsResetRaftView: matching arrow and native label"
    paths = {"presentation/widgets.gd", "presentation/settings_panel.gd", "pages/voyage_hud.gd", "presentation/utility_button_art.gd"}
    changed = []
    for asset_id, asset in assets.items():
        path = asset.get("path", "").removeprefix("res://")
        if path not in paths: continue
        current_hash = hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
        if asset.get("sha256") and asset["sha256"] != current_hash:
            asset["version"] = asset.get("version", 1) + 1
        asset["sha256"] = current_hash
        asset["source_hash_verified_on"] = "2026-10-17"
        if asset_id != "ui.controls.utility-icons":
            asset["dependencies"] = list(dict.fromkeys(asset.get("dependencies", []) + ["ui.controls.utility-icons"]))
        changed.append(asset_id)
    assets["ui.controls.close"]["role"] = "shared top-right X overlay with centered geometric cross and rounded-square bezel; 44px touch target; native text retained for accessibility"
    assets["ui.camera.reset-icon"]["role"] = "retained earlier SVG reset icon; current HUD uses ui.controls.utility-icons geometry"
    assets["ui.camera.reset-icon"]["runtime_mapping"] = "retained source reference; not loaded by the current ResetRaftView"
    assets["ui.camera.reset-icon"]["status"] = "retained-not-active"
    manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("UTILITY BUTTON ASSETS: registered " + ", ".join(changed))

if __name__ == "__main__": main()
