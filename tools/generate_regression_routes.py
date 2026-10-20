"""Bounded public Agent routes. Checkpoints are evidence, never fixtures.

Resume replays the unmodified reset initial and complete command/hash prefix.
Terminal traces must replay in an independent process before publication.
"""
import argparse
import hashlib
import json
import os
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


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def save_evidence(record):
    save(ROOT / "evidence" / ("v03-route-" + record["route"] + ".metrics.json"),
         {key: value for key, value in record.items() if key != "trace"})


def prefix_hash(trace):
    # Godot JSON round trips integral values as floats; normalize wire numbers.
    def normalize(value):
        if isinstance(value, float) and value.is_integer():
            return int(value)
        if isinstance(value, dict):
            return {key: normalize(item) for key, item in value.items()}
        if isinstance(value, list):
            return [normalize(item) for item in value]
        return value
    return hashlib.sha256(json.dumps(normalize(trace), sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()


def failure_action(obs, actions):
    for command in ("voyage", "enter", "advance", "leave_encounter", "shop_leave",
                    "shop_enter", "option", "end_voyage", "discard", "battle_action", "battle_end"):
        found = next((a for a in actions if a["command"] == command), None)
        if found:
            return found
    raise RuntimeError("failure scenario has no next action: " + obs["phase"])


def summarize(obs):
    return {key: obs.get(key) for key in ("voyage", "phase", "completed", "player", "environments")}


def metric_step(metrics, before, after, events):
    voyage = str(int(after["voyage"]))
    weather = metrics.setdefault("weather_voyages", {})
    active = [e["id"] for e in after.get("environments", []) if not e.get("pending", False)]
    weather[voyage] = sorted(set(weather.get(voyage, [])) | set(active))
    previous = set(metrics.get("active_weather", []))
    metrics["weather_episodes"] = metrics.get("weather_episodes", 0) + len(set(active) - previous)
    metrics["active_weather"] = active
    for event in events:
        if event.get("kind") == "battle_enter":
            metrics["battles"] = metrics.get("battles", 0) + 1
            if before.get("node", {}).get("boss"):
                metrics.setdefault("boss_entry_hp", []).append({"voyage": before["voyage"], "hp": before["player"]["hp"]})
        if event.get("kind") == "attribute" and event.get("source") == "deprivation":
            metrics["deprivation_damage"] = metrics.get("deprivation_damage", 0) + max(0, -event.get("delta", 0))


def generate(route, args):
    identity, difficulty, mode, seed = route
    checkpoint = args.checkpoint or ROOT / ".planning/v03-development/routes" / (identity + ".checkpoint.json")
    # All processes, including independent replays, use isolated user directories.
    isolation = checkpoint.parent / (identity + "-user")
    for key in ("APPDATA", "LOCALAPPDATA"):
        directory = isolation / key
        directory.mkdir(parents=True, exist_ok=True)
        os.environ[key] = str(directory.resolve())
    prior = json.loads(checkpoint.read_text(encoding="utf-8")) if args.resume or args.verify_only else None
    if prior and (prior["route"] != identity or prior["prefix_sha256"] != prefix_hash(prior["trace"])):
        raise ValueError("checkpoint identity/hash mismatch")
    if args.verify_only:
        verify_checkpoint(checkpoint, prior)
        return
    timings = prior["timings"] if prior else []
    metrics = prior["metrics"] if prior else {"battles": 0, "weather_episodes": 0, "deprivation_damage": 0, "boss_entry_hp": []}
    segments = prior["segments"] if prior else []
    started = time.monotonic()
    player = SmartPlayer(verbose=False)
    with AgentClient(timeout=12) as game:
        if prior:
            game.timeout = 25
            replay_started = time.monotonic()
            resumed = data(game.request("replay", {"trace": prior["trace"]}))
            replay_seconds = time.monotonic() - replay_started
            game.timeout = 12
            assert resumed["steps"] == len(prior["trace"]["steps"])
            obs = data(game.request("observe"))
        else:
            replay_seconds = 0
            obs = data(game.request("reset", {"seed": seed, "difficulty": difficulty, "mode": mode}))["observation"]
        count = 0
        play_started = time.monotonic()
        while not obs["terminal"] and count < args.max_segment_steps and time.monotonic() - play_started < args.segment_seconds and time.monotonic() - started < 38:
            before = obs
            tick = time.monotonic()
            actions = data(game.request("actions"))["actions"]
            query_seconds = time.monotonic() - tick
            if time.monotonic() - started >= 40:
                break  # Query is read-only; retain enough wall budget for act/trace.
            action = failure_action(obs, actions) if identity == "standard-failure" else player.choose_action(obs, actions)
            if action is None:
                raise RuntimeError(f"{identity}: no action in {obs['phase']}")
            tick = time.monotonic()
            response = data(game.request("act", {"action_id": action["action_id"], "revision": obs["revision"]}))
            obs = response["observation"]
            timings.append({"step": len(timings) + 1, "voyage": before["voyage"], "phase": before["phase"],
                            "command": action["command"], "actions_seconds": round(query_seconds, 5),
                            "act_seconds": round(time.monotonic() - tick, 5),
                            "weather_after": [{"id": e["id"], "pending": e.get("pending", False)} for e in obs.get("environments", [])]})
            metric_step(metrics, before, obs, response.get("events", []))
            count += 1
            if before["voyage"] != obs["voyage"]:
                print(json.dumps({"route": identity, "progress": summarize(obs)}, ensure_ascii=False), flush=True)
        result = data(game.request("result"))
        trace = data(game.request("trace"))
        if prior:
            assert trace["initial"] == prior["trace"]["initial"]
            trace["initial"] = prior["trace"]["initial"]
    assert not game.errors, list(game.errors)
    segments.append({"steps": count, "elapsed_seconds": round(time.monotonic() - started, 3), "replay_seconds": round(replay_seconds, 3), "progress": summarize(obs)})
    record = {"route": identity, "status": "terminal_pending_replay" if result["terminal"] else "checkpointed",
              "trace": trace, "prefix_sha256": prefix_hash(trace), "timings": timings,
              "metrics": metrics, "segments": segments, "result": result}
    save(checkpoint, record)
    save_evidence(record)
    print(json.dumps({"route": identity, "status": record["status"], "steps": len(trace["steps"]), "progress": summarize(obs)}, ensure_ascii=False), flush=True)


def verify_checkpoint(checkpoint, record):
    identity, trace, result, metrics = record["route"], record["trace"], record["result"], record["metrics"]
    assert result["terminal"], "nonterminal checkpoints cannot be published"
    started = time.monotonic()
    with AgentClient(timeout=25) as replay_game:
        replay = data(replay_game.request("replay", {"trace": trace}))
        replay_game.timeout = 12
        replay_result = data(replay_game.request("result"))
        replay_trace = data(replay_game.request("trace"))
        assert replay["steps"] == len(trace["steps"])
        assert replay_result == result
        assert prefix_hash(replay_trace) == prefix_hash(trace)
    assert not replay_game.errors, list(replay_game.errors)
    filename = identity + ".trace.json"
    save(DEST / filename, trace)
    manifest_path = DEST / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {"routes": []}
    row = {"id": identity, "path": "res://tests/fixtures/routes/" + filename,
           "expected": {key: result[key] for key in ("phase", "outcome", "completed")},
           "steps": len(trace["steps"]), "version": trace["initial"]["content_version"]}
    manifest["routes"] = [r for r in manifest["routes"] if r["id"] != identity] + [row]
    save(manifest_path, manifest)
    record["status"] = "published"
    record["independent_replay"] = {"steps": replay["steps"], "prefix_sha256": prefix_hash(replay_trace), "result_equal": True, "elapsed_seconds": round(time.monotonic() - started, 3)}
    save(checkpoint, record)
    save_evidence(record)
    print(json.dumps({**row, "status": "published", "metrics": metrics}, ensure_ascii=False), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--route", choices=[r[0] for r in ROUTES], required=True)
    parser.add_argument("--segment-seconds", type=float, default=15)
    parser.add_argument("--max-segment-steps", type=int, default=80)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--verify-only", action="store_true", help="independent terminal replay and fixture publication, no gameplay")
    args = parser.parse_args()
    if not 0 < args.segment_seconds <= 20 or args.max_segment_steps < 1:
        parser.error("segment seconds must be (0,20], steps >= 1; terminal publication requires --verify-only")
    try:
        generate(next(route for route in ROUTES if route[0] == args.route), args)
    except TimeoutError as error:
        checkpoint = args.checkpoint or ROOT / ".planning/v03-development/routes" / (args.route + ".checkpoint.json")
        timeout_path = checkpoint.with_suffix(".timeout.json")
        if timeout_path.exists():
            timeout_path = checkpoint.with_suffix(f".timeout-{time.time_ns()}.json")
        save(timeout_path, {"route": args.route, "status": "request_timeout",
             "error": str(error), "retry": False, "previous_checkpoint": str(checkpoint)})
        raise


if __name__ == "__main__":
    main()
