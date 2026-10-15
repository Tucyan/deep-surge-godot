"""Monte Carlo Balance Simulation for Deep Surge Encounter Node Restructuring.
Quantitatively simulates interactions across:
1. Cards (hand limit with crate +3/+6, spring supply, consumption, craft)
2. Raft (cell damage, aging, detachment, wood maintenance)
3. Combat (enemy HP, player HP, equipment weapons, incoming damage)
4. Nodes (legacy pool vs Arknights "不期而遇" Restructured Encounter pool with balanced survival integration)
"""
import random
from collections import Counter

RESOURCES = ["wood", "iron", "plastic", "rope", "cloth"]
ENEMIES = {
    "biter": {"hp": 6, "atk": 2, "bites_raft": True},
    "jelly": {"hp": 7, "atk": 1, "poison": 1},
    "crab": {"hp": 9, "atk": 3, "bites_raft": False},
    "sentinel": {"hp": 11, "atk": 3, "fear": True},
    "boss": {"hp": 18, "atk": 3, "pollution": True}
}

class RunSimulator:
    def __init__(self, mode="legacy", seed=None):
        self.mode = mode
        self.rng = random.Random(seed)
        self.hp = 12
        self.hp_max = 12
        self.hunger = 40
        self.hydration = 40
        self.sanity = 80
        self.hand = []
        self.cells = [{"id": f"cell-{i}", "status": "intact", "damaged_at": 0, "equipment": None, "level": 1} for i in range(4)]
        self.coins = 0
        self.corpses = 0
        self.voyage = 1
        self.length = 12
        self.alive = True
        self.death_reason = None
        self.detached_cells = 0
        self.battles_won = 0
        self.battles_entered = 0
        self.discards_count = 0
        self.wood_deficit_events = 0
        self.avoid_wave = False
        self.rested_until = 0
        
        # Initial starting resources (7 random)
        for _ in range(7):
            self.hand.append(self.rng.choice(RESOURCES))

    def hand_limit(self):
        limit = 10
        for c in self.cells:
            if c["status"] == "intact" and c["equipment"] == "crate":
                if self.mode == "legacy":
                    limit += c["level"] # 1, 2, 3
                else: # new crate values: +3 for lv1, +6 for lv2, +9 for lv3
                    limit += 3 * c["level"]
        return limit

    def run(self):
        while self.voyage <= self.length and self.alive:
            self.step_voyage()
            if not self.alive:
                break
            self.voyage += 1
        return {
            "survived": self.alive,
            "death_reason": self.death_reason,
            "hp": self.hp,
            "hunger": self.hunger,
            "hydration": self.hydration,
            "sanity": self.sanity,
            "detached_cells": self.detached_cells,
            "battles_won": self.battles_won,
            "discards": self.discards_count,
            "wood_deficits": self.wood_deficit_events
        }

    def step_voyage(self):
        # 1. Spring supply (1 wood + 3 random) if voyage > 1
        if self.voyage > 1:
            self.hand.append("wood")
            for _ in range(3):
                self.hand.append(self.rng.choice(RESOURCES))
        
        # 2. Movement drain:
        # Default -30 hunger, -30 thirst (reduced by 15 if avoid_wave, or 5 if base avoidWave)
        reduction = 15 if self.avoid_wave else 0
        self.avoid_wave = False
        drain_hunger = max(0, 30 - reduction)
        drain_hydration = max(0, 30 - reduction)
        
        # Lamp mitigation if lamp intact with fuel
        lamp_active = any(c["status"] == "intact" and c["equipment"] == "lamp" for c in self.cells)
        if lamp_active and ("wood" in self.hand or self.corpses > 0):
            # burn fuel
            if self.corpses > 0:
                self.corpses -= 1
            else:
                self.hand.remove("wood")
            self.sanity = min(100, self.sanity - 15 + 15)
        else:
            self.sanity = max(0, self.sanity - 15)
        
        self.hunger = max(0, self.hunger - drain_hunger)
        self.hydration = max(0, self.hydration - drain_hydration)
        
        # Deprivation damage
        deprivation = 0
        if self.hunger == 0: deprivation += 1
        if self.hydration == 0: deprivation += 1
        if deprivation > 0:
            self.hp -= min(2, deprivation)
            if self.hp <= 0:
                self.alive = False
                self.death_reason = "deprivation"
                return

        # 3. Node Selection and Resolution
        node_kind = self.pick_node()
        self.resolve_node(node_kind)
        if not self.alive:
            return

        # 4. Preparation & Crafting logic
        self.ai_craft_and_maintain()

        # 5. Cell Aging and Detachment
        for c in self.cells:
            if c["status"] == "damaged" and self.voyage - c["damaged_at"] >= 2:
                c["status"] = "detached"
                c["equipment"] = None
                self.detached_cells += 1

        # 6. Discard Phase with dynamic hand limit
        limit = self.hand_limit()
        if len(self.hand) > limit:
            excess = len(self.hand) - limit
            self.discards_count += excess
            # Discard non-wood/non-cloth first
            for _ in range(excess):
                candidates = [c for c in self.hand if c not in ["wood", "cloth"]]
                discard_target = candidates[0] if candidates else self.hand[0]
                self.hand.remove(discard_target)

    def pick_node(self):
        if self.mode == "legacy":
            weights = {
                "drift": 25,
                "camp": 15,
                "trader": 10,
                "jelly": 10,
                "storm": 15,
                "battle": 25
            }
        else: # "encounter_restructured"
            weights = {
                "drift": 10,
                "camp": 10,
                "trader": 8,
                "enc_salvage": 15,       # 不期而遇：浮木与遗骸 (Provisions / Burial)
                "enc_cursed_box": 14,     # 不期而遇：深渊死箱 (Feed corpse / Blood unlock)
                "enc_phantom_trader": 12, # 不期而遇：迷途幽灵船 (Trade for supplies/medkits)
                "enc_pit_fight": 11,      # 不期而遇：潮穴搏杀 (Meat + Tactical boost)
                "enc_beast_cub": 12,      # 不期而遇：海兽幼崽 (Symbiosis nourishment)
                "storm": 6,
                "battle": 12
            }
        kinds = list(weights.keys())
        w_values = list(weights.values())
        return self.rng.choices(kinds, weights=w_values, k=1)[0]

    def resolve_node(self, kind):
        if kind == "drift":
            self.hand.append("wood")
            self.hand.append(self.rng.choice(RESOURCES))
            if self.hunger < 40: self.hunger = min(100, self.hunger + 40)
            if self.hydration < 40: self.hydration = min(100, self.hydration + 40)
        elif kind == "camp":
            self.hp = min(self.hp_max, self.hp + 6)
            self.hunger = min(100, self.hunger + 40)
            self.hydration = min(100, self.hydration + 40)
            self.sanity = min(100, self.sanity + 40)
        elif kind == "trader":
            self.coins += 2
        elif kind == "storm":
            if self.rng.random() < 0.4:
                intact = [c for c in self.cells if c["status"] == "intact"]
                if intact:
                    hit = self.rng.choice(intact)
                    hit["status"] = "damaged"
                    hit["damaged_at"] = self.voyage
            self.hand.append("iron")
        
        # --- 不期而遇 (Encounters) ---
        elif kind == "enc_salvage": # 浮木与遗骸
            # Smart choice: prioritize food/water if low
            if self.hunger < 50 or self.hydration < 50:
                self.hand.append("wood")
                self.hunger = min(100, self.hunger + 40)
                self.hydration = min(100, self.hydration + 40)
            elif self.sanity < 50 and "cloth" in self.hand:
                self.hand.remove("cloth")
                self.sanity = min(100, self.sanity + 30)
                self.avoid_wave = True
            else:
                self.hand.append("wood")
                self.hand.append(self.rng.choice(RESOURCES))
        
        elif kind == "enc_cursed_box": # 深渊死箱
            if self.corpses > 0:
                # Feed corpse -> gain sealed provisions (Food 50, Water 50)
                self.corpses -= 1
                self.hunger = min(100, self.hunger + 50)
                self.hydration = min(100, self.hydration + 50)
            elif self.hp > 8:
                # Blood unlock: sacrifice 2 HP for 2 iron + 1 water + 1 food
                self.hp -= 2
                self.hand.append("iron")
                self.hydration = min(100, self.hydration + 40)
                self.hunger = min(100, self.hunger + 40)
            else:
                # Pry with crowbar (70% iron+coins+food, 30% cell damage)
                if self.rng.random() < 0.7:
                    self.hand.append("iron")
                    self.coins += 2
                    self.hunger = min(100, self.hunger + 30)
                else:
                    intact = [c for c in self.cells if c["status"] == "intact"]
                    if intact:
                        hit = self.rng.choice(intact)
                        hit["status"] = "damaged"
                        hit["damaged_at"] = self.voyage
        
        elif kind == "enc_phantom_trader": # 迷途幽灵船
            if self.hand.count("plastic") >= 2:
                self.hand.remove("plastic")
                self.hand.remove("plastic")
                self.hand.append("medkit")
                self.hydration = min(100, self.hydration + 40)
            else:
                self.sanity = min(100, self.sanity + 20)
                self.hydration = min(100, self.hydration + 30)
                self.coins += 1
        
        elif kind == "enc_pit_fight": # 潮穴搏杀
            if self.hp > 7:
                self.hp -= 3 # Take 3 HP damage
                self.coins += 3
                self.corpses += 1
                # Sea beast meat feeds the player!
                self.hunger = min(100, self.hunger + 50)
                self.hydration = min(100, self.hydration + 30)
                self.hand.append("tactical_boost")
            else:
                self.hand.append("plastic")
                self.hunger = min(100, self.hunger + 20)
        
        elif kind == "enc_beast_cub": # 海兽幼崽
            if "cloth" in self.hand:
                self.hand.remove("cloth")
                self.coins += 2
                self.avoid_wave = True
                self.hydration = min(100, self.hydration + 40)
            else:
                # Tender interaction gives peace and finds foraging seaweed
                self.sanity = min(100, self.sanity + 25)
                self.hunger = min(100, self.hunger + 30)
                self.hydration = min(100, self.hydration + 30)
        
        elif kind == "battle":
            self.resolve_combat()

    def resolve_combat(self):
        self.battles_entered += 1
        enemy_id = self.rng.choice(["biter", "jelly", "crab", "sentinel"])
        enemy = ENEMIES[enemy_id]
        enemy_hp = enemy["hp"]
        
        has_crossbow = any(c["status"] == "intact" and c["equipment"] == "crossbow" for c in self.cells)
        has_tactical = "tactical_boost" in self.hand
        if has_tactical:
            self.hand.remove("tactical_boost")
            enemy_hp -= 4 # Tactical boost weakens enemy

        turn = 1
        while enemy_hp > 0 and self.alive:
            # Player heals with medkit if critical
            if self.hp <= 5 and "medkit" in self.hand:
                self.hand.remove("medkit")
                self.hp = min(self.hp_max, self.hp + 5)
            
            # Player attack
            dmg = 3 # 3 punches
            if has_crossbow: dmg += 2
            enemy_hp -= dmg
            if enemy_hp <= 0:
                break
            
            # Enemy attack
            enemy_dmg = enemy["atk"]
            if "wood" in self.hand: # Block combo
                enemy_dmg = max(0, enemy_dmg - 2)
            self.hp -= enemy_dmg
            
            if enemy.get("bites_raft") and self.rng.random() < 0.3:
                intact = [c for c in self.cells if c["status"] == "intact"]
                if intact:
                    hit = self.rng.choice(intact)
                    hit["status"] = "damaged"
                    hit["damaged_at"] = self.voyage

            if self.hp <= 0:
                self.alive = False
                self.death_reason = f"killed_by_{enemy_id}"
                return
            turn += 1

        if self.alive:
            self.battles_won += 1
            self.corpses += 1
            self.coins += 2
            self.hand.append(self.rng.choice(RESOURCES))

    def ai_craft_and_maintain(self):
        # 1. Repair damaged cells first!
        for c in self.cells:
            if c["status"] == "damaged":
                if "wood" in self.hand:
                    self.hand.remove("wood")
                    c["status"] = "intact"
                    c["damaged_at"] = 0
                elif self.hand.count("rope") >= 2:
                    self.hand.remove("rope")
                    self.hand.remove("rope")
                    c["status"] = "intact"
                    c["damaged_at"] = 0
                else:
                    self.wood_deficit_events += 1

        # 2. Craft Crate if wood & rope available to expand hand limit!
        empty_cells = [c for c in self.cells if c["status"] == "intact" and c["equipment"] is None]
        equipped_types = [c["equipment"] for c in self.cells if c["equipment"] is not None]
        
        # Priority in restructured mode: Lamp -> Crate (if materials allow) -> Crossbow
        if empty_cells:
            if "lamp" not in equipped_types and "wood" in self.hand and "iron" in self.hand:
                self.hand.remove("wood"); self.hand.remove("iron")
                empty_cells[0]["equipment"] = "lamp"
            elif self.mode != "legacy" and "crate" not in equipped_types and self.hand.count("wood") >= 2 and "rope" in self.hand:
                self.hand.remove("wood"); self.hand.remove("wood"); self.hand.remove("rope")
                empty_cells[0]["equipment"] = "crate"
                empty_cells[0]["level"] = 1
            elif "crossbow" not in equipped_types and "wood" in self.hand and "iron" in self.hand and "rope" in self.hand:
                self.hand.remove("wood"); self.hand.remove("iron"); self.hand.remove("rope")
                empty_cells[0]["equipment"] = "crossbow"

def run_experiment(mode, n=1000):
    survivals = 0
    deaths = Counter()
    total_detached = 0
    total_battles = 0
    total_battles_won = 0
    total_wood_deficits = 0
    total_discards = 0

    for seed in range(n):
        sim = RunSimulator(mode=mode, seed=seed)
        res = sim.run()
        if res["survived"]:
            survivals += 1
        else:
            deaths[res["death_reason"]] += 1
        total_detached += res["detached_cells"]
        total_battles += sim.battles_entered
        total_battles_won += res["battles_won"]
        total_wood_deficits += res["wood_deficits"]
        total_discards += res["discards"]

    return {
        "mode": mode,
        "n": n,
        "survival_rate": survivals / n,
        "deaths": dict(deaths),
        "avg_detached_cells": total_detached / n,
        "avg_battles": total_battles / n,
        "battle_win_rate": total_battles_won / max(1, total_battles),
        "avg_wood_deficits": total_wood_deficits / n,
        "avg_discards": total_discards / n
    }

if __name__ == "__main__":
    print("=" * 65)
    print("Running 1,000 Monte Carlo Simulations: Legacy vs Encounter-Restructured")
    print("=" * 65)
    legacy = run_experiment("legacy", 1000)
    encounter = run_experiment("encounter_restructured", 1000)
    
    print("\n[LEGACY POOL RESULTS]")
    print(f"  Survival Rate:        {legacy['survival_rate']:.1%}")
    print(f"  Deaths Breakdown:     {legacy['deaths']}")
    print(f"  Avg Detached Cells:   {legacy['avg_detached_cells']:.2f}")
    print(f"  Battle Win Rate:      {legacy['battle_win_rate']:.1%}")
    print(f"  Avg Wood Deficits:    {legacy['avg_wood_deficits']:.2f}")
    print(f"  Avg Discards/Run:     {legacy['avg_discards']:.2f}")

    print("\n[ENCOUNTER-RESTRUCTURED RESULTS (Arknights Encounters + Crate +3/+6)]")
    print(f"  Survival Rate:        {encounter['survival_rate']:.1%}")
    print(f"  Deaths Breakdown:     {encounter['deaths']}")
    print(f"  Avg Detached Cells:   {encounter['avg_detached_cells']:.2f}")
    print(f"  Battle Win Rate:      {encounter['battle_win_rate']:.1%}")
    print(f"  Avg Wood Deficits:    {encounter['avg_wood_deficits']:.2f}")
    print(f"  Avg Discards/Run:     {encounter['avg_discards']:.2f}")
    print("=" * 65)
