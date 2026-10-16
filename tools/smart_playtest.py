"""Intelligent agent playtest runner for Deep Surge Godot V0.2.

Plays through the game using strategic reasoning across Standard, Hard, and Nightmare difficulties.
Logs turn-by-turn state, decisions, combat rounds, survival stats, and final outcomes.
"""
import json
from pathlib import Path
import sys
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from agent_client import AgentClient, data


class SmartPlayer:
    def __init__(self, verbose=True):
        self.verbose = verbose
        self.log_entries = []

    def log(self, msg):
        if self.verbose:
            print(msg, flush=True)
        self.log_entries.append(msg)

    def choose_action(self, obs, actions):
        p = obs["player"]
        phase = obs["phase"]
        hand = {c["uid"]: c for c in obs["hand"]}
        counts = Counter(c["id"] for c in obs["hand"])
        cells = obs["cells"]
        devices = {c["equipment"].get("id"): c["equipment"] for c in cells if c["status"] == "intact" and c["equipment"]}
        damaged_cells = [c for c in cells if c["status"] == "damaged"]
        empty_cells = [c for c in cells if c["status"] == "intact" and not c["equipment"]]

        def find(cmd, pred=lambda a: True):
            return next((a for a in actions if a["command"] == cmd and pred(a)), None)

        def find_all(cmd, pred=lambda a: True):
            return [a for a in actions if a["command"] == cmd and pred(a)]

        # --- Survival item usage (Navigation, Preparation, Aftermath, Battle) ---
        # Don't waste food/water if near full. Use when deficit >= 35 (food/water restore 40).
        # Use medkit if hp deficit >= 3 or hp <= 4.
        if phase in ("navigation", "preparation", "aftermath", "battle"):
            # Check medkit
            if p["hp_max"] - p["hp"] >= 3 or p["hp"] <= 4:
                act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "medkit" and a["effective"])
                if act:
                    return act
            # Check water
            if p["hydration_max"] - p["hydration"] >= 35 or (p["hydration"] <= 15 and phase != "battle"):
                act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "water" and a["effective"])
                if act:
                    return act
            # Check food
            if p["hunger_max"] - p["hunger"] >= 35 or (p["hunger"] <= 15 and phase != "battle"):
                act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "food" and a["effective"])
                if act:
                    return act
            # Check calm (sanity)
            if p["sanity_max"] - p["sanity"] >= 20:
                act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "calm" and a["effective"])
                if act:
                    return act

        # --- Base Operations (Preparation, Aftermath, Navigation) ---
        if phase in ("navigation", "preparation", "aftermath"):
            # Tutorial operation (Story mode Voyage 2/3)
            tut = obs.get("tutorial_operation")
            if tut:
                tut_act = find(tut, lambda a: tut != "craft" or a["args"].get("id") == "filter")
                if tut_act:
                    return tut_act

            # 1. Claim generator boosts if ready
            claim = find("claim_boost")
            if claim:
                return claim

            # 2. Repair damaged cells before they detach!
            if damaged_cells:
                # Prefer wood repair, then rope
                rep = find("repair_cell", lambda a: a["args"].get("material") == "wood") or find("repair_cell")
                if rep:
                    return rep

            # 3. Fuel lamp if low fuel (< 2)
            lamp = devices.get("lamp")
            if lamp and lamp.get("fuel", 0) < 2:
                # Prefer corpse (3 fuel), then wood (2 fuel)
                fuel_act = find("fuel", lambda a: a["args"].get("material") == "corpse")
                if not fuel_act and counts["wood"] >= 1:
                    fuel_act = find("fuel", lambda a: a["args"].get("material") == "wood")
                if fuel_act:
                    return fuel_act

            # 4. Install crafted equipment from hand into empty cell
            if empty_cells:
                # Priority: lamp > filter > planter > crossbow > fishingNet > shieldRack > spearRack > crate
                install_prio = ["lamp", "filter", "planter", "crossbow", "fishingNet", "shieldRack", "spearRack", "crate"]
                for dev_id in install_prio:
                    inst = find("install", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == dev_id)
                    if inst:
                        return inst

            # 5. Craft core devices if empty cell available
            if empty_cells and obs["ap"] >= 1:
                # 5a. First craft 1 of each essential device
                if p["hydration"] <= 35 or p["hunger"] <= 35:
                    craft_prio = ["filter", "planter", "lamp", "crossbow", "fishingNet", "shieldRack"]
                else:
                    craft_prio = ["lamp", "filter", "planter", "crossbow", "fishingNet", "shieldRack"]
                for dev_id in craft_prio:
                    if dev_id not in devices and not any(c["id"] == dev_id for c in hand.values()):
                        craft = find("craft", lambda a: a["args"].get("id") == dev_id)
                        if craft:
                            return craft
                
                # 5b. If all essential devices are owned, craft secondary combat/utility devices for extra cells
                dev_counts = Counter(c["equipment"]["id"] for c in cells if c.get("equipment"))
                hand_counts = Counter(c["id"] for c in hand.values())
                secondary_prio = ["crossbow", "fishingNet", "shieldRack", "crate"]
                for dev_id in secondary_prio:
                    max_target = 2 if dev_id in ("crossbow", "fishingNet", "shieldRack") else 1
                    if dev_counts[dev_id] + hand_counts[dev_id] < max_target:
                        craft = find("craft", lambda a: a["args"].get("id") == dev_id)
                        if craft:
                            return craft

            # 6. Upgrade production equipment (filter/planter) to Lv 2
            if obs["ap"] >= 1:
                for target_dev in ("filter", "planter"):
                    if target_dev in devices and devices[target_dev].get("level", 1) < 2:
                        upg = find("upgrade", lambda a: any(c["id"] == a["args"].get("cell") and c["equipment"].get("id") == target_dev for c in cells))
                        if upg:
                            return upg

            # 7. Pre-craft medkits whenever we have cloth and wood to prepare for battles!
            # Having 1-3 medkits in hand gives +3 to +9 emergency HP in combat.
            if counts["cloth"] >= 2 and counts["wood"] >= 1 and counts["medkit"] < 3 and obs["ap"] >= 1:
                craft_med = find("craft", lambda a: a["args"].get("id") == "medkit")
                if craft_med:
                    return craft_med

            # 8. Expand raft if wood >= 2 and AP available and no empty cells
            if counts["wood"] >= 2 and obs["ap"] >= 1 and len(empty_cells) == 0:
                exp = find("expand")
                if exp:
                    return exp

            # 9. Navigation-specific decisions
            if phase == "navigation":
                # Check drift / heading fix
                nav = obs.get("navigation", {})
                if nav.get("wrong_direction_chance", 0) > 0 and not nav.get("heading_locked", False):
                    fix = find("fix_heading")
                    if fix:
                        return fix

                # Scout hidden candidates if high sanity
                if p["sanity"] > 55:
                    scout_act = find("scout")
                    if scout_act:
                        return scout_act

                # Score candidates
                def score_node(cand):
                    cid = cand.get("id", "")
                    kind = cand.get("kind", "")
                    val = 20
                    if cand.get("boss"):
                        return 1000  # unavoidable final boss
                    if cid == "camp":
                        return 100
                    if kind == "shop":
                        # If we have coins or corpses, shop is great
                        return 80 if (obs.get("coins", 0) >= 3 or counts["corpse"] >= 1) else 35
                    if kind == "supply":
                        return 60
                    if cid in ("provision", "sharedMeal"):
                        return 65
                    if kind == "rest":
                        return 75
                    if kind == "exchange":
                        return 40
                    if cand.get("monster") or kind == "battle":
                        if p["hp"] >= 10 and ("crossbow" in devices or counts["arrow"] >= 2):
                            return 45  # Good for bounty/corpse/coin
                        else:
                            return 10  # Risky
                    if cand.get("risk"):
                        return 15
                    return val

                best_cand = max(obs["candidates"], key=score_node)
                voyage_act = find("voyage", lambda a: a["args"].get("id") == best_cand["visit_id"])
                if voyage_act:
                    return voyage_act
                fallback_v = find("voyage")
                if fallback_v:
                    return fallback_v

            # 10. Aftermath / Preparation fallback
            # If in aftermath with spare AP and capacity, salvage!
            if phase == "aftermath" and obs["ap"] > 0 and len(obs["hand"]) < p["limit"]:
                salv = find("salvage")
                if salv:
                    return salv

            # Advance phase
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

            # Boss combat is mandatory
            if obs.get("node", {}).get("boss"):
                fight = find("fight")
                if fight:
                    return fight

            # Monster encounter
            if obs.get("node", {}).get("monster"):
                # If healthy and prepared, fight for rewards; otherwise leave
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

            scene = obs.get("scene", {})
            if scene.get("id") == "ST.L1.S04":
                route_opt = find("option", lambda a: a["args"].get("id") == "companion") or find("option")
                if route_opt:
                    return route_opt
            if scene.get("id") == "ST.L1.F15":
                finale_opt = find("option", lambda a: a["args"].get("id") in ("seal", "tow", "release")) or find("option")
                if finale_opt:
                    return finale_opt
            skip_act = find("skip")
            if skip_act:
                return skip_act

            # Event choices
            options = find_all("option")
            if options:
                # Score options
                opts_map = {x["id"]: x for x in obs.get("event_options", [])}
                def score_opt(a):
                    opt = opts_map.get(a["args"].get("id"), {})
                    prev = opt.get("preview", {})
                    s = 0.0
                    # Stat gains
                    for stat, delta in prev.get("attributes", {}).items():
                        cur = p.get(stat, 0)
                        max_val = p.get(stat + "_max", 100)
                        effective_gain = min(max_val - cur, max(0, delta))
                        s += effective_gain * (3.0 if stat == "hp" else 1.0)
                    # Resource cards
                    for r_card, amt in prev.get("cards", {}).items():
                        s += amt * 2.0
                    if prev.get("rested"):
                        s += 5.0
                    if prev.get("repair"):
                        s += 8.0
                    if prev.get("random_resources", 0):
                        s += prev["random_resources"] * 2.0
                    # Costs
                    if opt.get("cost", 0):
                        s -= opt["cost"] * 2.0
                    for stat, cost in opt.get("statCosts", {}).items():
                        s -= cost * (4.0 if stat == "hp" else 1.2)
                    for r_card, cost in opt.get("cardCosts", {}).items():
                        s -= cost * 2.0
                    if opt.get("risk"):
                        s -= 10.0
                    if opt.get("battle"):
                        s -= 15.0
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

            # 1. Sell corpses first for 2 coins each!
            sell_corpse = find("sell", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "corpse")
            if sell_corpse:
                return sell_corpse

            # 2. Sell duplicate non-material cards if we need coins
            sell_other = find("sell", lambda a: hand.get(a["args"].get("uid"), {}).get("id") in ("dismantle", "repair"))
            if sell_other and coins < 4:
                return sell_other

            # 3. Buy equipment if affordable
            stock = shop_data.get("stock", [])
            for equip_id in ("filter", "lamp", "planter", "crossbow", "shieldRack", "spearRack"):
                if equip_id in stock and equip_id not in devices:
                    buy_act = (find("buy", lambda a: a["args"].get("id") == equip_id and a["args"].get("payment") == "coin") or
                               find("buy", lambda a: a["args"].get("id") == equip_id and a["args"].get("payment") == "corpse"))
                    if buy_act:
                        return buy_act

            # 4. Buy cheap materials if price is 1 coin and we have coins
            buy_res = find("buy", lambda a: a["args"].get("payment") == "coin" and a["args"].get("id") in ("plastic", "iron", "wood"))
            if buy_res and coins >= 3:
                return buy_res

            # Leave shop
            return find("shop_leave")

        # --- Combat Tactics ---
        if phase == "battle":
            battle = obs.get("battle", {})
            b_ap = battle.get("ap", 0)
            enemy = obs.get("enemy", {})
            e_hp = enemy.get("hp", 0)
            e_dmg = enemy.get("damage", 1)
            b_hp = battle.get("hp", p["hp"])
            shields = sum(s["amount"] for s in battle.get("shields", []))
            turn = battle.get("turn", 1)

            # 1. Play Arrows (0 AP, 2 dmg)! Free damage!
            arrow_act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "arrow")
            if arrow_act:
                return arrow_act

            # 2. Play Spear (1 AP, 3 or 5 dmg)!
            spear_act = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "spear")
            if spear_act:
                return spear_act

            # 3. Check for Lethal on Enemy:
            # Under fear, attack damage is reduced by 1 (min 1), so basic attack is 1, iron attack is 1!
            is_feared = battle.get("fear_until", 0) >= turn
            dmg_per_ap = 1 if is_feared else 2
            max_damage_possible = b_ap * dmg_per_ap
            if max_damage_possible >= e_hp or (turn >= 7 and e_hp <= 4):
                # Attack to finish!
                atk_iron = find("battle_action", lambda a: a["args"].get("action") == "attack" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "iron")
                if atk_iron:
                    return atk_iron
                atk_basic = find("battle_action", lambda a: a["args"].get("action") == "attack" and not a["args"].get("resource_uid"))
                if atk_basic:
                    return atk_basic

            # 4. Cleanse poison if poisoned and have cloth
            if battle.get("poison_until", 0) >= turn and counts["cloth"] > 0:
                block_cloth = find("battle_action", lambda a: a["args"].get("action") == "block" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "cloth")
                if block_cloth:
                    return block_cloth

            # 5. Defense against incoming damage:
            # If incoming damage exceeds current shield, prioritize blocking before burning AP on pollution!
            incoming = e_dmg - shields
            if incoming > 0 and b_ap >= 1 and turn < 8:
                # Special: against Boss or heavy hitters (dmg >= 2), Rope block reduces damage by 2 AND gives 1 shield!
                if e_dmg >= 2 and counts["rope"] > 0:
                    block_rope = find("battle_action", lambda a: a["args"].get("action") == "block" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "rope")
                    if block_rope:
                        return block_rope

                # Wood block: 3 shields!
                if counts["wood"] > 0 and incoming >= 2:
                    block_wood = find("battle_action", lambda a: a["args"].get("action") == "block" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "wood")
                    if block_wood:
                        return block_wood

                # Scrap block: 2 shields + 1 counterattack
                if counts["iron"] > 0 and incoming >= 2:
                    block_iron = find("battle_action", lambda a: a["args"].get("action") == "block" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "iron")
                    if block_iron:
                        return block_iron

                # Basic block: 1 shield for 1 AP whenever incoming > 0 and we cannot block with resources
                if (b_hp <= 6 or e_dmg >= 2 or counts["pollution"] == 0 or b_ap == 1) and turn < 8:
                    block_basic = find("battle_action", lambda a: a["args"].get("action") == "block" and not a["args"].get("resource_uid"))
                    if block_basic:
                        return block_basic

            # 6. Clear pollution if Boss combat and hand has pollution and b_ap >= 2
            # Only clear pollution if incoming damage is already blocked or we have sufficient shields/HP
            if counts["pollution"] > 0 and b_ap >= 2:
                if (shields >= e_dmg or b_ap > 2 or counts["pollution"] >= 2 or b_hp > e_dmg + 3) and e_hp > 3 and turn < 8:
                    poll = find("play", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == "pollution")
                    if poll:
                        return poll

            # 6.5. In-combat Salvage when out of defensive materials:
            if incoming > 0 and b_ap >= 2 and counts["rope"] == 0 and counts["wood"] == 0 and counts["iron"] == 0:
                salv = find("salvage")
                if salv:
                    return salv

            # 7. Offensive actions with remaining AP:
            # Wood attack: deals 1 damage + grants 1 shield! Excellent hybrid action.
            if counts["wood"] > 0 and b_ap >= 1 and shields < e_dmg:
                atk_wood = find("battle_action", lambda a: a["args"].get("action") == "attack" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "wood")
                if atk_wood:
                    return atk_wood

            # Iron attack: deals 2 damage!
            if counts["iron"] > 0 and b_ap >= 1:
                atk_iron = find("battle_action", lambda a: a["args"].get("action") == "attack" and hand.get(a["args"].get("resource_uid"), {}).get("id") == "iron")
                if atk_iron:
                    return atk_iron

            # Basic attack: 1 damage
            atk_basic = find("battle_action", lambda a: a["args"].get("action") == "attack" and not a["args"].get("resource_uid"))
            if atk_basic:
                return atk_basic

            # 8. Salvage with spare combat AP if hand not full:
            if b_ap >= 1 and len(obs["hand"]) < p["limit"] and (counts["rope"] < 2 or counts["wood"] < 2):
                salv = find("salvage")
                if salv:
                    return salv

            # End battle turn
            b_end = find("battle_end")
            if b_end:
                return b_end

        # --- Discard Phase ---
        if phase == "discard":
            # Discard priority:
            # 1. Discard excess basic resources (if we have > 2 of that resource)
            for res in ("wood", "rope", "cloth", "plastic", "iron"):
                if counts[res] > 2:
                    disc = find("discard", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == res)
                    if disc:
                        return disc
            # 2. Discard unneeded craft tools if any
            disc_tool = find("discard", lambda a: hand.get(a["args"].get("uid"), {}).get("id") in ("dismantle", "repair"))
            if disc_tool:
                return disc_tool
            # 3. Discard any basic resource
            for res in ("cloth", "rope", "plastic", "wood", "iron"):
                disc = find("discard", lambda a: hand.get(a["args"].get("uid"), {}).get("id") == res)
                if disc:
                    return disc
            # Fallback discard
            return find("discard")

        # --- Story Mode Night Hub ---
        if phase == "nightHub":
            # Submit quest if possible
            sub = find("submit_quest")
            if sub:
                return sub
            # Accept quest
            acq = find("accept_quest")
            if acq:
                return acq
            # Night action: Rest (hp +3, food +50, water +50, SAN +35)
            rest = find("night_action", lambda a: a["args"].get("id") == "rest")
            if rest:
                return rest
            ack = find("night_ack") or find("night_actions") or find("finish_night")
            if ack:
                return ack

        # Default fallback (never abandon unless it's the only action)
        non_abandon = [a for a in actions if a["command"] != "abandon"]
        return non_abandon[0] if non_abandon else (actions[0] if actions else None)


def play_run(game, difficulty="standard", seed=22, mode="challenge", raft_4x4=False, max_steps=800, verbose=True):
    player = SmartPlayer(verbose=verbose)
    player.log(f"=== Starting Run: Mode={mode}, Difficulty={difficulty}, Seed={seed}, Raft4x4={raft_4x4} ===")
    
    reset_params = {"seed": seed, "mode": mode, "difficulty": difficulty, "origin": "strong"}
    if raft_4x4:
        reset_params["purchases"] = {"raft": 1}
    obs = data(game.request("reset", reset_params))["observation"]
    
    current_voyage = -1
    step_count = 0
    battles_encountered = []
    
    while not obs["terminal"] and step_count < max_steps:
        step_count += 1
        v = obs.get("voyage", 0)
        p = obs["player"]
        phase = obs["phase"]
        hand = {c["uid"]: c for c in obs.get("hand", [])}
        
        if v != current_voyage:
            current_voyage = v
            env_str = ", ".join(e["id"] for e in obs.get("environments", [])) or "None"
            dev_str = ", ".join(f"{c['equipment']['id']}(Lv{c['equipment']['level']})" for c in obs["cells"] if c["equipment"]) or "None"
            player.log(f"\n[Voyage {v} | Phase: {phase}] HP: {p['hp']}/{p['hp_max']} | Hunger: {p['hunger']}/100 | Water: {p['hydration']}/100 | SAN: {p['sanity']}/100 | Coins: {obs.get('coins', 0)} | Cells: {len(obs['cells'])}")
            player.log(f"  Environments: [{env_str}] | Devices: [{dev_str}] | Hand ({len(obs['hand'])}): {Counter(c['id'] for c in obs['hand'])}")

        actions = data(game.request("actions"))["actions"]
        action = player.choose_action(obs, actions)
        if not action:
            player.log(f"ERROR: No action available at phase {phase}!")
            break
            
        cmd = action["command"]
        args = action.get("args", {})
        
        # Log notable actions
        if cmd in ("craft", "install", "upgrade", "fuel", "repair_cell", "expand", "scout", "fix_heading", "play", "salvage"):
            played_card = hand.get(args.get("uid"), {}).get("id", "") if cmd == "play" else ""
            b_tag = f" [Turn {obs.get('battle',{}).get('turn',1)} Combat Salvage]" if phase == 'battle' and cmd == 'salvage' else ""
            player.log(f"  -> Action: {cmd} {args} {f'({played_card})' if played_card else ''}{b_tag}")
        elif cmd == "voyage":
            target_id = args.get("id")
            cand = next((c for c in obs.get("candidates", []) if c["visit_id"] == target_id), {})
            player.log(f"  -> Voyage to: {cand.get('name', target_id)} ({cand.get('kind', 'unknown')})")
        elif cmd == "fight":
            m = obs.get("node", {}).get("monster", {})
            m_name = m.get("name", m) if isinstance(m, dict) else str(m)
            player.log(f"  -> Engaged Fight: {m_name}")
            battles_encountered.append(m_name)
        elif cmd == "battle_action":
            act_name = args.get("action", "")
            res_uid = args.get("resource_uid")
            res_id = hand.get(res_uid, {}).get("id", "") if res_uid else "none"
            b = obs.get("battle", {})
            e = obs.get("enemy", {})
            player.log(f"    [Turn {b.get('turn',1)} | Enemy HP: {e.get('hp')} | AP: {b.get('ap')}] Battle Action: {act_name} + {res_id}")
        elif cmd == "battle_end":
            b = obs.get("battle", {})
            e = obs.get("enemy", {})
            player.log(f"    [Turn {b.get('turn',1)}] End Turn -> Enemy incoming dmg: {e.get('damage')}")
        elif cmd == "buy":
            player.log(f"  -> Shop Buy: {args.get('id')} with {args.get('payment')}")
        elif cmd == "sell":
            sold_card = next((c['id'] for c in obs['hand'] if c['uid'] == args.get('uid')), 'item')
            player.log(f"  -> Shop Sell: {sold_card}")
            
        resp = data(game.request("act", {"action_id": action["action_id"], "revision": obs["revision"]}))
        obs = resp["observation"]
        
    result = data(game.request("result"))
    trace = data(game.request("trace"))
    
    player.log(f"\n=== Run Finished ===")
    player.log(f"Terminal: {obs['terminal']} | Outcome: {result.get('outcome')} | Phase: {result.get('phase')} | Completed: {result.get('completed')}")
    final_p = obs.get("player", {})
    player.log(f"Final Stats: HP: {final_p.get('hp')}/{final_p.get('hp_max')} | Hunger: {final_p.get('hunger')} | Water: {final_p.get('hydration')} | SAN: {final_p.get('sanity')}")
    player.log(f"Total Steps: {step_count} | Trace Steps: {len(trace['steps'])}")
    player.log(f"Battles Encountered: {battles_encountered}")
    
    return {
        "difficulty": difficulty,
        "mode": mode,
        "seed": seed,
        "raft_4x4": raft_4x4,
        "outcome": result.get("outcome"),
        "phase": result.get("phase"),
        "completed": result.get("completed"),
        "cells_count": len(obs.get("cells", [])),
        "final_stats": final_p,
        "steps": step_count,
        "battles": battles_encountered,
        "report": result.get("report", {}),
        "trace_len": len(trace["steps"])
    }


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--difficulty", default="standard", choices=("standard", "hard", "nightmare"))
    parser.add_argument("--seed", type=int, default=22)
    parser.add_argument("--mode", default="challenge", choices=("challenge", "story"))
    parser.add_argument("--raft-4x4", action="store_true", default=False, help="Allow raft expansion up to 4x4")
    args = parser.parse_args()
    
    with AgentClient() as game:
        res = play_run(game, difficulty=args.difficulty, seed=args.seed, mode=args.mode, raft_4x4=args.raft_4x4)
        print("\nSummary JSON:")
        print(json.dumps({k: v for k, v in res.items() if k != "report"}, ensure_ascii=False, indent=2))
