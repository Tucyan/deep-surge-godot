"""Run 6 Challenge Mode playthroughs across 2 seeds and 3 difficulties.
Records detailed telemetry, survival curves, combat stats, and saves traces.
"""
import json
from pathlib import Path
import sys
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from agent_client import AgentClient, data
from smart_playtest import SmartPlayer

def run_single(game, seed, difficulty, mode="challenge"):
    player = SmartPlayer(verbose=False)
    reset_params = {"seed": seed, "mode": mode, "difficulty": difficulty, "origin": "strong"}
    obs = data(game.request("reset", reset_params))["observation"]
    
    voyage_history = []
    battles_detail = []
    current_battle = None
    step_count = 0
    max_steps = 800
    
    while not obs["terminal"] and step_count < max_steps:
        step_count += 1
        v = obs.get("voyage", 0)
        p = obs["player"]
        phase = obs["phase"]
        
        # Record voyage entry snapshot
        if phase == "navigation":
            if not voyage_history or voyage_history[-1]["voyage"] != v:
                voyage_history.append({
                    "voyage": v,
                    "hp": p["hp"],
                    "hp_max": p["hp_max"],
                    "hunger": p["hunger"],
                    "hydration": p["hydration"],
                    "sanity": p["sanity"],
                    "coins": obs.get("coins", 0),
                    "cells": len(obs.get("cells", [])),
                    "devices": [f"{c['equipment']['id']}(Lv{c['equipment']['level']})" for c in obs.get("cells", []) if c.get("equipment")],
                    "environments": [e["id"] for e in obs.get("environments", [])],
                    "hand_count": len(obs.get("hand", []))
                })
                
        actions = data(game.request("actions"))["actions"]
        action = player.choose_action(obs, actions)
        if not action:
            break
            
        cmd = action["command"]
        args = action.get("args", {})
        
        # Combat tracking
        if cmd == "fight":
            m = obs.get("node", {}).get("monster", {})
            m_name = m.get("name", m) if isinstance(m, dict) else str(m)
            current_battle = {
                "voyage": v,
                "enemy": m_name,
                "turns": 0,
                "initial_hp": p["hp"],
                "final_hp": p["hp"],
                "actions": []
            }
            battles_detail.append(current_battle)
            
        if phase == "battle" and current_battle:
            b = obs.get("battle", {})
            e = obs.get("enemy", {})
            current_battle["turns"] = b.get("turn", 1)
            current_battle["final_hp"] = p["hp"]
            if cmd in ("battle_action", "play", "salvage"):
                current_battle["actions"].append({
                    "turn": b.get("turn", 1),
                    "cmd": cmd,
                    "args": args,
                    "enemy_hp": e.get("hp", 0),
                    "ap": b.get("ap", 0)
                })
                
        resp = data(game.request("act", {"action_id": action["action_id"], "revision": obs["revision"]}))
        obs = resp["observation"]
        
    result = data(game.request("result"))
    trace = data(game.request("trace"))
    
    # Save trace
    trace_path = ROOT / "evidence" / f"agent-v20-run-{seed}-{difficulty}.trace.json"
    trace_path.write_text(json.dumps(trace, ensure_ascii=False), encoding="utf-8")
    
    final_p = obs.get("player", {})
    return {
        "seed": seed,
        "difficulty": difficulty,
        "mode": mode,
        "outcome": result.get("outcome"),
        "completed_voyages": result.get("completed", 0),
        "total_steps": step_count,
        "trace_len": len(trace["steps"]),
        "trace_file": trace_path.name,
        "final_stats": {
            "hp": final_p.get("hp"),
            "hp_max": final_p.get("hp_max"),
            "hunger": final_p.get("hunger"),
            "hydration": final_p.get("hydration"),
            "sanity": final_p.get("sanity"),
            "coins": obs.get("coins", 0),
            "cells": len(obs.get("cells", []))
        },
        "devices": [f"{c['equipment']['id']}(Lv{c['equipment']['level']})" for c in obs.get("cells", []) if c.get("equipment")],
        "voyage_history": voyage_history,
        "battles": battles_detail,
        "death_phase": result.get("phase") if result.get("outcome") != "survived" else None
    }

def main():
    runs = [
        (22, "standard"),
        (22, "hard"),
        (22, "nightmare"),
        (1000, "standard"),
        (1000, "hard"),
        (1000, "nightmare"),
    ]
    
    results = []
    print(f"Starting execution of 6 v20 agent games across seeds [22, 1000] and difficulties [standard, hard, nightmare]...\n")
    
    with AgentClient() as game:
        for seed, diff in runs:
            print(f">>> Running Seed {seed} | Difficulty {diff.upper()}...")
            summary = run_single(game, seed, diff)
            results.append(summary)
            print(f"    Outcome: {summary['outcome'].upper()} | Completed: {summary['completed_voyages']}/12 voyages | Steps: {summary['total_steps']}")
            print(f"    Final HP: {summary['final_stats']['hp']}/{summary['final_stats']['hp_max']} | Food: {summary['final_stats']['hunger']} | Water: {summary['final_stats']['hydration']} | SAN: {summary['final_stats']['sanity']}")
            print(f"    Battles: {[b['enemy'] for b in summary['battles']]} | Devices: {summary['devices']}\n")
            
    summary_path = ROOT / "evidence" / "v20_six_agent_runs_summary.json"
    summary_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"All 6 v20 runs completed! Master summary written to {summary_path}")

if __name__ == "__main__":
    main()
