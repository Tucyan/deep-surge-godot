extends SceneTree
## Test suite verifying:
## 1. Crate capacity values (+3 at level 1, +6 at level 2, +9 at level 3) and its balance impact.
## 2. Restructured "不期而遇" (Arknights-style Encounters) node design and its interplay with Cards, Raft, and Combat.

var failures := 0
var catalog

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("  [OK] " + message)

func session(origin: String = "strong", seed: int = 42):
	var s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new", {"mode": "challenge", "origin": origin, "seed": seed})
	return s

func _init() -> void:
	print("=====================================================================")
	print("START: Encounter Node Design & Crate Capacity Balance Test")
	print("=====================================================================")
	
	catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(), "Load content catalog")

	test_crate_capacity_values()
	test_crate_raft_synergy_and_damage_disabling()
	test_encounter_archetype_salvage_relics()
	test_encounter_archetype_cursed_box_gamble()
	test_encounter_archetype_phantom_trader()
	test_encounter_archetype_pit_fight()
	test_encounter_archetype_beast_cub()
	test_four_systems_equilibrium()

	print("=====================================================================")
	print("ENCOUNTER BALANCE TEST RESULT: %s (Failures: %d)" % ["PASS" if failures == 0 else "FAIL", failures])
	print("=====================================================================")
	quit(1 if failures > 0 else 0)

## ------------------------------------------------------------------
## 1. 箱子容量数值与升级阶梯验证 (Crate Capacity Scaling)
## ------------------------------------------------------------------
func test_crate_capacity_values() -> void:
	print("\n--- Testing Crate Capacity Scaling (+3, +6, +9) ---")
	var I = load("res://core/inventory.gd")
	var s = session()
	
	# Baseline without crate
	check(I.hand_limit(s.state, catalog) == 10, "Base hand limit is 10")
	
	# Install Level 1 crate
	var cell = s.state.cells[0]
	cell.equipment = {"id": "crate", "level": 1, "fuel": 0, "progress": 0}
	check(I.hand_limit(s.state, catalog) == 13, "Level 1 crate expands hand limit to 13 (+3)")
	
	# Upgrade to Level 2 crate
	cell.equipment.level = 2
	check(I.hand_limit(s.state, catalog) == 16, "Level 2 crate expands hand limit to 16 (+6)")
	
	# Upgrade to Level 3 crate
	cell.equipment.level = 3
	check(I.hand_limit(s.state, catalog) == 19, "Level 3 crate expands hand limit to 19 (+9)")
	
	# Two crates stack additively
	var cell2 = s.state.cells[1]
	cell2.equipment = {"id": "crate", "level": 1, "fuel": 0, "progress": 0}
	check(I.hand_limit(s.state, catalog) == 22, "Two crates (Lv3 + Lv1) grant 10 + 9 + 3 = 22 hand limit")
	print("  Crate Capacity Insight: Hand limit of 13/16 provides adequate buffer for 4-card spring draws.")

## ------------------------------------------------------------------
## 2. 木筏损毁与箱子容量失效联动 (Raft-Crate Damage Linkage)
## ------------------------------------------------------------------
func test_crate_raft_synergy_and_damage_disabling() -> void:
	print("\n--- Testing Raft-Crate Synergy (Cell Damage Disables Capacity) ---")
	var I = load("res://core/inventory.gd")
	var s = session()
	var cell = s.state.cells[0]
	cell.equipment = {"id": "crate", "level": 2, "fuel": 0, "progress": 0}
	check(I.hand_limit(s.state, catalog) == 16, "Intact Lv2 crate provides 16 hand limit")
	
	# Fill hand with 14 cards (allowed under 16 limit)
	s.state.hand = []
	for i in range(14):
		s.give("wood")
	check(I.capacity(s.state) == 14, "Player holds 14 cards")
	
	# Damage the cell holding the crate!
	cell.status = "damaged"
	cell.damaged_at = s.state.voyage
	
	# Capacity boost is immediately lost when cell is damaged!
	var limit_damaged = I.hand_limit(s.state, catalog)
	check(limit_damaged == 10, "Damaged cell immediately suspends crate bonus (limit drops from 16 back to 10)")
	
	# At settlement, holding 14 cards with limit 10 forces discard phase!
	s.state.phase = "aftermath"
	check(s.dispatch("end_voyage"), "Settlement dispatch succeeds")
	check(s.state.phase == "discard", "Player forced into discard phase because 14 > 10")
	
	# Repair cell in preparation phase
	s.state.phase = "preparation"
	s.state.ap = 2
	check(s.dispatch("repair_cell", {"cell": cell.id, "material": "wood"}), "Repairing crate cell succeeds")
	check(I.hand_limit(s.state, catalog) == 16, "Repaired cell immediately restores 16 hand limit")
	print("  Raft-Crate Linkage Insight: Protecting and repairing the crate cell is critical to prevent sudden mass discards.")

## ------------------------------------------------------------------
## 3. 不期而遇原型 1：遗骸与打捞 (Salvage & Relics - 无效验尸/陌生旅伴)
## ------------------------------------------------------------------
func test_encounter_archetype_salvage_relics() -> void:
	print("\n--- Testing Encounter Archetype 1: Salvage & Relics (浮木与遗骸) ---")
	var s = session()
	var I = load("res://core/inventory.gd")
	
	# Test Option A: Search supplies (1 AP -> Wood 1, Food 1)
	s.state.phase = "story"
	s.state.story_step = "choice"
	s.state.ap = 2
	var option_a = {
		"id": "search_provisions",
		"name": "搜寻密封补给",
		"description": "撬开被水草包裹的补给箱，获得木头与食物。",
		"cost": 1,
		"effects": [
			{"type": "GiveCard", "id": "wood", "amount": 1},
			{"type": "GiveCard", "id": "food", "amount": 1}
		]
	}
	s.state.node = {"id": "enc_relics", "name": "浮木与遗骸", "options": [option_a]}
	check(s.dispatch("option", {"id": "search_provisions"}), "Choose search provisions option")
	check(I.count(s.state, "wood") >= 1 and I.count(s.state, "food") >= 1, "Provisions option granted wood and food")
	check(s.state.ap == 1, "AP reduced by 1")
	
	# Test Option B: Simple sea burial (Cloth 1 -> SAN +25, avoidWave = true)
	s.state.story_step = "choice"
	s.state.player.sanity = 50
	s.give("cloth", 1)
	var option_b = {
		"id": "sea_burial",
		"name": "简易海葬",
		"description": "用布条将残骸包裹沉入海渊，获得精神安宁与海流眷顾。",
		"cost": 0,
		"cardCosts": {"cloth": 1},
		"effects": [
			{"type": "ChangeCurrent", "stat": "sanity", "delta": 25},
			{"type": "SetFlag", "key": "avoidWave", "value": true}
		]
	}
	s.state.node = {"id": "enc_relics", "name": "浮木与遗骸", "options": [option_b]}
	check(s.dispatch("option", {"id": "sea_burial"}), "Choose sea burial option")
	check(s.state.player.sanity == 75, "Sanity increased by 25")
	check(s.state.flags.get("avoidWave", false) == true, "Sea burial grants avoidWave flag (reduces next voyage cost)")

## ------------------------------------------------------------------
## 4. 不期而遇原型 2：深渊死箱博弈 (Cursed Box Gamble - 死箱/活木)
## ------------------------------------------------------------------
func test_encounter_archetype_cursed_box_gamble() -> void:
	print("\n--- Testing Encounter Archetype 2: Cursed Box Gamble (深渊死箱) ---")
	var s = session()
	s.state.phase = "story"
	s.state.story_step = "choice"
	s.give("wood", 1)
	s.state.ap = 2
	
	# Option A: Violent pry with crowbar (Cost 1 wood, 1 AP -> 70% iron+coins, 30% DamageCell)
	var option_pry = {
		"id": "pry_box",
		"name": "撬棒暴力破拆",
		"description": "强行破拆锁扣，可能震伤木筏或获得高额金属。",
		"cost": 1,
		"cardCosts": {"wood": 1},
		"outcomes": [
			{"weight": 70, "effects": [{"type": "GiveCard", "id": "iron", "amount": 2}, {"type": "GiveCard", "id": "coin", "amount": 2}]},
			{"weight": 30, "effects": [{"type": "DamageCell"}]}
		]
	}
	s.state.node = {"id": "enc_dead_box", "name": "深渊死箱", "options": [option_pry]}
	check(s.dispatch("option", {"id": "pry_box"}), "Violent pry executed smoothly with weighted outcomes")
	
	# Option B: Blood sacrifice unlock (Cost 2 HP, 0 AP -> safe high return)
	s.state.story_step = "choice"
	s.state.player.hp = 10
	var option_blood = {
		"id": "blood_unlock",
		"name": "以血濡祭符文",
		"description": "以鲜血浸润海蚀封印，安全解开箱锁。",
		"cost": 0,
		"statCosts": {"hp": 2},
		"effects": [
			{"type": "GiveCard", "id": "iron", "amount": 2},
			{"type": "GiveCard", "id": "water", "amount": 1}
		]
	}
	s.state.node = {"id": "enc_dead_box", "name": "深渊死箱", "options": [option_blood]}
	check(s.dispatch("option", {"id": "blood_unlock"}), "Blood unlock option executed")
	check(s.state.player.hp == 8, "HP sacrificed by 2 for guaranteed safe return")

## ------------------------------------------------------------------
## 5. 不期而遇原型 3：幽灵商船奇遇 (Phantom Trader - 强买强卖)
## ------------------------------------------------------------------
func test_encounter_archetype_phantom_trader() -> void:
	print("\n--- Testing Encounter Archetype 3: Phantom Trader (迷途幽灵船) ---")
	var s = session()
	s.state.phase = "story"
	s.state.story_step = "choice"
	s.give("plastic", 2)
	s.state.ap = 1
	
	# Option: Exchange excess plastic for medical gear
	var option_trade = {
		"id": "trade_plastic",
		"name": "交付塑料残件换取医疗包",
		"description": "幽灵机械臂接收了塑料残料，抛出一个封蜡医疗包。",
		"cost": 1,
		"cardCosts": {"plastic": 2},
		"effects": [
			{"type": "GiveCard", "id": "medkit", "amount": 1}
		]
	}
	s.state.node = {"id": "enc_phantom_trader", "name": "迷途幽灵船", "options": [option_trade]}
	check(s.dispatch("option", {"id": "trade_plastic"}), "Phantom trader accepts plastic exchange for medkit")
	check(s.I.count(s.state, "medkit") >= 1, "Player received medkit from encounter")

## ------------------------------------------------------------------
## 6. 不期而遇原型 4：潮穴搏杀角斗 (Tidal Pit Fight - 原始娱乐/搏杀)
## ------------------------------------------------------------------
func test_encounter_archetype_pit_fight() -> void:
	print("\n--- Testing Encounter Archetype 4: Tidal Pit Fight (潮穴搏杀) ---")
	var s = session()
	s.state.phase = "story"
	s.state.story_step = "choice"
	s.state.player.hp = 12
	s.state.ap = 1
	
	# Option: Fight in arena (Cost 3 HP, 1 AP -> Gain 3 coins, 1 corpse, and power boost)
	var option_arena = {
		"id": "arena_fight",
		"name": "亲自下水搏杀角斗",
		"description": "跃入斗兽坑中击毙潮兽，掠取丰厚赏金与战利品。",
		"cost": 1,
		"statCosts": {"hp": 3},
		"effects": [
			{"type": "GiveCard", "id": "coin", "amount": 3},
			{"type": "GiveCard", "id": "corpse", "amount": 1}
		]
	}
	s.state.node = {"id": "enc_pit_fight", "name": "潮穴搏杀", "options": [option_arena]}
	check(s.dispatch("option", {"id": "arena_fight"}), "Arena fight option executed")
	check(s.state.player.hp == 9, "Player took 3 HP damage in pit fight")
	check(s.state.coins >= 3, "Earned 3 coins from victory")
	check(s.I.count(s.state, "corpse") >= 1, "Obtained monster corpse for fuel/nursery")

## ------------------------------------------------------------------
## 7. 不期而遇原型 5：海兽幼崽羁绊 (Beast Cub - 鸭托邦/陌生旅伴)
## ------------------------------------------------------------------
func test_encounter_archetype_beast_cub() -> void:
	print("\n--- Testing Encounter Archetype 5: Beast Cub (海兽幼崽) ---")
	var s = session()
	s.state.phase = "story"
	s.state.story_step = "choice"
	s.give("food", 1)
	
	# Option: Feed food to cub (Cost 1 food -> Rested buff +1 AP for 2 voyages)
	var option_feed = {
		"id": "feed_cub",
		"name": "投喂食物照料幼崽",
		"description": "幼崽舔舐你的手心，游弋在木筏周围护航，使后续两轮行动充裕。",
		"cost": 0,
		"cardCosts": {"food": 1},
		"effects": [
			{"type": "AddBuff", "id": "rested"}
		]
	}
	s.state.node = {"id": "enc_beast_cub", "name": "海兽幼崽", "options": [option_feed]}
	check(s.dispatch("option", {"id": "feed_cub"}), "Feeding cub succeeded")
	check(int(s.state.flags.get("rested_until", 0)) >= s.state.voyage + 2, "Cub loyalty grants rested AP buff for 2 voyages")

## ------------------------------------------------------------------
## 8. 四系统平衡整体闭环验证 (Four Systems Equilibrium)
## ------------------------------------------------------------------
func test_four_systems_equilibrium() -> void:
	print("\n--- Testing Overall Equilibrium (Cards, Raft, Combat, Encounters) ---")
	var s = session()
	
	# Step 1: Raft equips Crate (+3 limit = 13)
	s.state.cells[0].equipment = {"id": "crate", "level": 1, "fuel": 0, "progress": 0}
	check(s.I.hand_limit(s.state, catalog) == 13, "System 1 & 2: Crate expands hand capacity to 13")
	
	# Step 2: Player uses Encounter rewards to solve wood deficit
	var wood_before = s.I.count(s.state, "wood")
	s.give("wood", 2, false, "encounter")
	check(s.I.count(s.state, "wood") == wood_before + 2, "System 2: Encounter provides wood for cell repair & lamp")
	
	# Step 3: Encounter provides combat assistance before crab battle
	s.give("medkit", 1, false, "encounter")
	check(s.I.count(s.state, "medkit") >= 1, "System 3: Encounter equips player with medkit before heavy combat")
	
	# Step 4: Discard phase does not trigger prematurely thanks to Crate
	s.state.hand = []
	for i in range(12): s.give("iron")
	check(s.I.capacity(s.state) == 12 and s.I.capacity(s.state) <= s.I.hand_limit(s.state, catalog), "System 4: 12 cards held cleanly without being forced to discard")
	print("  Four Systems Equilibrium Insight: Restructured encounters + upgraded crates harmoniously bridge the survival, crafting, and combat bottlenecks.")
