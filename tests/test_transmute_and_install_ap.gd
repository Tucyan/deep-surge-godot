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
	# Wait through deferred modal and container layout after pointer-triggered rebuilds.
	for i in range(4): await process_frame

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
	
	# 4. Real pointer integration: selection is local until dispatch.
	app = load("res://flow_app.gd").new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.persistence = false
	root.add_child(app)
	await settle()
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":22})
	for id in ["wood", "wood", "wood", "iron", "plastic"]:
		app.session.give(id, 1, false, "test-fixture")
	app.handle_command("panel", {"id":"craft"})
	app.handle_ui("craft_tab", "transmute")
	await settle()
	var before: Dictionary = app.session.snapshot()
	var execute = app.find_child("TransmuteExecuteButton", true, false)
	check(execute.disabled, "initial selection is empty and cannot execute")
	check(app.find_child("TransmuteCountSection", true, false) == null, "batch controls removed")
	for id in ["wood", "iron", "plastic", "rope", "cloth"]:
		check(app.find_child("MatPlus_" + id, true, false) == null, "no material stepper")
		var item = app.find_child("MatItem_" + id, true, false)
		check(item != null and item.size.y >= 130, "larger material card")
	var wood_count: int = app.session.I.count(app.session.state, "wood")
	var quantity = app.find_child("MatQuantity_wood", true, false)
	check(quantity != null, "quantity ratio exists")
	if quantity != null: check(quantity.text == "0/%d" % wood_count, "initial ratio shows zero selected")
	await click(app.find_child("MatItem_cloth", true, false))
	check(app.ui_state.transmute_uids in ["", "none"], "unavailable material cannot be selected")
	await click(app.find_child("MatItem_wood", true, false))
	check(app.ui_state.transmute_uids.split(",").size() == 1, "one click selects one material")
	quantity = app.find_child("MatQuantity_wood", true, false)
	if quantity != null: check(quantity.text == "1/%d" % wood_count, "ratio updates after selecting")
	await click(app.find_child("DiagramSlot1", true, false))
	check(app.ui_state.transmute_uids in ["none", ""], "clicking input slot cancels last selection")
	await click(app.find_child("DiagramSlot1", true, false))
	check(app.session.snapshot() == before, "empty slot click is harmless")
	await click(app.find_child("MatItem_wood", true, false))
	await click(app.find_child("MatItem_iron", true, false))
	await click(app.find_child("MatItem_plastic", true, false))
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/workbench-selected.png")
	for name in ["DiagramSlot1", "DiagramSlot2", "DiagramSlot3"]:
		check(app.find_child(name, true, false).find_children("*", "Label", true, false).is_empty(), "input slot displays icons only")
	var output = app.find_child("DiagramOutputSlot", true, false)
	var output_labels = output.find_children("*", "Label", true, false)
	check(output_labels.size() == 1 and output_labels[0].text == "2", "output shows only the quantity 2 beneath its icon")
	var top_input = app.find_child("DiagramSlot1", true, false)
	check(output.get_global_rect().position.y - top_input.get_global_rect().end.y >= 36, "upper green connector has visible space")
	var selected: String = app.ui_state.transmute_uids
	await click(app.find_child("MatItem_wood", true, false))
	check(app.ui_state.transmute_uids == selected, "full slots reject fourth input")
	await click(app.find_child("DiagramSlot2", true, false))
	check(app.ui_state.transmute_uids.split(",").size() == 2, "middle slot cancels exactly one UID")
	check(selected.split(",")[1] not in app.ui_state.transmute_uids.split(","), "middle slot removes its own material UID")
	check(app.session.snapshot() == before, "selection and cancellation preserve state and RNG")
	var help = app.find_child("CraftHelpButton", true, false)
	check(help != null, "workbench help exists")
	if help != null:
		var close = app.find_child("CloseX", true, false)
		check(help.get_global_rect().end.x < close.get_global_rect().position.x, "help is left of close")
		await click(help)
		var dialog = app.find_child("CraftHelpDialog", true, false)
		check(dialog != null and dialog.visible, "help opens workbench instructions")
		if dialog != null:
			check(dialog.size.x <= root.size.x, "help fits window")
			if "--capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				dialog.get_texture().get_image().save_png("res://evidence/workbench-help.png")
			dialog.hide()
		check(app.session.snapshot() == before, "help preserves state and RNG")
	await click(app.find_child("MatItem_wood", true, false))
	await click(app.find_child("TargetItem_cloth", true, false))
	check(app.ui_state.transmute_uids in ["", "none"], "changing target leaves empty inputs")
	for i in range(3):
		await click(app.find_child("MatItem_wood", true, false))
	var ap_before: int = app.session.state.ap
	var cloth_before: int = app.session.I.count(app.session.state, "cloth")
	execute = app.find_child("TransmuteExecuteButton", true, false)
	check(not execute.disabled, "three chosen inputs enable conversion")
	await click(execute)
	check(app.session.state.ap == ap_before - 1, "execute spends exactly one AP")
	check(app.session.I.count(app.session.state, "cloth") == cloth_before + 2, "execute produces two chosen resources")
	check(app.find_child("TransmuteExecuteButton", true, false).disabled, "consumed inputs do not auto-refill")
	for config in [Vector3(1600,900,1), Vector3(1280,720,1), Vector3(1280,720,1.25), Vector3(1920,820,1.25)]:
		root.size = Vector2i(config.x, config.y)
		app.display_settings.free_aspect = true
		app.display_settings.ui_scale = config.z
		app.apply_display_settings(false)
		await settle()
		for name in ["TransmuteColumns", "TransmuteMaterialList", "TransmuteTargets", "TransmuteExecuteButton"]:
			var control = app.find_child(name, true, false)
			check(app.get_global_rect().encloses(control.get_global_rect()), name + " fits viewport " + str(config))
		var diagram = app.find_child("FusionDiagram", true, false)
		check(app.find_child("DiagramOutputSlot", true, false).get_global_rect().position.y - app.find_child("DiagramSlot1", true, false).get_global_rect().end.y >= 36, "upper connector remains visible at " + str(config))
		for name in ["DiagramSlot1", "DiagramSlot2", "DiagramSlot3", "DiagramOutputSlot"]:
			check(diagram.get_global_rect().encloses(app.find_child(name, true, false).get_global_rect()), "diagram slot fits " + name)
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/workbench-%dx%d-%d.png" % [config.x, config.y, roundi(config.z * 100)])
	for config in [Vector3(1280,720,1.25), Vector3(1600,900,1)]:
		root.size = Vector2i(config.x, config.y)
		app.display_settings.ui_scale = config.z
		app.apply_display_settings(false)
		app.handle_ui("craft_tab", "craft")
		await settle()
		var grid = app.find_child("RecipeGrid", true, false)
		check(grid != null and grid.columns == 4, "recipe tab still uses four columns")
		# The list scrolls, so the scroll region (not the whole grid) must fit the window.
		var recipe_scroll = app.find_child("RecipeScroll", true, false)
		if recipe_scroll == null: recipe_scroll = app.find_child("MobileRecipeScroll", true, false)
		check(recipe_scroll != null and app.get_global_rect().encloses(recipe_scroll.get_global_rect()), "larger recipe UI fits " + str(config))
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/workbench-recipes-%dx%d-%d.png" % [config.x, config.y, roundi(config.z * 100)])
	app.queue_free()
	await settle()
	print("TRANSMUTE AND INSTALL AP: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func click(control: Control) -> void:
	var pos: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos; event.global_position = pos
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()
