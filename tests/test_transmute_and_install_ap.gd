extends SceneTree
var failures := 0
var app: Control

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + why)

func _init() -> void:
	call_deferred("run")

func settle() -> void:
	await process_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(1600, 900)
	var catalog = load("res://content/catalog.gd").new()
	catalog.load_catalog()
	
	# 1. Verify equipment cost in catalog is 0
	for eq in ["lamp", "filter", "planter", "crossbow", "spearRack"]:
		check(int(catalog.entry("cards", eq).cost) == 0, "Card %s cost must be 0" % eq)
	
	# 2. Test Rule Session: install 0 AP
	var s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new", {"mode": "challenge", "origin": "strong", "seed": 42})
	check(s.state.ap == 3, "Initial AP is 3")
	s.give("filter")
	var filter_card = s.state.hand[-1]
	check(s.dispatch("install", {"uid": filter_card.uid, "cell": "cell-0"}), "Install filter into cell-0")
	check(s.state.ap == 3, "Installation does NOT consume AP (ap remains 3)")
	check(s.state.cells[0].equipment.id == "filter", "Cell-0 has filter installed")
	
	# Install at 0 AP
	s.state.ap = 0
	s.give("lamp")
	var lamp_card = s.state.hand[-1]
	check(s.dispatch("install", {"uid": lamp_card.uid, "cell": "cell-1"}), "Install lamp at 0 AP succeeds")
	check(s.state.ap == 0, "AP remains 0 after install")
	check(s.state.cells[1].equipment.id == "lamp", "Cell-1 has lamp installed")
	
	# 3. Test Transmutation Rules
	s.state.hand = []
	# Insufficient AP
	s.give("wood", 4)
	check(not s.dispatch("transmute", {"target": "cloth"}), "Transmute fails when AP < 1")
	
	# With 1 AP, auto transmute 3 wood -> 2 cloth
	s.state.ap = 1
	var wood_before = s.I.count(s.state, "wood")
	var result = s.dispatch("transmute", {"target": "cloth"})
	check(result, "Auto transmute 3 wood -> 2 cloth succeeds")
	check(s.state.ap == 0, "Transmute spends 1 AP (now 0)")
	check(s.I.count(s.state, "cloth") == 2, "Transmute granted 2 cloth")
	check(s.I.count(s.state, "wood") == wood_before - 3, "Transmute consumed 3 wood")
	
	# Insufficient resources (< 3)
	s.state.ap = 1
	check(s.I.count(s.state, "wood") == 1, "Only 1 wood left")
	# Hand has 1 wood, 2 cloth. Let's discard the 2 cloth so only 1 resource remains
	s.state.hand = s.state.hand.filter(func(c): return c.id != "cloth")
	check(not s.dispatch("transmute", {"target": "plastic"}), "Transmute fails with < 3 resource cards")
	
	# Transmute with specific UIDs
	s.give("wood", 1)
	s.give("iron", 1)
	s.give("plastic", 1)
	s.give("rope", 1)
	# Now hand has: 2 wood, 1 iron, 1 plastic, 1 rope (5 resource cards total)
	var wood_uid = s.state.hand.filter(func(c): return c.id == "wood")[0].uid
	var iron_uid = s.state.hand.filter(func(c): return c.id == "iron")[0].uid
	var plastic_uid = s.state.hand.filter(func(c): return c.id == "plastic")[0].uid
	
	s.state.ap = 2
	check(s.dispatch("transmute", {"target": "rope", "uids": [wood_uid, iron_uid, plastic_uid]}), "Transmute specific 3 cards -> 2 rope")
	check(s.state.ap == 1, "Transmute deducted 1 AP (was 2, now 1)")
	check(s.I.count(s.state, "rope") == 3, "Had 1 rope, now has 3 rope")
	check(s.I.count(s.state, "wood") == 1, "Had 2 wood, consumed 1, 1 remains")
	check(s.I.count(s.state, "iron") == 0, "Iron was consumed")
	check(s.I.count(s.state, "plastic") == 0, "Plastic was consumed")
	
	# Multi-batch transmute (count = 2: 6 wood -> 4 iron, 2 AP)
	s.state.hand = []
	s.state.ap = 2
	s.give("wood", 6)
	var wood_before_batch = s.I.count(s.state, "wood")
	var iron_before_batch = s.I.count(s.state, "iron")
	check(s.dispatch("transmute", {"target": "iron", "count": 2}), "Batch transmute count=2 succeeds")
	check(s.state.ap == 0, "Batch transmute spent 2 AP")
	check(s.I.count(s.state, "iron") == iron_before_batch + 4, "Batch transmute granted 4 iron")
	check(s.I.count(s.state, "wood") == wood_before_batch - 6, "Batch transmute consumed 6 wood")
	
	# Reject duplicate UIDs
	s.state.hand = []
	s.give("wood", 2)
	s.give("rope", 1)
	var w1 = s.state.hand.filter(func(c): return c.id == "wood")[0].uid
	var w2 = s.state.hand.filter(func(c): return c.id == "wood")[1].uid
	check(not s.dispatch("transmute", {"target": "iron", "uids": [w1, w1, w2]}), "Reject duplicate UIDs in transmute")
	
	# Reject non-resource card in transmute
	s.give("filter")
	var filter_uid = s.state.hand.filter(func(c): return c.id == "filter")[0].uid
	var r1 = s.state.hand.filter(func(c): return c.id == "rope")[0].uid
	check(not s.dispatch("transmute", {"target": "iron", "uids": [w1, r1, filter_uid]}), "Reject non-resource card in transmute")
	
	# Reject during battle
	s.state.phase = "battle"
	check(not s.dispatch("transmute", {"target": "wood"}), "Transmute blocked during battle")
	s.state.phase = "preparation"
	
	# 4. Test UI Integration
	app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await settle()
	
	app.handle_command("new", {"mode": "challenge", "origin": "strong", "seed": 22})
	for id in ["wood", "wood", "wood", "wood", "wood", "wood", "plastic", "iron"]:
		app.session.give(id, 1, false, "test-fixture")
	app.session.state.ap = 3
	app.render()
	await settle()
	
	var craft_btn = app.find_child("CraftEntry", true, false)
	check(craft_btn != null, "CraftEntry button exists in HUD")
	check(craft_btn.text == "合成/转化", "CraftEntry button text is '合成/转化' (was '%s')" % craft_btn.text)
	
	# Open craft panel
	app.handle_command("panel", {"id": "craft"})
	await settle()
	
	var recipe_grid = app.find_child("RecipeGrid", true, false)
	check(recipe_grid != null, "Default tab shows RecipeGrid")
	
	var craft_tab_btn = app.find_child("CraftTabButton", true, false)
	var transmute_tab_btn = app.find_child("TransmuteTabButton", true, false)
	check(craft_tab_btn != null and transmute_tab_btn != null, "Header has both craft and transmute tab buttons")
	
	# Verify CloseX button does not overlap TransmuteTabButton
	var close_x = app.find_child("CloseX", true, false)
	check(close_x != null, "CloseX button exists on modal surface")
	var close_rect = Rect2(close_x.global_position, close_x.size)
	var tab_rect = Rect2(transmute_tab_btn.global_position, transmute_tab_btn.size)
	check(not close_rect.intersects(tab_rect), "CloseX does not overlap TransmuteTabButton (close_x: %s, tab: %s)" % [close_rect, tab_rect])
	
	# Switch to transmute tab
	app.handle_ui("craft_tab", "transmute")
	await settle()
	
	var transmute_panel = app.find_child("TransmutePanel", true, false)
	check(transmute_panel != null, "TransmutePanel is displayed after switching tab")
	
	# Verify 3-column layout elements
	var left_inv = app.find_child("TransmuteInventory", true, false)
	check(left_inv != null, "Left column TransmuteInventory exists")
	var mat_list = app.find_child("TransmuteMaterialList", true, false)
	check(mat_list != null, "TransmuteMaterialList exists in left column")
	for res_id in ["wood", "iron", "plastic", "rope", "cloth"]:
		var mat_item = app.find_child("MatItem_" + res_id, true, false)
		check(mat_item != null, "Material item %s exists" % res_id)
		var minus_btn = app.find_child("MatMinus_" + res_id, true, false)
		var plus_btn = app.find_child("MatPlus_" + res_id, true, false)
		check(minus_btn != null and plus_btn != null, "Material %s has minus and plus steppers" % res_id)
	
	var center_core = app.find_child("TransmuteCore", true, false)
	check(center_core != null, "Center column TransmuteCore exists")
	var fusion_diag = app.find_child("FusionDiagram", true, false)
	check(fusion_diag != null, "FusionDiagram exists in center column")
	
	# Test clicking card body directly auto-allocates +1
	app.handle_ui("transmute_uids", "none")
	await settle()
	var iron_card_item = app.find_child("MatItem_iron", true, false)
	check(iron_card_item != null, "MatItem_iron exists")
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = iron_card_item.size * 0.5
	iron_card_item.gui_input.emit(click_event)
	await settle()
	var uids_after_click = app.ui_state.get("transmute_uids", "")
	var iron_uids = app.session.state.hand.filter(func(c): return c.id == "iron").map(func(c): return c.uid)
	check(uids_after_click in iron_uids, "Clicking card body auto-allocated 1 iron (transmute_uids: %s)" % uids_after_click)
	
	# Test minus button on iron card
	var minus_iron = app.find_child("MatMinus_iron", true, false)
	check(minus_iron != null and not minus_iron.disabled, "MatMinus_iron enabled after allocation")
	minus_iron.pressed.emit()
	await settle()
	check(app.ui_state.get("transmute_uids", "") == "none", "Minus button cleared iron allocation back to none")
	
	# Test right click on card body decreases allocation
	iron_card_item = app.find_child("MatItem_iron", true, false)
	iron_card_item.gui_input.emit(click_event)
	await settle()
	check(app.ui_state.get("transmute_uids", "") in iron_uids, "Left click allocates iron again")
	iron_card_item = app.find_child("MatItem_iron", true, false)
	var rclick_event := InputEventMouseButton.new()
	rclick_event.button_index = MOUSE_BUTTON_RIGHT
	rclick_event.pressed = true
	rclick_event.position = iron_card_item.size * 0.5
	iron_card_item.gui_input.emit(rclick_event)
	await settle()
	check(app.ui_state.get("transmute_uids", "") == "none", "Right click on card body successfully decrements allocation")
	
	# Test clicking target item row selects the target material
	var target_iron_row = app.find_child("TargetItem_iron", true, false)
	check(target_iron_row != null, "TargetItem_iron row exists")
	var target_click := InputEventMouseButton.new()
	target_click.button_index = MOUSE_BUTTON_LEFT
	target_click.pressed = true
	target_iron_row.gui_input.emit(target_click)
	await settle()
	check(app.ui_state.get("transmute_target", "") == "iron", "Clicking target item row selected 'iron' as target")
	
	# Reset target back to wood and default recommendation for subsequent tests
	app.handle_ui("transmute_target", "wood")
	app.handle_ui("transmute_uids", "")
	await settle()
	
	var right_col = app.find_child("TransmuteRightCol", true, false)
	check(right_col != null, "Right column TransmuteRightCol exists")
	var count_sec = app.find_child("TransmuteCountSection", true, false)
	check(count_sec != null, "TransmuteCountSection exists in right column")
	var target_sec = app.find_child("TransmuteTargetSection", true, false)
	check(target_sec != null, "TransmuteTargetSection exists in right column")
	
	var targets_row = app.find_child("TransmuteTargets", true, false)
	check(targets_row != null and targets_row.get_child_count() == 5, "TransmuteTargets has 5 target options")
	
	var execute_btn = app.find_child("TransmuteExecuteButton", true, false)
	var quick_btn = app.find_child("QuickTransmuteButton", true, false)
	check(execute_btn != null and not execute_btn.disabled, "TransmuteExecuteButton is available")
	check("开始转化" in execute_btn.text, "TransmuteExecuteButton text contains '开始转化' (was '%s')" % execute_btn.text)
	check(quick_btn != null and not quick_btn.disabled, "QuickTransmuteButton is available")
	
	# Test Stepper controls
	var minus_btn = app.find_child("TransmuteCountMinus", true, false)
	var plus_btn = app.find_child("TransmuteCountPlus", true, false)
	var count_lbl = app.find_child("TransmuteCountLabel", true, false)
	check(minus_btn != null and plus_btn != null and count_lbl != null, "Stepper buttons and label exist")
	check(count_lbl.text == "1 批次", "Initial count label is '1 批次'")
	
	# Increase count to 2 via UI
	app.handle_ui("transmute_count", "2")
	await settle()
	count_lbl = app.find_child("TransmuteCountLabel", true, false)
	check(count_lbl.text == "2 批次", "Count label updated to '2 批次'")
	
	# Execute batch transmute (count=2: 6 wood -> 4 cloth, 2 AP)
	var ap_before = app.session.state.ap
	var cloth_before = app.session.I.count(app.session.state, "cloth")
	var wood_cards = app.session.state.hand.filter(func(c): return c.id == "wood")
	var wood_uids = wood_cards.slice(0, 6).map(func(c): return c.uid)
	var wood_before_ui = wood_cards.size()
	app.handle_command("transmute", {"target": "cloth", "count": 2, "uids": wood_uids})
	await settle()
	
	check(app.session.state.ap == ap_before - 2, "UI batch transmute spends 2 AP (was %d, now %d)" % [ap_before, app.session.state.ap])
	check(app.session.I.count(app.session.state, "cloth") == cloth_before + 4, "UI batch transmute grants 4 cloth")
	check(app.session.I.count(app.session.state, "wood") == wood_before_ui - 6, "UI batch transmute consumed 6 wood")
	
	# Switch back to craft tab
	app.handle_ui("craft_tab", "craft")
	await settle()
	recipe_grid = app.find_child("RecipeGrid", true, false)
	check(recipe_grid != null, "Can switch back to RecipeGrid")
	
	app.queue_free()
	await settle()
	
	print("TRANSMUTE AND INSTALL AP: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
