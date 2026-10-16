extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _init() -> void:
	call_deferred("run")

func card_count(s, id: String) -> int:
	return s.state.hand.filter(func(c): return c.id == id).size()

func run() -> void:
	var catalog = load("res://content/catalog.gd").new()
	catalog.load_catalog()
	var assets = load("res://presentation/asset_catalog.gd").new()
	var RaftActions = load("res://presentation/raft_actions.gd")

	print("\n--- 1. Testing Dismantle Action ---")
	var s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new", {"mode": "challenge", "origin": "strong", "seed": 42})
	s.state.ap = 3
	s.give("filter")
	var filter_card = s.state.hand[-1]
	var cell_id = s.state.cells[0].id
	check(s.dispatch("install", {"uid": filter_card.uid, "cell": cell_id}), "安装净化器成功")
	check(not s.state.cells[0].equipment.is_empty(), "第0格外设已安装")

	var ap_before = s.state.ap
	var plastic_before = card_count(s, "plastic")
	var raft_actions = RaftActions.new()
	raft_actions.refresh(s)
	var actions = raft_actions.cell_actions(cell_id)
	var dismantle_opt: Dictionary = {}
	for act in actions:
		if act.get("operation") == "dismantle":
			dismantle_opt = act; break
	check(not dismantle_opt.is_empty(), "筏格详情中存在拆除选项")
	check(dismantle_opt.allowed, "有AP时允许拆除")

	check(s.dispatch("dismantle", {"cell": cell_id}), "执行拆除命令成功")
	check(s.state.cells[0].equipment.is_empty(), "拆除后筏格设备已清空")
	check(s.state.ap == ap_before - 1, "拆除扣除1点AP")
	check(card_count(s, "plastic") == plastic_before + 1, "拆除返还主要原料(塑料)")

	print("\n--- 2. Testing 3 Crossbows Upgrade Bug Fix ---")
	s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new", {"mode": "challenge", "origin": "strong", "seed": 42})
	s.state.ap = 5
	# Give 3 crossbows and install them on 3 different cells
	for i in range(3):
		s.give("crossbow")
		var cb_card = s.state.hand[-1]
		check(s.dispatch("install", {"uid": cb_card.uid, "cell": s.state.cells[i].id}), "安装第%d个弩机" % (i + 1))
	check(card_count(s, "crossbow") == 0, "手牌中已无弩机卡牌")

	# Query raft actions for all 3 cells
	raft_actions.refresh(s)
	for i in range(3):
		var cid = s.state.cells[i].id
		var actions_cid = raft_actions.cell_actions(cid)
		var up_opts = actions_cid.filter(func(a): return a.get("label", "").begins_with("升级"))
		check(up_opts.size() > 0 and not up_opts[0].allowed, "手上没有弩机时，第%d格弩机不可升级(禁止吞噬其他已安装弩机)" % (i + 1))

	# Now give 1 crossbow to hand
	s.give("crossbow")
	var donor_card = s.state.hand[-1]
	raft_actions.refresh(s)
	var target_cid = s.state.cells[0].id
	var up_opts_allowed = raft_actions.cell_actions(target_cid).filter(func(a): return a.get("label", "").begins_with("升级"))
	check(up_opts_allowed.size() > 0 and up_opts_allowed[0].allowed, "手上有弩机手牌时允许升级")

	check(s.dispatch("upgrade", {"cell": target_cid, "uid": donor_card.uid}), "使用手牌升级弩机成功")
	check(int(s.state.cells[0].equipment.level) == 2, "第0格弩机升至2级")
	check(card_count(s, "crossbow") == 0, "手牌弩机被消耗")
	check(not s.state.cells[1].equipment.is_empty(), "第1格弩机依然完好保留")
	check(not s.state.cells[2].equipment.is_empty(), "第2格弩机依然完好保留")

	print("\n--- 3. Testing Build Page Filtering & Layout ---")
	var CraftPage = load("res://pages/craft_page.gd")
	var craft_ui = CraftPage.new()
	var view_build = s.view()
	view_build.panel = "build"
	craft_ui.setup(view_build, catalog, assets)
	root.add_child(craft_ui)

	var header_lbl = craft_ui.find_child("CraftHeader", true, false).get_child(0)
	check(header_lbl.text == "建造设备", "建造模式标题为'建造设备'")
	check(craft_ui.find_child("TransmuteTabButton", true, false) == null, "建造模式隐藏资源转化页签")

	var grid = craft_ui.find_child("RecipeGrid", true, false)
	check(grid != null, "存在配方网格")
	check(grid.get_child_count() == 8, "建造配方网格固定对齐到8个单元(4x2网格)")
	craft_ui.queue_free()
	await process_frame

	print("\n--- 4. Testing Craft Page Grid Dimensions Consistency across Pages ---")
	var craft_ui_p1 = CraftPage.new()
	var view_p1 = s.view()
	view_p1.panel = "craft"
	view_p1.ui_state = {"list_page": 0, "craft_tab": "craft"}
	craft_ui_p1.setup(view_p1, catalog, assets)
	root.add_child(craft_ui_p1)
	var grid_p1 = craft_ui_p1.find_child("RecipeGrid", true, false)
	check(grid_p1.get_child_count() == 8, "合成第1页槽位总数为8")
	craft_ui_p1.queue_free()
	await process_frame

	var craft_ui_p2 = CraftPage.new()
	var view_p2 = s.view()
	view_p2.panel = "craft"
	view_p2.ui_state = {"list_page": 1, "craft_tab": "craft"}
	craft_ui_p2.setup(view_p2, catalog, assets)
	root.add_child(craft_ui_p2)
	var grid_p2 = craft_ui_p2.find_child("RecipeGrid", true, false)
	check(grid_p2.get_child_count() == 8, "合成第2页通过占位对齐到8，卡片形状与第1页一致")
	craft_ui_p2.queue_free()
	await process_frame

	print("\n--- 5. Testing Salvage Button Repositioning & Shape ---")
	var VoyageHud = load("res://pages/voyage_hud.gd")
	var hud = VoyageHud.new()
	var view_hud = s.view()
	view_hud.ui_state = {}
	root.add_child(hud)
	hud.setup(view_hud, catalog, assets)

	var salvage_btn = hud.find_child("SalvageEntry", true, false)
	check(salvage_btn != null, "存在SalvageEntry独立打捞按钮")
	check(salvage_btn.text == "打捞 · AP1", "打捞按钮文案为'打捞 · AP1'")
	check(salvage_btn.offset_top == -238 and salvage_btn.offset_bottom == -190, "打捞按钮位于合成按钮上方(y: -238至-190)")
	var sb_style = salvage_btn.get_theme_stylebox("normal")
	check(sb_style is StyleBoxFlat and sb_style.corner_radius_top_left == 8, "打捞按钮使用圆角矩形样式(corner_radius=8)")

	var op_frame = hud.find_child("VoyageOperationFrame", true, false)
	var inner_salvage = op_frame.find_children("*", "Button", true, false).filter(func(b): return "打捞" in b.text)
	check(inner_salvage.is_empty(), "右侧操作面板中已移除重复的打捞按钮")
	hud.queue_free()
	await process_frame

	print("\n--- 6. Testing Battle Card Double-Click Auto-Play ---")
	s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new", {"mode": "challenge", "origin": "strong", "seed": 42})
	s.state.phase = "battle"
	s.state.ap = 2
	s.state.node = catalog.entry("nodes", "battle")
	s.state.battle = {"id": "biter", "hp": 10, "turn": 1, "ap": 2, "entry_hp": 40, "poison_until": 0, "fear_until": 0}
	s.give("arrow")
	var arrow_card = s.state.hand[-1]

	var battle_hud = VoyageHud.new()
	var view_battle = s.view()
	view_battle.ui_state = {}
	root.add_child(battle_hud)
	battle_hud.command_requested.connect(func(cmd, args): s.dispatch(cmd, args))
	battle_hud.configure_session(s)
	battle_hud.setup(view_battle, catalog, assets)

	var bview = battle_hud.find_child("BattleHUDView", true, false)
	check(bview != null, "战斗页面生成BattleHUDView")
	var hp_before = s.state.battle.hp
	bview.on_action_double_clicked(arrow_card)
	check(s.state.battle.hp < hp_before, "双击射箭自动打出并扣除怪物生命")
	battle_hud.queue_free()
	await process_frame

	print("\n==========================================")
	print("ALL BATCH FEATURES & FIXES: %s" % ("PASS" if failures == 0 else "FAIL"))
	print("==========================================")
	quit(0 if failures == 0 else 1)
