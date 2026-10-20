"""Build deterministic runtime art from the twenty supplied transparent PNGs.

Originals are preserved. This only scales pixels; it never invents new artwork.
Run from any directory: python tools/import_relic_art.py
"""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IDS = ["sealedFishTin", "emberFuse", "kelpRation", "copperStill", "tideTablet",
       "homeCompass", "hunterSpear", "rescueBadge", "tideBoneBlade", "glowConch",
       "crackedCarapace", "sunkenCoin", "drifterMedkit", "barbedBundle", "redCoral",
       "drifterQuiver", "crimsonVial", "scavengerSatchel", "foldingRule", "sailorsKnot"]
ORIGINAL_NAMES = ["21_33_38-1", "21_33_40-2", "21_33_42-3", "21_33_43-4", "21_33_45-1",
                  "21_33_45-5", "21_33_47-2", "21_33_47-6", "21_33_48-3", "21_33_48-7",
                  "21_33_50-4", "21_33_50-8", "21_33_52-5", "21_33_52-9", "21_33_53-6",
                  "21_33_54-10", "21_33_55-7", "21_33_57-8", "21_33_59-9", "21_34_00-10"]

def main():
    manifest_path = ROOT / "assets/manifest.json"
    manifest_newline = "\r\n" if b"\r\n" in manifest_path.read_bytes() else "\n"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    relics = json.loads((ROOT / "content/data/relics.json").read_text(encoding="utf-8"))
    records = []
    runtime = ROOT / "assets/collectibles"
    runtime.mkdir(parents=True, exist_ok=True)
    # Old relic art belongs to the archived design, not the active catalog.
    for key in list(manifest["assets"]):
        if key.startswith("relic."):
            del manifest["assets"][key]
    for index, identity in enumerate(IDS, 1):
        source = ROOT / f"asset-sources/relics-v1/original/{index:02d}.png"
        original = Image.open(source)
        assert original.size == (1254, 1254) and original.mode == "RGBA"
        dest = runtime / (identity + "-v1.png")
        original.resize((512, 512), Image.Resampling.LANCZOS).save(dest, optimize=True)
        entry = {
            "path": "res://" + dest.relative_to(ROOT).as_posix(),
            "source": source.relative_to(ROOT).as_posix(),
            "source_entry": f"藏品/ChatGPT 图像 2026年10月19日 {ORIGINAL_NAMES[index-1]}.png",
            "version": 1, "dependencies": [], "dimensions": [512, 512],
            "source_dimensions": [1254, 1254],
            "sha256": hashlib.sha256(dest.read_bytes()).hexdigest(),
            "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "license": "User-supplied project artwork; external redistribution rights unspecified",
            "source_hash_verified_on": "2026-10-20", "alpha": "RGBA; transparent background preserved",
            "label": relics[identity]["name"], "show_label": False,
            "runtime_mapping": f"relic.{identity}: acquisition receipt, warehouse, encyclopedia, node art",
            "derivation": "Pillow LANCZOS 1254x1254 to 512x512; no cropping or recoloring"
        }
        manifest["assets"]["relic." + identity] = entry
        records.append({"id": identity, **entry})
    manifest["assets"]["ui.collectible.placeholder"]["dependencies"] = ["texture.collectible.placeholder"] + ["relic." + i for i in IDS]
    manifest["assets"]["ui.collectible.placeholder"]["runtime_mapping"] = "collectible_art.gd resolves relic.<id> through shared cache; unknown ID uses transparent placeholder"
    manifest["assets"]["ui.collectibles.warehouse"]["runtime_mapping"] = "Scrollable grid of actual instances; 5 desktop / 3 mobile columns; per-ID art; UID discard command"
    manifest["assets"]["texture.collectible.placeholder"]["runtime_mapping"] = "Fallback only for unregistered relic artwork"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline=manifest_newline)
    (ROOT / "asset-sources/relics-v1/manifest.json").write_text(json.dumps({
        "source_archive": "藏品.zip", "version": 1, "entries": records
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("RELIC ART: 20 originals preserved, 20 runtime images registered")

if __name__ == "__main__":
    main()
