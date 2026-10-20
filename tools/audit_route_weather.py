"""Bounded public-prefix weather audit for pre-filter route timing records."""
import argparse
import json
import os
import time
from pathlib import Path
from agent_client import AgentClient, data
from generate_regression_routes import save, prefix_hash, save_evidence


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkpoint", type=Path)
    parser.add_argument("--segment-seconds", type=float, default=20)
    args = parser.parse_args()
    checkpoint = json.loads(args.checkpoint.read_text(encoding="utf-8"))
    trace = checkpoint["trace"]
    audit_path = args.checkpoint.with_suffix(".weather-audit.json")
    audit = json.loads(audit_path.read_text(encoding="utf-8")) if audit_path.exists() else {"trace_sha256": prefix_hash(trace), "samples": []}
    assert audit["trace_sha256"] == prefix_hash(trace)
    isolated = args.checkpoint.parent / "weather-audit-user"
    for key in ("APPDATA", "LOCALAPPDATA"):
        (isolated / key).mkdir(parents=True, exist_ok=True)
        os.environ[key] = str((isolated / key).resolve())
    started = time.monotonic()
    with AgentClient(timeout=25) as game:
        prefix = {**trace, "steps": trace["steps"][:len(audit["samples"])]}
        public = data(game.request("replay", {"trace": prefix}))["observation"]
        game.timeout = 12
        play_started = time.monotonic()
        while len(audit["samples"]) < len(trace["steps"]) and time.monotonic() - play_started < args.segment_seconds and time.monotonic() - started < 38:
            index = len(audit["samples"])
            expected = trace["steps"][index]
            actions = data(game.request("actions"))["actions"]
            selected = next(a for a in actions if a["command"] == expected["command"] and a["args"] == expected["args"])
            public = data(game.request("act", {"action_id": selected["action_id"], "revision": public["revision"]}))["observation"]
            audit["samples"].append({"voyage": int(public["voyage"]), "weather_after":
                                    [{"id": e["id"], "pending": e.get("pending", False)} for e in public.get("environments", [])]})
        actual = data(game.request("trace"))
        assert prefix_hash(actual) == prefix_hash({**trace, "steps": trace["steps"][:len(audit["samples"])]})
    assert not game.errors, list(game.errors)
    audit["status"] = "verified" if len(audit["samples"]) == len(trace["steps"]) else "checkpointed"
    save(audit_path, audit)
    if audit["status"] == "verified":
        weather, previous, episodes, pending = {}, set(), 0, 0
        for sample in audit["samples"]:
            active = {e["id"] for e in sample["weather_after"] if not e["pending"]}
            pending += sum(e["pending"] for e in sample["weather_after"])
            key = str(sample["voyage"])
            weather[key] = sorted(set(weather.get(key, [])) | active)
            episodes += len(active - previous)
            previous = active
        audit["pending_samples"] = pending
        audit["corrected"] = {"weather_voyages": weather, "weather_episodes": episodes, "active_weather": sorted(previous)}
        checkpoint["metrics"].update(audit["corrected"])
        checkpoint["weather_audit"] = {"status": "verified", "pending_samples": pending, "steps": len(audit["samples"])}
        save(args.checkpoint, checkpoint)
        save_evidence(checkpoint)
        save(audit_path, audit)
    print(json.dumps({"status": audit["status"], "samples": len(audit["samples"]), "steps": len(trace["steps"])}), flush=True)


if __name__ == "__main__":
    main()
