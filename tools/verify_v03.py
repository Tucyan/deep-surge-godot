"""Run isolated, bounded Godot suites and retain exact diagnostic logs."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tests", nargs="+")
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--frames", type=int, default=600)
    args = parser.parse_args()
    godot = shutil.which("Godot_v4.7.2-stable_win64_console.exe") or shutil.which("godot")
    if not godot:
        raise SystemExit("Godot unavailable; no installation attempted")
    failed = []
    for name in args.tests:
        path = name if name.endswith(".gd") else f"tests/{name}.gd"
        if not (ROOT / path).is_file():
            raise SystemExit(f"Missing test: {path}")
        case = ROOT / ".planning/v03-development/verification" / Path(path).stem
        env = os.environ.copy()
        for key, subdir in (("APPDATA", "appdata"), ("LOCALAPPDATA", "local")):
            dest = case / subdir
            dest.mkdir(parents=True, exist_ok=True)
            env[key] = str(dest)
        command = [godot]
        if not args.graphical:
            command.append("--headless")
        command += ["--path", str(ROOT), "--script", "res://" + path,
                    "--quit-after", str(args.frames)]
        try:
            result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                                    text=True, encoding="utf-8", errors="replace", timeout=55)
        except subprocess.TimeoutExpired as exc:
            (case / "timeout.txt").write_text(str(exc), encoding="utf-8")
            print(f"TIMEOUT {name}: stopped; no retry. Run manually if desired.", flush=True)
            return 2
        output = result.stdout + result.stderr
        (case / "output.txt").write_text(output, encoding="utf-8")
        bad = result.returncode != 0 or any(marker in output for marker in
                ("SCRIPT ERROR", "Parse Error", "FAIL:", ": FAIL", " FAILED"))
        # A script that never reaches its report is not verified by quit-after.
        bad = bad or not any(marker in output for marker in ("PASS", "0 failures", "0 failed"))
        print(f"{'FAIL' if bad else 'PASS'} {name}", flush=True)
        if bad:
            failed.append(name)
            print(output[-6000:], flush=True)
    print(f"V03 SUITES: {len(args.tests)-len(failed)}/{len(args.tests)} PASS", flush=True)
    return bool(failed)


if __name__ == "__main__":
    sys.exit(main())
