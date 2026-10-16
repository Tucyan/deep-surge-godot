"""Play 2 Challenge Nightmare runs using the 'restless' (多动症) origin with 2 random seeds.
Evaluates the real in-game impact of having +1 Base AP and +1 Battle AP from Turn 1 under Nightmare conditions.
"""
import json
from pathlib import Path
import random
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from agent_client import AgentClient, data
from smart_playtest import SmartPlayer

def run_restless_nightmare(game, seed):
    player = SmartPlayer(verbose=True)
    player.log(f"\n=======================================================")
    player.log(f"  STARTING RUN: Origin=restless (多动症), Diff=NIGHTMARE, Seed={seed}")
    player.log(f"=======================================================\n")
    
    reset_params = {"seed": seed, "mode": "challenge", "difficulty": "nightmare", "origin": "restless"}
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
        hand = {c["uid"]: c for c in obs.get("hand", [])}
        
        if phase == "navigation":
            if not voyage_history or voyage_history[-1]["voyage"] != v:
                snap = {
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
                }
                voyage_history.append(snap)
                env_str = ", ".join(snap["environments"]) or "None"
                dev_str = ", ".join(snap["devices"]) or "None"
                player.log(f"\n[Voyage {v} | Navigation] HP: {p['hp']}/{p['hp_max']} | Hunger: {p['hunger']}/100 | Water: {p['hydration']}/100 | SAN: {p['sanity']}/100 | Base AP: {obs.get('ap', 0)} | Devices: [{dev_str}]")
                player.log(f"  Environments: [{env_str}] | Hand ({len(obs['hand'])}): {list(Counter(c['id'] for c in obs['hand']).items())}")
                
        actions = data(game.request("actions"))["actions"]
        action = player.choose_action(obs, actions)
        if not action:
            player.log(f"ERROR: No action at phase {phase}")
            break
            
        cmd = action["command"]
        args = action.get("args", {})
        
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
            player.log(f"  -> ENGAGED FIGHT: {m_name}")
            
        if phase == "battle" and current_battle:
            b = obs.get("battle", {})
            e = obs.get("enemy", {})
            current_battle["turns"] = b.get("turn", 1)
            current_battle["final_hp"] = p["hp"]
            if cmd in ("battle_action", "play", "salvage"):
                act_record = {
                    "turn": b.get("turn", 1),
                    "cmd": cmd,
                    "args": args,
                    "enemy_hp": e.get("hp", 0),
                    "ap": b.get("ap", 0)
                }
                current_battle["actions"].append(act_record)
                res_id = hand.get(args.get("resource_uid"), {}).get("id") if args.get("resource_uid") else args.get("action", "")
                player.log(f"    [Turn {b.get('turn',1)} | Enemy HP: {e.get('hp')} | AP: {b.get('ap')}] {cmd} {res_id or args}")
        elif cmd in ("craft", "install", "upgrade", "fuel", "repair_cell", "expand", "scout", "fix_heading", "play", "salvage", "voyage"):
            player.log(f"  -> Action: {cmd} {args}")
                
        resp = data(game.request("act", {"action_id": action["action_id"], "revision": obs["revision"]}))
        obs = resp["observation"]
        
    result = data(game.request("result"))
    trace = data(game.request("trace"))
    
    trace_path = ROOT / "evidence" / f"agent-restless-nightmare-{seed}.trace.json"
    trace_path.write_text(json.dumps(trace, ensure_ascii=False), encoding="utf-8")
    
    final_p = obs.get("player", {})
    player.log(f"\n=== FINISHED RUN Seed {seed} ===")
    player.log(f"Outcome: {result.get('outcome')} | Completed: {result.get('completed')}/12 | Final HP: {final_p.get('hp')}/{final_p.get('hp_max')}")
    player.log(f"Total Steps: {step_count} | Trace: {trace_path.name}")
    
    return {
        "seed": seed,
        "difficulty": "nightmare",
        "origin": "restless",
        "mode": "challenge",
        "outcome": result.get("outcome"),
        "completed_voyages": result.get("completed", 0),
        "total_steps": step_count,
        "trace_len": len(trace["steps"]),
        "trace_file": trace_path.name,
        "final_stats": final_p,
        "devices": [f"{c['equipment']['id']}(Lv{c['equipment']['level']})" for c in obs.get("cells", []) if c.get("equipment")],
        "voyage_history": voyage_history,
        "battles": battles_detail,
        "death_phase": result.get("phase") if result.get("outcome") != "survived" else None
    }

def main():
    from collections import Counter
    # Generate 2 random seeds
    random.seed()
    seeds = [random.randint(100000, 99999999), random.randint(100000, 99999999)]
    print(f"Randomly selected 2 seeds for Restless (多动症) Nightmare Challenge: {seeds}")
    
    results = []
    with AgentClient() as game:
        for seed in seeds:
            res = run_restless_nightmare(game, seed)
            results.append(res)
            
    summary_path = ROOT / "evidence" / "restless_nightmare_runs_summary.json"
    summary_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nAll Restless Nightmare runs completed! Summary written to {summary_path}")

if __name__ == "__main__":
    from collections import Counter
    main()
