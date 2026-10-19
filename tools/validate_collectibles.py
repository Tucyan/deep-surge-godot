"""Bounded, isolated Godot checks. Script errors fail even if Godot exits zero."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CHECKS = [
    "relic_rewards", "collectible_effects", "collectible_voyage_install", "collectible_battle",
    "collectible_integration", "collectible_ui", "collectible_agent", "session", "catalog", "save", "origins_v2",
    "origins_edges", "battle_actions", "formal_shop", "node_shop_integration",
    "voyage_survival", "action_query", "action_catalogue", "auto_progress",
    "environment", "round_start_production", "chapter1_saves", "narrative_repairs",
    "reward_recovery", "recall_restore", "tutorial", "interaction_refresh",
    "navigation_partial_refresh", "application_boundaries", "agent_session", "routes",
]


def main():
    executable = shutil.which("Godot_v4.7.2-stable_win64_console.exe") or shutil.which("godot")
    if not executable:
        raise SystemExit("Godot not found; no dependency download attempted")
    directory = ROOT / ".planning/collectibles/verification"
    directory.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for key, child in (("APPDATA", "appdata"), ("LOCALAPPDATA", "local")):
        path = directory / child
        path.mkdir(exist_ok=True)
        env[key] = str(path)
    rows = []
    for name in sys.argv[1:] or CHECKS:
        try:
            result = subprocess.run(
                [executable, "--headless", "--path", str(ROOT), "--script", f"res://tests/test_{name}.gd"],
                cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8", timeout=30,
            )
        except subprocess.TimeoutExpired:
            rows.append({"test": name, "passed": False, "timeout": True})
            print(f"TIMEOUT {name}: stopped; no retry", flush=True)
            break
        output = result.stdout + result.stderr
        (directory / f"test_{name}.log").write_text(output, encoding="utf-8")
        passed = result.returncode == 0 and not any(marker in output for marker in ("SCRIPT ERROR", "ERROR:", "FAIL:"))
        rows.append({"test": name, "passed": passed, "exit_code": result.returncode})
        print(f"{'PASS' if passed else 'FAIL'} {name}", flush=True)
        if not passed:
            print(output[-6000:], flush=True)
    (directory / "results.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{sum(row['passed'] for row in rows)}/{len(rows)} passed", flush=True)
    return 0 if rows and all(row["passed"] for row in rows) else 1


if __name__ == "__main__":
    sys.exit(main())
