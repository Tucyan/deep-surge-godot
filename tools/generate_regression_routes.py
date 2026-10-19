"""Generate current-version public-interface fixtures; never modify player saves.

Each route uses a real Agent process and replays its JSON trace before publication.
The success strategy is the existing local heuristic, not a balance benchmark.
"""
import argparse
import json
from pathlib import Path
import time

from agent_client import AgentClient, data
from smart_playtest import SmartPlayer

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "tests/fixtures/routes"
ROUTES = [(f"{difficulty}-{mode}", difficulty, mode, 22)
          for difficulty in ("standard", "hard", "nightmare")
          for mode in ("challenge", "story")]
ROUTES.append(("standard-failure", "standard", "challenge", 22))
HISTORICAL = [f"res://evidence/tech-v22-{name}.trace.json" for name in (
    "standard-challenge-22", "standard-challenge-39", "standard-challenge-9",
    "standard-challenge-73", "standard-challenge-1000", "standard-challenge-7919",
    "standard-challenge-20261016", "standard-challenge-4294967295", "standard-story-22",
    "hard-challenge-22", "hard-story-22", "nightmare-challenge-22", "nightmare-story-22")]


def failure_action(obs, actions):
    """A public survival-failure scenario: travel without restoring food or SAN."""
    for command in ("voyage", "enter", "advance", "leave_encounter", "shop_leave",
                    "shop_enter", "option", "end_voyage", "discard", "battle_action", "battle_end"):
        found = next((a for a in actions if a["command"] == command), None)
        if found:
            return found
    raise RuntimeError("failure scenario has no next action: " + obs["phase"])


def generate(route):
    identity, difficulty, mode, seed = route
    started = time.monotonic()
    player = SmartPlayer(verbose=False)
    with AgentClient() as game:
        obs = data(game.request("reset", {"seed":seed, "difficulty":difficulty, "mode":mode}))['observation']
        for _ in range(800):
            if obs["terminal"]:
                break
            if time.monotonic() - started > 45:
                raise TimeoutError(f"{identity}: 45s route limit; no retry")
            actions = data(game.request("actions"))["actions"]
            action = failure_action(obs, actions) if identity == "standard-failure" else player.choose_action(obs, actions)
            if action is None:
                raise RuntimeError(f"{identity}: no action in {obs['phase']}")
            obs = data(game.request("act", {"action_id":action["action_id"], "revision":obs["revision"]}))["observation"]
        result = data(game.request("result"))
        assert result["terminal"], (identity, "step limit")
        trace = data(game.request("trace"))
        encoded = json.dumps(trace, ensure_ascii=False, separators=(",", ":"))
        replay = data(game.request("replay", {"trace":json.loads(encoded)}))
        assert replay["steps"] == len(trace["steps"]), identity
        assert not game.errors, list(game.errors)
    DEST.mkdir(parents=True, exist_ok=True)
    filename = identity + ".trace.json"
    (DEST / filename).write_text(encoded + "\n", encoding="utf-8", newline="\n")
    return {"id":identity, "path":"res://tests/fixtures/routes/" + filename,
            "expected":{"phase":result["phase"], "outcome":result["outcome"], "completed":result["completed"]},
            "steps":len(trace["steps"]), "version":trace["initial"]["content_version"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--route", choices=[r[0] for r in ROUTES])
    args = parser.parse_args()
    manifest_path = DEST / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {"routes":[], "historical_paths":HISTORICAL}
    for route in ROUTES:
        if args.route and route[0] != args.route:
            continue
        row = generate(route)
        manifest["routes"] = [r for r in manifest["routes"] if r["id"] != row["id"]] + [row]
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(json.dumps(row, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
