"""Register the sea ambience loop, its configuration and the director.

The loop is assembled from CC0 recordings published on OpenGameArt; the source
bytes and the licence live in asset-sources/ocean-waves-20261020/README.md.
Existing entries are bumped in place instead of being duplicated, so one file
keeps one AssetId. Re-run after changing the loop, the config or the director.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERIFIED = "2026-10-20"
SOURCE = "project-authored/ocean-waves-20261020 (CC0 OpenGameArt sources)"

TRACKS = [
    {
        "id": "audio.ambience.waves-loop",
        "file": "assets/audio/ambience/waves-loop-v1.ogg",
        "origin": "OpenGameArt CC0 packs by jasinski (alkaibeach) and transitking (wavesound)",
        "role": "Continuous sea ambience; one seamless 48 s loop under every music cue",
        "mapping": {
            "loop": True,
            "player": "ambience_director.gd/AmbienceTrack",
            "trim_db": -16.0,
            "config": "res://assets/audio/ambience.json",
        },
        "dependencies": [],
    },
    {
        "id": "data.ambience.config",
        "file": "assets/audio/ambience.json",
        "origin": None,
        "role": "Ambience track list, fade length and per-track trim",
        "mapping": {
            "tracks": "res://assets/audio/ambience/waves-loop-v1.ogg",
            "fade_seconds": 2.0,
            "trim_db": -16.0,
        },
        "dependencies": ["audio.ambience.waves-loop"],
    },
]

SCRIPTS = [
    {
        "id": "ui.ambience-director",
        "file": "presentation/ambience_director.gd",
        "role": "Single looping ambience player; reads only the local audio preferences and the replay flag",
        "mapping": {
            "entry": "flow_app.gd/render after page_host.render",
            "preferences": "user://display-settings.cfg [audio] (shared with the music toggle)",
            "suspension": "an open gallery replay silences the sea as well",
        },
        "dependencies": ["data.ambience.config"],
    },
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    manifest_path = ROOT / "assets/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    added, bumped = [], []
    for entry in TRACKS + SCRIPTS:
        path = ROOT / entry["file"]
        if not path.is_file():
            raise SystemExit(f"missing source file: {entry['file']}")
        digest = sha256(path)
        existing = manifest["assets"].get(entry["id"])
        if existing is None:
            record = {
                "path": "res://" + entry["file"],
                "source": SOURCE if entry.get("origin") else entry["file"],
                "version": 1,
                "sha256": digest,
                "dependencies": entry.get("dependencies", []),
                "role": entry["role"],
                "license": (
                    "CC0 1.0 (OpenGameArt sources); processed into a seamless loop"
                    if entry.get("origin")
                    else "project-authored configuration and code"
                ),
                "source_hash_verified_on": VERIFIED,
                "runtime_mapping": entry["mapping"],
            }
            if entry.get("origin"):
                record["bytes"] = path.stat().st_size
            manifest["assets"][entry["id"]] = record
            added.append(entry["id"])
            continue
        if existing.get("sha256") == digest:
            continue
        existing["sha256"] = digest
        existing["version"] = int(existing.get("version", 1)) + 1
        existing["source_hash_verified_on"] = VERIFIED
        if entry.get("role"):
            existing["role"] = entry["role"]
        if entry.get("mapping"):
            existing["runtime_mapping"] = entry["mapping"]
        bumped.append(f"{entry['id']} v{existing['version']}")
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("AMBIENCE: added %s" % (", ".join(added) if added else "none"))
    print("AMBIENCE: bumped %s" % (", ".join(bumped) if bumped else "none"))


if __name__ == "__main__":
    main()
