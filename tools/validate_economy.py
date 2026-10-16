"""v11 public-action economy sample; fixed heuristic, no private state in decisions."""
import argparse
import json
from collections import Counter
from pathlib import Path
from statistics import median
from agent_client import AgentClient, data
from validate_node_shop import decide

ROOT = Path(__file__).resolve().parents[1]

def run(game, seed, mode):
    o = data(game.request("reset", {"seed":seed,"mode":mode}))["observation"]
    boss_materials = None
    first_devices = {}
    for step in range(650):
        for cell in o["cells"]:
            item = cell.get("equipment",{}).get("id")
            if item: first_devices.setdefault(item,o["voyage"])
        if o["terminal"]: break
        actions = data(game.request("actions"))["actions"]
        a = decide(o, actions)
        if a is None: raise RuntimeError("No action at "+o["phase"])
        if a["command"]=="fight" and o["node"].get("boss"):
            boss_materials = sum(c["id"] in ("wood","iron","rope","plastic","cloth") for c in o["hand"])
        o=data(game.request("act",{"action_id":a["action_id"],"revision":o["revision"]}))["observation"]
    result=data(game.request("result"))
    assert result["terminal"], (seed,mode,"step limit")
    trace=data(game.request("trace"))
    path=ROOT/"evidence"/f"economy-v11-{mode}-{seed}.trace.json"
    path.write_text(json.dumps(trace,ensure_ascii=False),encoding="utf-8")
    replay=data(game.request("replay",{"trace":trace}))
    assert replay["steps"]==len(trace["steps"])
    cards=result["report"].get("cards",[])
    for card in cards:
        assert card["obtained"]==card["remaining"]+sum(card.get(k,0) for k in ("use_consumed","cost_consumed","deployed","discarded","lost","cleared","sold")), card
    return {"seed":seed,"mode":mode,"outcome":result["outcome"],"phase":result["phase"],"completed":result["completed"],"steps":len(trace["steps"]),"replayed":replay["steps"],"boss_materials":boss_materials,"first_devices":first_devices,"spring_cards":sum(c.get("sources",{}).get("spring",0) for c in cards),"discarded":sum(c.get("discarded",0) for c in cards),"minimum":result["report"].get("stats",{}).get("minimum",{}),"trace":path.name}

if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--count",type=int,default=100);args=parser.parse_args()
    rows=[]
    with AgentClient() as game:
        for mode,seed in [("challenge",n) for n in range(args.count)]+[("story",22)]:
            row=run(game,seed,mode);rows.append(row)
            if (seed+1)%10==0 or mode=="story":print(json.dumps({"runs":len(rows),"latest":row},ensure_ascii=False),flush=True)
        assert not game.errors,list(game.errors)
    challenges=[r for r in rows if r["mode"]=="challenge"]
    boss=[r["boss_materials"] for r in challenges if r["boss_materials"] is not None]
    summary={"policy":"validate_node_shop.decide, public observation, strong origin, no meta upgrades","challenge_count":len(challenges),"outcomes":dict(Counter(r["outcome"] for r in challenges)),"boss_entries":len(boss),"boss_materials_median":median(boss) if boss else None,"discarded_median":median(r["discarded"] for r in challenges),"all_replayed":all(r["steps"]==r["replayed"] for r in rows),"story_phase":rows[-1]["phase"]}
    (ROOT/"evidence/economy-v11-runs.json").write_text(json.dumps({"summary":summary,"runs":rows},ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps(summary,ensure_ascii=False),flush=True)
