"""Register supplied text-button artwork and only the UI files changed with it."""
import hashlib
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "asset-sources/text-buttons-v1"
ARCHIVE = SOURCE / "deep_surge_resizable_buttons_godot4.zip"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    manifest = ROOT / "assets/manifest.json"
    data = json.loads(manifest.read_text(encoding="utf-8"))
    assets = data["assets"]
    source_files = {}
    with zipfile.ZipFile(ARCHIVE) as archive:
        for name in ["normal", "hover", "pressed", "disabled", "compass"]:
            for extension in ["png", "svg"]:
                entry = f"deep_surge_resizable_buttons/addons/deep_surge_resizable_buttons/{name}.{extension}"
                source_hash = digest(archive.read(entry))
                path = ROOT / f"assets/ui/buttons/{name}.{extension}"
                assert digest(path.read_bytes()) == source_hash, f"Source differs: {path}"
                source_files[entry] = source_hash
                asset_id = f"texture.ui.tarot.{name}" + ("-svg" if extension == "svg" else "")
                asset = assets[asset_id]
                asset.update({
                    "source": ARCHIVE.relative_to(ROOT).as_posix(),
                    "source_entry": entry,
                    "license": "user-supplied; no additional license assertion",
                    "runtime_mapping": "shared native text-button artwork in presentation/text_button_art.gd; scenes/ui/tarot_button.tscn remains reusable" if extension == "png" else "editable source variant; not loaded by shared native text buttons",
                    "source_hash_verified_on": "2026-10-17",
                })
    assets.setdefault("ui.controls.text-buttons", {
        "path": "res://presentation/text_button_art.gd", "version": 1,
        "source": ["presentation/text_button_art.gd", ARCHIVE.relative_to(ROOT).as_posix()],
        "license": "project-authored integration of user-supplied artwork",
        "visual_random": "none",
    })
    button_asset = assets["ui.controls.text-buttons"]
    button_asset["dependencies"] = [f"texture.ui.tarot.{name}" for name in ["normal", "hover", "pressed", "disabled", "compass"]]
    button_asset["runtime_mapping"] = "Widgets.button plus settings tabs/actions, debug buttons and native confirmation dialogs; nine-slice art behind native input/text; compact symbol variant; explicit caller skins take precedence"
    paths = {
        "presentation/text_button_art.gd", "presentation/widgets.gd",
        "presentation/settings_panel.gd", "presentation/title_layout_debug.gd",
        "pages/craft_page.gd", "pages/shop_page.gd", "flow_app.gd",
    }
    updated = []
    for asset_id, asset in assets.items():
        path = asset.get("path", "").removeprefix("res://")
        if path not in paths:
            continue
        current_hash = digest((ROOT / path).read_bytes())
        if asset.get("sha256") and asset["sha256"] != current_hash:
            asset["version"] = asset.get("version", 1) + 1
        asset["sha256"] = current_hash
        asset["source_hash_verified_on"] = "2026-10-17"
        if asset_id != "ui.controls.text-buttons":
            asset["dependencies"] = list(dict.fromkeys(asset.get("dependencies", []) + ["ui.controls.text-buttons"]))
        updated.append(asset_id)
    manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (SOURCE / "inventory.json").write_text(json.dumps({
        "archive_sha256": digest(ARCHIVE.read_bytes()), "source_files": source_files,
        "runtime_images": "all ten existing PNG/SVG files match the supplied archive byte-for-byte",
        "updated_script_assets": updated,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"TEXT BUTTON ASSETS: 10 source images verified; {len(updated)} UI script assets registered")


if __name__ == "__main__":
    main()
