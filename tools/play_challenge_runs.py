"""Dedicated 4-Run Challenge Playtest Driver for Deep Surge Godot V0.3.

Executes 4 distinct challenge runs via the persistent Agent JSONL interface:
  Run 1: Difficulty Standard, Seed 42
  Run 2: Difficulty Standard, Seed 1024
  Run 3: Difficulty Hard,     Seed 42
  Run 4: Difficulty Hard,     Seed 1024

Collects turn-by-turn progression, layer transitions, combat actions,
resource management, and final outcomes.
"""
from collections import Counter
import json
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from agent_client import AgentClient, data


class V03AgentPlayer:
    def __init__(self, run_id="", verbose=True):
        self.run_id = run_id
        self.verbose = verbose
        self.log_entries = []
        self.milestones = []
        self.battles_summary = []

    def log(self, msg):
        if self.verbose:
            print(msg, flush=True)
        self.log_entries.append(msg)

    def choose_action(self, obs, actions):
        p = obs["player"]
        phase = obs["phase"]
        hand = {c["uid"]: c for c in obs.get("hand", [])}
        counts = Counter(c["id"] for c in obs.get("hand", []))
        cells = obs.get("cells", [])
        devices = {c["equipment"].get("id"): c["equipment"] for c in cells if c.get("status") == "intact" and c.get("equipment")}
        damaged_cells = [c for c in cells if c.get("status") == "damaged"]
        empty_cells = [c for c in cells if c.get("status") == "intact" and not c.get("equipment")]

        def find(cmd, pred=lambda a: True):
            return next((a for a in actions if a["command"] == cmd and pred(a)), None)

        def find_all(cmd, pred=lambda a: True):
            return [a for a in actions if a["command"] == cmd and pred(a)]

        # --- Survival Items Usage (Navigation, Preparation, Aftermath, Battle) ---
        if phase in ("navigation", "preparation", "aftermath", "battle"):
            # Medkit usage: if HP deficit >= 3, or in critical danger (HP <= 5)
            if p["hp_max"] - p["hp"] >= 3 or p["hp"] <= 5:
                act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "medkit" and a["effective"])
                if act:
                    return act
            # Water usage: deficit >= 35 or hydration <= 30
            if p["hydration_max"] - p["hydration"] >= 35 or (p["hydration"] <= 30 and phase != "battle"):
                act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "water" and a["effective"])
                if act:
                    return act
            # Food usage: deficit >= 35 or hunger <= 30
            if p["hunger_max"] - p["hunger"] >= 35 or (p["hunger"] <= 30 and phase != "battle"):
                act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "food" and a["effective"])
                if act:
                    return act
            # Sanity (Calm)
            if p["sanity_max"] - p["sanity"] >= 20 or p["sanity"] <= 50:
                act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "calm" and a["effective"])
                if act:
                    return act

        # --- Base Operations (Preparation, Aftermath, Navigation) ---
        if phase in ("navigation", "preparation", "aftermath"):
            # Emergency crafting: if HP <= 6, prioritize crafting a medkit immediately if we have materials and AP!
            if p["hp"] <= 6 and counts["cloth"] >= 2 and counts["wood"] >= 1 and obs.get("ap", 0) >= 1:
                craft_med = find("craft", lambda a: a["args"].get("id") == "medkit")
                if craft_med:
                    return craft_med

            # 1. Claim generator boosts if available
            claim = find("claim_boost")
            if claim:
                return claim

            # 2. Repair damaged cells before detachment (unless HP is critical and medkit needed)
            if damaged_cells and (p["hp"] > 6 or counts["cloth"] < 2):
                rep = find("repair_cell", lambda a: a["args"].get("material") == "wood") or find("repair_cell")
                if rep:
                    return rep

            # 3. Fuel lamp if low fuel (< 2)
            lamp = devices.get("lamp")
            if lamp and lamp.get("fuel", 0) < 2:
                fuel_act = find("fuel", lambda a: a["args"].get("material") == "corpse")
                if not fuel_act and counts["wood"] >= 1:
                    fuel_act = find("fuel", lambda a: a["args"].get("material") == "wood")
                if fuel_act:
                    return fuel_act

            # 4. Install crafted equipment from hand into empty cells
            if empty_cells:
                install_prio = ["filter", "planter", "lamp", "crossbow", "fishingNet", "shieldRack", "spearRack", "crate"]
                for dev_id in install_prio:
                    inst = find("install", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == dev_id)
                    if inst:
                        return inst

            # 5. Craft essential devices if empty cell available
            if empty_cells and obs.get("ap", 0) >= 1:
                if p["hydration"] <= 40 or p["hunger"] <= 40:
                    craft_prio = ["filter", "planter", "lamp", "crossbow", "fishingNet", "shieldRack"]
                else:
                    craft_prio = ["lamp", "filter", "planter", "crossbow", "fishingNet", "shieldRack"]
                for dev_id in craft_prio:
                    if dev_id not in devices and not any(c["id"] == dev_id for c in hand.values()):
                        craft = find("craft", lambda a: a["args"].get("id") == dev_id)
                        if craft:
                            return craft

                # Secondary combat/utility devices
                dev_counts = Counter(c["equipment"]["id"] for c in cells if c.get("equipment"))
                hand_counts = Counter(c["id"] for c in hand.values())
                secondary_prio = ["crossbow", "fishingNet", "shieldRack", "crate"]
                for dev_id in secondary_prio:
                    max_target = 2 if dev_id in ("crossbow", "fishingNet", "shieldRack") else 1
                    if dev_counts[dev_id] + hand_counts[dev_id] < max_target:
                        craft = find("craft", lambda a: a["args"].get("id") == dev_id)
                        if craft:
                            return craft

            # 6. Upgrade survival devices (filter/planter)
            if obs.get("ap", 0) >= 1:
                for target_dev in ("filter", "planter", "fishingNet"):
                    if target_dev in devices and devices[target_dev].get("level", 1) < 2:
                        upg = find("upgrade", lambda a: any(c["id"] == a["args"].get("cell") and c["equipment"].get("id") == target_dev for c in cells))
                        if upg:
                            return upg

            # 7. Craft defensive medkits
            if counts["cloth"] >= 2 and counts["wood"] >= 1 and counts["medkit"] < 3 and obs.get("ap", 0) >= 1:
                craft_med = find("craft", lambda a: a["args"].get("id") == "medkit")
                if craft_med:
                    return craft_med

            # 8. Expand raft if wood >= 2 and AP available and no empty cells
            if counts["wood"] >= 2 and obs.get("ap", 0) >= 1 and len(empty_cells) == 0:
                exp = find("expand")
                if exp:
                    return exp

            # 9. Navigation-specific decisions
            if phase == "navigation":
                nav = obs.get("navigation", {})
                if nav.get("wrong_direction_chance", 0) > 0 and not nav.get("heading_locked", False):
                    fix = find("fix_heading")
                    if fix:
                        return fix

                if p["sanity"] > 60:
                    scout_act = find("scout")
                    if scout_act:
                        return scout_act

                # Score candidates
                def score_node(cand):
                    cid = cand.get("id", "")
                    kind = cand.get("kind", "")
                    val = 20
                    if cand.get("boss"):
                        return 10000
                    if cid == "camp":
                        return 120
                    if kind == "rest":
                        return 90
                    # Emergency survival node weighting
                    if p["hydration"] <= 35 or p["hunger"] <= 35:
                        if kind == "supply" or cid in ("provision", "sharedMeal"):
                            return 150
                    if kind == "supply" or cid in ("provision", "sharedMeal"):
                        return 70
                    if kind == "shop":
                        return 85 if (obs.get("coins", 0) >= 3 or counts["corpse"] >= 1) else 40
                    if kind == "exchange":
                        return 40
                    if cand.get("monster") or kind == "battle":
                        if p["hp"] >= 10 and ("crossbow" in devices or counts["arrow"] >= 2):
                            return 45
                        else:
                            return 5
                    return val

                best_cand = max(obs["candidates"], key=score_node)
                voyage_act = find("voyage", lambda a: a["args"].get("id") == best_cand["visit_id"])
                if voyage_act:
                    return voyage_act
                fallback_v = find("voyage")
                if fallback_v:
                    return fallback_v

            # 10. Aftermath / Preparation fallback
            if phase == "aftermath" and obs.get("ap", 0) > 0 and len(obs.get("hand", [])) < p["limit"]:
                salv = find("salvage")
                if salv:
                    return salv

            if phase == "preparation":
                enter = find("enter")
                if enter:
                    return enter
            elif phase == "aftermath":
                end_v = find("end_voyage")
                if end_v:
                    return end_v

        # --- Story / Node Events ---
        if phase == "story":
            adv = find("advance")
            if adv:
                return adv

            if obs.get("node", {}).get("boss"):
                fight = find("fight")
                if fight:
                    return fight

            if obs.get("node", {}).get("monster"):
                if p["hp"] >= 9:
                    fight = find("fight")
                    if fight:
                        return fight
                leave = find("leave_encounter")
                if leave:
                    return leave
                fight = find("fight")
                if fight:
                    return fight

            skip_act = find("skip")
            if skip_act:
                return skip_act

            options = find_all("option")
            if options:
                opts_map = {x["id"]: x for x in obs.get("event_options", [])}
                def score_opt(a):
                    opt = opts_map.get(a["args"].get("id"), {})
                    prev = opt.get("preview", {})
                    s = 0.0
                    for stat, delta in prev.get("attributes", {}).items():
                        cur = p.get(stat, 0)
                        max_val = p.get(stat + "_max", 100)
                        effective_gain = min(max_val - cur, max(0, delta))
                        s += effective_gain * (3.5 if stat == "hp" else 1.2)
                    for r_card, amt in prev.get("cards", {}).items():
                        s += amt * 2.0
                    if prev.get("rested"):
                        s += 5.0
                    if prev.get("repair"):
                        s += 8.0
                    if prev.get("random_resources", 0):
                        s += prev["random_resources"] * 2.0
                    if opt.get("cost", 0):
                        s -= opt["cost"] * 2.0
                    for stat, cost in opt.get("statCosts", {}).items():
                        s -= cost * (5.0 if stat == "hp" else 1.5)
                    for r_card, cost in opt.get("cardCosts", {}).items():
                        s -= cost * 2.0
                    return s

                best_opt = max(options, key=score_opt)
                return best_opt

            shop_e = find("shop_enter")
            if shop_e:
                return shop_e
            leave_e = find("leave_encounter")
            if leave_e:
                return leave_e

        # --- Shop Interaction ---
        if phase == "interaction":
            shop_data = obs.get("shop", {})
            coins = obs.get("coins", 0)

            # 1. Sell corpses for coins
            sell_corpse = find("sell", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "corpse")
            if sell_corpse:
                return sell_corpse

            # 2. Sell surplus cards if short on coins
            sell_other = find("sell", lambda a: hand.get(a["args"].get("uid"), {}).get("id") in ("dismantle", "repair"))
            if sell_other and coins < 4:
                return sell_other

            # 3. Buy essential equipment
            stock = {item["id"] for item in shop_data.get("stock", [])}
            owned = set(devices) | {c["id"] for c in hand.values()}
            for equip_id in ("filter", "lamp", "planter", "crossbow", "shieldRack", "spearRack"):
                if equip_id in stock and equip_id not in owned:
                    buy_act = find("buy", lambda a: a["args"].get("id") == equip_id and a["args"].get("payment") == "coin")
                    if buy_act:
                        return buy_act

            # 4. Buy relics
            relic = find("buy_collectible")
            if relic and coins >= 6:
                return relic

            # 5. Buy resources if coins >= 3
            buy_res = find("buy", lambda a: a["args"].get("payment") == "coin" and a["args"].get("id") in ("plastic", "iron", "wood", "cloth"))
            if buy_res and coins >= 3:
                return buy_res

            return find("shop_leave")

        # --- Combat Tactics ---
        if phase == "battle":
            battle = obs.get("battle", {})
            b_ap = battle.get("ap", 0)
            enemy = obs.get("enemy", {})
            e_hp = battle.get("hp", enemy.get("hp", 0))
            e_dmg = battle.get("enemy_direct_damage", enemy.get("damage", 1))
            shields = sum(s["amount"] for s in battle.get("shields", []))
            turn = battle.get("turn", 1)

            # 1. Free arrows (0 AP)
            arrow_act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "arrow")
            if arrow_act:
                return arrow_act

            # 2. Spear (1 AP)
            spear_act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "spear")
            if spear_act:
                return spear_act

            # 3. Lethal check
            is_feared = battle.get("fear_until", 0) >= turn
            dmg_per_ap = max(1, 1 + p.get("damage", 0) - int(is_feared))
            attacks = find_all("battle_action", lambda a: a["args"].get("action") == "attack")
            def attack_damage(action):
                resource = hand.get(action["args"].get("resource_uid"), {}).get("id")
                bonus = obs.get("battle_combinations", {}).get(resource, {}).get("attack", {}).get("damage", 0)
                return max(1, 1 + p.get("damage", 0) + bonus - int(is_feared))
            best_attack = max(attacks, key=attack_damage) if attacks else None
            bonuses = sorted((max(0, attack_damage(a) - dmg_per_ap) for a in attacks), reverse=True)
            max_damage_possible = int(b_ap) * dmg_per_ap + sum(bonuses[:int(b_ap)])
            if best_attack and (max_damage_possible >= e_hp or (turn >= 7 and e_hp <= 4)):
                return best_attack

            # 4. Cleanse poison
            if battle.get("poison_until", 0) >= turn and counts["cloth"] > 0:
                block_cloth = find("battle_action", lambda a: a["args"].get("action") == "block" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "cloth")
                if block_cloth:
                    return block_cloth

            # 5. Defend incoming damage
            incoming = e_dmg - shields
            if incoming > 0 and b_ap >= 1 and turn < 8:
                if e_dmg >= 2 and counts["rope"] > 0:
                    block_rope = find("battle_action", lambda a: a["args"].get("action") == "block" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "rope")
                    if block_rope:
                        return block_rope

                if counts["wood"] > 0 and incoming >= 2:
                    block_wood = find("battle_action", lambda a: a["args"].get("action") == "block" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "wood")
                    if block_wood:
                        return block_wood

                if counts["iron"] > 0 and incoming >= 2:
                    block_iron = find("battle_action", lambda a: a["args"].get("action") == "block" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "iron")
                    if block_iron:
                        return block_iron

                block_basic = find("battle_action", lambda a: a["args"].get("action") == "block" and not a["args"].get("resource_uid"))
                if block_basic:
                    return block_basic

            # 6. Clear pollution if needed
            if counts["pollution"] > 0 and b_ap >= 1:
                if (shields >= e_dmg or b_ap > 1 or counts["pollution"] >= 2 or p["hp"] > e_dmg + 3) and e_hp > 3 and turn < 8:
                    poll = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "pollution")
                    if poll:
                        return poll

            # 7. Offensive actions
            if counts["wood"] > 0 and b_ap >= 1 and shields < e_dmg:
                atk_wood = find("battle_action", lambda a: a["args"].get("action") == "attack" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "wood")
                if atk_wood:
                    return atk_wood

            if counts["iron"] > 0 and b_ap >= 1:
                atk_iron = find("battle_action", lambda a: a["args"].get("action") == "attack" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "iron")
                if atk_iron:
                    return atk_iron

            atk_basic = find("battle_action", lambda a: a["args"].get("action") == "attack" and not a["args"].get("resource_uid"))
            if atk_basic:
                return atk_basic

            # 8. Combat salvage if hand not full
            if b_ap >= 1 and len(obs.get("hand", [])) < p["limit"] and (counts["rope"] < 2 or counts["wood"] < 2):
                salv = find("salvage")
                if salv:
                    return salv

            # End turn
            b_end = find("battle_end")
            if b_end:
                return b_end

        # --- Discard Phase ---
        if phase == "discard":
            for res in ("wood", "rope", "cloth", "plastic", "iron"):
                if counts[res] > 2:
                    disc = find("discard", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == res)
                    if disc:
                        return disc
            disc_tool = find("discard", lambda a: hand.get(a["args"].get("uid"), {}).get("id") in ("dismantle", "repair"))
            if disc_tool:
                return disc_tool
            for res in ("cloth", "rope", "plastic", "wood", "iron"):
                disc = find("discard", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == res)
                if disc:
                    return disc
            return find("discard")

        # Fallback
        non_abandon = [a for a in actions if a["command"] != "abandon"]
        return non_abandon[0] if non_abandon else (actions[0] if actions else None)


def execute_run(game, run_index, difficulty, seed, origin="strong", max_steps=1200):
    player = V03AgentPlayer(run_id=f"Run-{run_index}")
    header = f"============================================================\n" \
             f"  [RUN {run_index}/4] CHALLENGE MODE | Difficulty: {difficulty.upper()} | Seed: {seed} | Origin: {origin}\n" \
             f"============================================================"
    player.log(header)
    
    reset_params = {"seed": seed, "mode": "challenge", "difficulty": difficulty, "origin": origin}
    obs = data(game.request("reset", reset_params))["observation"]
    
    current_voyage = -1
    step_count = 0
    battles_encountered = []
    layer_checkpoints = []
    voyage_history = []
    
    layer_names = ["Ⅰ · 浅海 (Shallows)", "Ⅱ · 公海 (Open Sea)", "Ⅲ · 深渊 (Abyss)"]

    while not obs["terminal"] and step_count < max_steps:
        step_count += 1
        v = obs.get("voyage", 0)
        p = obs["player"]
        phase = obs["phase"]
        hand = {c["uid"]: c for c in obs.get("hand", [])}
        journey = obs.get("journey", {})
        layer_idx = int(journey.get("layer_index", 0))
        layer_voyage = int(journey.get("layer_voyage", v))
        layer_display = layer_names[layer_idx] if layer_idx < len(layer_names) else f"Layer {layer_idx+1}"

        if v != current_voyage:
            current_voyage = v
            env_str = ", ".join(e["id"] for e in obs.get("environments", [])) or "平息 (None)"
            dev_str = ", ".join(f"{c['equipment']['id']}(Lv{c['equipment']['level']})" for c in obs.get("cells", []) if c.get("equipment")) or "无设备"
            
            # Check layer transition milestone
            if not layer_checkpoints or layer_checkpoints[-1]["layer_idx"] != layer_idx:
                cp_msg = f"\n>>> [进入新层级: {layer_display}] 全局航次: {v}/25 | 玩家HP: {p['hp']}/{p['hp_max']} | 木筏格数: {len(obs.get('cells', []))}"
                player.log(cp_msg)
                layer_checkpoints.append({
                    "layer_idx": layer_idx,
                    "layer_name": layer_display,
                    "voyage": v,
                    "hp": p["hp"],
                    "hunger": p["hunger"],
                    "hydration": p["hydration"],
                    "sanity": p["sanity"]
                })

            status_line = f"\n[航次 {v}/25 | {layer_display} 航行 {layer_voyage} | 阶段: {phase}]\n" \
                          f"  状态: HP {p['hp']}/{p['hp_max']} | 饱食 {p['hunger']}/100 | 水分 {p['hydration']}/100 | SAN {p['sanity']}/100 | 金币 {obs.get('coins', 0)} | 筏格 {len(obs.get('cells', []))}\n" \
                          f"  环境: [{env_str}] | 设备: [{dev_str}]\n" \
                          f"  手牌({len(obs.get('hand', []))}): {dict(Counter(c['id'] for c in obs.get('hand', [])))}"
            player.log(status_line)
            voyage_history.append({
                "voyage": v,
                "layer_idx": layer_idx,
                "layer_voyage": layer_voyage,
                "hp": p["hp"],
                "hunger": p["hunger"],
                "hydration": p["hydration"],
                "sanity": p["sanity"],
                "coins": obs.get("coins", 0),
                "cells": len(obs.get("cells", [])),
                "environments": [e["id"] for e in obs.get("environments", [])]
            })

        actions = data(game.request("actions"))["actions"]
        action = player.choose_action(obs, actions)
        if not action:
            player.log(f"  [ERROR] 当前阶段 {phase} 无法获取任何有效行动！")
            break

        cmd = action["command"]
        args = action.get("args", {})

        if cmd == "voyage":
            target_id = args.get("id")
            cand = next((c for c in obs.get("candidates", []) if c["visit_id"] == target_id), {})
            player.log(f"  -> 选择航向目的地: {cand.get('name', target_id)} ({cand.get('kind', 'unknown')})")
        elif cmd in ("craft", "install", "upgrade", "fuel", "repair_cell", "expand", "play", "salvage"):
            played_card = hand.get(args.get("uid"), {}).get("id", "") if cmd == "play" else ""
            player.log(f"  -> 执行运营操作: {cmd} {args} {f'({played_card})' if played_card else ''}")
        elif cmd == "fight":
            m = obs.get("node", {}).get("monster", {})
            m_name = m.get("name", m) if isinstance(m, dict) else str(m)
            player.log(f"  -> 迎战遭遇怪物: {m_name}")
            battles_encountered.append({"voyage": v, "monster": m_name, "layer": layer_idx})
        elif cmd == "battle_action":
            act_name = args.get("action", "")
            res_uid = args.get("resource_uid")
            res_id = hand.get(res_uid, {}).get("id", "") if res_uid else "none"
            b = obs.get("battle", {})
            e = obs.get("enemy", {})
            player.log(f"    [战斗回合 {b.get('turn',1)} | 敌人HP {e.get('hp')} | 玩家AP {b.get('ap')}] 战术动作: {act_name} + 附魔({res_id})")
        elif cmd == "battle_end":
            b = obs.get("battle", {})
            e = obs.get("enemy", {})
            player.log(f"    [战斗回合 {b.get('turn',1)} 结束] -> 敌人即将发起攻击: 伤害 {e.get('damage')}")
        elif cmd == "buy":
            player.log(f"  -> 商店购买: {args.get('id')} 支付: {args.get('payment')}")
        elif cmd == "sell":
            sold_card = next((c['id'] for c in obs.get('hand', []) if c['uid'] == args.get('uid')), 'item')
            player.log(f"  -> 商店出售: {sold_card}")

        resp = data(game.request("act", {"action_id": action["action_id"], "revision": obs["revision"]}))
        obs = resp["observation"]

    result = data(game.request("result"))
    trace = data(game.request("trace"))

    final_p = obs.get("player", {})
    outcome = result.get("outcome", "unknown")
    completed = result.get("completed", 0)

    player.log("\n============================================================")
    player.log(f"  [RUN {run_index} 终局结果] 状态: {'【通关存活】' if outcome == 'survived' else '【折戟沉没】'}")
    player.log(f"  模式: Challenge | 难度: {difficulty} | 种子: {seed}")
    player.log(f"  结局: {outcome} | 完成航次: {completed}/25 | 终局阶段: {result.get('phase')}")
    player.log(f"  最终玩家属性: 生命 {final_p.get('hp')}/{final_p.get('hp_max')} | 饱食 {final_p.get('hunger')} | 水分 {final_p.get('hydration')} | SAN {final_p.get('sanity')}")
    player.log(f"  总行动步数: {step_count} | 轨迹记录步数: {len(trace['steps'])}")
    player.log(f"  遭遇战斗列表: {[b['monster'] for b in battles_encountered]}")
    player.log("============================================================\n")

    return {
        "run_index": run_index,
        "difficulty": difficulty,
        "seed": seed,
        "origin": origin,
        "outcome": outcome,
        "phase": result.get("phase"),
        "completed": completed,
        "steps": step_count,
        "trace_len": len(trace["steps"]),
        "final_stats": final_p,
        "cells_count": len(obs.get("cells", [])),
        "battles": battles_encountered,
        "layer_checkpoints": layer_checkpoints,
        "voyage_history": voyage_history,
        "report": result.get("report", {}),
        "log_text": "\n".join(player.log_entries)
    }


def main():
    runs_spec = [
        {"run_index": 1, "difficulty": "standard", "seed": 42},
        {"run_index": 2, "difficulty": "standard", "seed": 1024},
        {"run_index": 3, "difficulty": "hard",     "seed": 42},
        {"run_index": 4, "difficulty": "hard",     "seed": 1024},
    ]

    out_dir = ROOT / "evidence" / "v03-agent-play-runs"
    out_dir.mkdir(parents=True, exist_ok=True)

    print("================================================================")
    print("  Deep Surge 0.3 Agent 挑战模式四联试玩流程启动")
    print("  模式: 挑战模式 (3层 25航次架构)")
    print("  难度: Standard (基准难度) & Hard (高压难度)")
    print("  种子: 42 & 1024")
    print("================================================================\n")

    all_results = []

    with AgentClient() as game:
        for spec in runs_spec:
            run_res = execute_run(
                game,
                run_index=spec["run_index"],
                difficulty=spec["difficulty"],
                seed=spec["seed"],
                origin="strong"
            )
            all_results.append(run_res)
            
            # Save individual run log & summary
            run_file = out_dir / f"run-{spec['run_index']}-{spec['difficulty']}-seed{spec['seed']}.json"
            summary_data = {k: v for k, v in run_res.items() if k != "log_text"}
            with open(run_file, "w", encoding="utf-8") as f:
                json.dump(summary_data, f, ensure_ascii=False, indent=2)

    summary_file = out_dir / "all_4_runs_summary.json"
    with open(summary_file, "w", encoding="utf-8") as f:
        json.dump([
            {
                "run_index": r["run_index"],
                "difficulty": r["difficulty"],
                "seed": r["seed"],
                "outcome": r["outcome"],
                "completed": r["completed"],
                "steps": r["steps"],
                "hp": f"{r['final_stats'].get('hp')}/{r['final_stats'].get('hp_max')}",
                "hunger": r["final_stats"].get("hunger"),
                "hydration": r["final_stats"].get("hydration"),
                "sanity": r["final_stats"].get("sanity"),
                "battles_count": len(r["battles"]),
                "cells": r["cells_count"]
            }
            for r in all_results
        ], f, ensure_ascii=False, indent=2)

    print("\n================ 4 局总体试玩概览 ================")
    for r in all_results:
        status_tag = "✓ 通关成功 (Survived)" if r["outcome"] == "survived" else "✗ 中途沉没 (Died)"
        print(f"Run {r['run_index']}: [{r['difficulty'].upper()} | 种子 {r['seed']}] -> {status_tag} | 完成航次: {r['completed']}/25 | 战斗: {len(r['battles'])}场 | 步数: {r['steps']}")
    print("==================================================\n")


if __name__ == "__main__":
    main()
