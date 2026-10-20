"""Register the user-supplied daily background music, its cue table and the director.

Runtime files keep the bytes from the supplied archive; only names, mapping and
hashes are authored here. Existing script entries are bumped in place instead of
being duplicated, so one file keeps one AssetId. Re-run after changing a track,
the cue table or any registered script.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = "日常背景音乐(1).zip"
VERIFIED = "2026-10-20"

TRACKS = [
    {
        "id": "audio.music.daily-aria",
        "file": "assets/music/daily-arsnova-bwv82-aria-v1.mp3",
        "origin": "Quartetto Chitarristico Ars Nova Johann Sebastian Bach - Cantata Ich Habe Genug BWV82 Aria.mp3",
        "role": "Home and settlement background music (Bach BWV82 aria, guitar quartet)",
        "mapping": {"cue": "home", "loop": True, "player": "music_director.gd/MusicTrackA"},
        "dependencies": [],
    },
    {
        "id": "audio.music.daily-fuga",
        "file": "assets/music/daily-arsnova-bwv578-fuga-v1.mp3",
        "origin": "Quartetto Chitarristico Ars Nova Johann Sebastian Bach - Fuga BWV578.mp3",
        "role": "Voyage background music (Bach BWV578 fugue, guitar quartet)",
        "mapping": {"cue": "voyage", "loop": True, "player": "music_director.gd/MusicTrackB"},
        "dependencies": [],
    },
    {
        "id": "data.music.cues",
        "file": "assets/music/music.json",
        "origin": None,
        "role": "Cue table, crossfade length and per-cue fallback",
        "mapping": {
            "cues": "home | voyage | boss",
            "boss_tracks": "empty until the boss archive contains audio; the cue falls back to voyage",
            "fade_seconds": 1.5,
            "trim_db": -6.0,
        },
        "dependencies": ["audio.music.daily-aria", "audio.music.daily-fuga"],
    },
]

SCRIPTS = [
    {
        "id": "ui.music-director",
        "file": "presentation/music_director.gd",
        "role": "Two-player music crossfade; reads only screen, phase and the current node boss flag",
        "mapping": {
            "entry": "flow_app.gd/render after page_host.render",
            "preferences": "user://display-settings.cfg [audio]",
            "suspension": "an open gallery replay keeps only the narration music",
        },
        "dependencies": ["data.music.cues"],
    },
    {"id": "ui.modal-layout", "file": "flow_app.gd"},
    {"id": "ui.settings-panel", "file": "presentation/settings_panel.gd"},
    {"id": "ui.display-preferences", "file": "presentation/display_settings.gd"},
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
                "source": (
                    f"user-supplied/{ARCHIVE}/{entry['origin']}" if entry.get("origin")
                    else entry["file"]
                ),
                "version": 1,
                "sha256": digest,
                "dependencies": entry.get("dependencies", []),
                "role": entry["role"],
                "license": "user-supplied audio" if entry.get("origin") else "project-authored configuration and code",
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
    print("MUSIC: added %s" % (", ".join(added) if added else "none"))
    print("MUSIC: bumped %s" % (", ".join(bumped) if bumped else "none"))


if __name__ == "__main__":
    main()
