extends SceneTree
var failures := 0
var catalog
const I = preload("res://core/inventory.gd")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _init() -> void:
	catalog = load("res://content/catalog.gd").new()
	catalog.load_catalog()

	# 1. Test Recipe Health: repair kit uses iron 1 and rope 1
	var repair_recipe = catalog.entry("recipes", "repair")
	check(repair_recipe.ingredients.has("iron") and repair_recipe.ingredients.iron == 1, "修补包配方包含铁1")
	check(repair_recipe.ingredients.has("rope") and repair_recipe.ingredients.rope == 1, "修补包配方包含绳索1")
	check(not repair_recipe.ingredients.has("wood"), "修补包配方不再强制需要木头")

	# 2. Test Crafting Repair Kit with Iron and Rope
	var s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new", {"mode": "challenge", "origin": "strong", "seed": 42})
	s.state.hand = []
	I.give(s.state, "iron", 1, false, "fixture")
	I.give(s.state, "rope", 1, false, "fixture")
	s.state.ap = 2
	check(s.dispatch("craft", {"id": "repair"}), "仅有铁和绳索时可成功制造修补包")
	check(I.count(s.state, "repair") == 1, "修补包成功加入手牌")
	check(I.count(s.state, "iron") == 0 and I.count(s.state, "rope") == 0, "制造正确扣减铁与绳索")
	check(s.state.ap == 1, "制造扣减1点AP")

	# 3. Test Cell Repair with 2 Ropes (when wood is 0)
	s.state.hand = []
	I.give(s.state, "rope", 2, false, "fixture")
	s.state.cells[0].status = "damaged"
	s.state.ap = 2
	check(s.dispatch("repair_cell", {"cell": "cell-0"}), "无木头时可用2根绳索修补破损木筏格")
	check(s.state.cells[0].status == "intact", "筏格成功恢复完好")
	check(I.count(s.state, "rope") == 0, "扣除2根绳索")
	check(s.state.ap == 1, "修补扣减1点AP")

	# 4. Test Cell Repair with 1 Wood (when wood is present)
	s.state.hand = []
	I.give(s.state, "wood", 1, false, "fixture")
	I.give(s.state, "rope", 2, false, "fixture")
	s.state.cells[0].status = "damaged"
	s.state.ap = 2
	check(s.dispatch("repair_cell", {"cell": "cell-0"}), "有木头时优先扣除木头修补")
	check(s.state.cells[0].status == "intact", "筏格成功恢复完好")
	check(I.count(s.state, "wood") == 0, "优先扣除1块木头")
	check(I.count(s.state, "rope") == 2, "绳索得以保留")

	# 5. Test Sea Salvage in Navigation, Preparation, and Aftermath
	s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new", {"mode": "challenge", "origin": "strong", "seed": 99})
	s.state.cells[0].equipment={"id":"fishingNet","level":1,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
	s.state.hand = []
	s.state.ap = 3
	check(s.phase() == "navigation", "当前为导航阶段")
	check(s.dispatch("salvage"), "导航阶段可执行打捞")
	check(s.state.ap == 2, "打捞扣减1点AP")
	check(s.state.hand.size() == 2, "打捞产物进入手牌")
	check(s.state.hand[0].id in I.RESOURCES, "打捞产物属于基础资源")

	s.state.phase = "preparation"
	s.state.ap = 2
	check(s.dispatch("salvage"), "准备阶段可执行打捞")
	check(s.state.ap == 1, "打捞扣减1点AP")
	check(s.state.hand.size() == 4, "保底与捕捞网再次产出两张手牌")

	s.state.phase = "aftermath"
	s.state.ap = 1
	var pre_hand_count: int = s.state.hand.size()
	check(s.dispatch("salvage"), "收尾阶段可执行打捞")
	check(s.phase() == "navigation", "收尾耗尽最后AP自动完成轮末老化/生产并进入新一轮导航")
	check(s.state.voyage == 2, "进入第2航次")
	check(s.state.ap == s.state.player.base_ap, "新航次刷新基地AP")
	check(s.state.hand.size() == pre_hand_count + 2 + 2 + 1, "获得打捞2张、涌泉2张和航行轮初捕捞网1张")

	s.state.ap = 0
	check(not s.dispatch("salvage"), "AP为0时无法打捞")

	print("SALVAGE AND RECIPES: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
