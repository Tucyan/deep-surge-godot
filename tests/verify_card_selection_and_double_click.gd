extends SceneTree

func settle():
	await process_frame; await process_frame; await process_frame

func _init():
	call_deferred("run")

func run():
	root.size = Vector2i(1600, 900)
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await settle()
	
	var s = app.session
	s.dispatch("new", {"mode":"challenge", "origin":"strong", "seed":42})
	s.state.hand = []
	s.state.node = app.catalog.entry("nodes", "battle")
	s.state.node.visit_id = "test-selection-double-click"
	s.state.phase = "battle"
	s.state.battle = {
		"id": "biter",
		"hp": 28,
		"turn": 1,
		"ap": 3,
		"entry_hp": 40,
		"poison_until": 0,
		"fear_until": 0,
		"shields": [],
		"raft_target_cell": "cell-0",
		"intent": {"type":"biter_bite", "target_cell":"cell-0", "cell_damage":1}
	}
	s.give("wood", 2, false, "fixture")
	s.give("cloth", 1, false, "fixture")
	s.give("iron", 1, false, "fixture")
	
	app.render()
	await settle()
	
	var fan = app.find_child("hand_fan", true, false)
	assert(fan != null, "hand_fan must exist")
	var bview = app.find_child("BattleHUDView", true, false)
	assert(bview != null, "BattleHUDView must exist")
	
	print("--- TEST 1: Card Raised by 1/3 and Persistent Across Render ---")
	var wood_card: Dictionary = {}
	var cloth_card: Dictionary = {}
	for c in fan.cards:
		if c.id == "wood" and wood_card.is_empty(): wood_card = c
		elif c.id == "cloth" and cloth_card.is_empty(): cloth_card = c
	assert(not wood_card.is_empty(), "Wood card must be in fan")
	assert(not cloth_card.is_empty(), "Cloth card must be in fan")
	
	var card_h = fan.card_height
	var expected_raise = card_h / 3.0
	print("Card height: ", card_h, ", expected 1/3 raise: ", expected_raise)
	
	# Initial positions: unselected
	var wood_idx := -1
	for i in range(fan.cards.size()):
		if fan.cards[i].uid == wood_card.uid: wood_idx = i; break
	assert(wood_idx >= 0, "wood_idx must be found for wood_card.uid")
	var initial_target_y = fan.target_positions[wood_idx].y
	print("Initial unselected target_y for wood: ", initial_target_y)
	
	# Select wood
	bview.on_card_clicked(wood_card)
	await settle()
	
	fan = app.find_child("hand_fan", true, false)
	bview = app.find_child("BattleHUDView", true, false)
	wood_idx = -1
	for i in range(fan.cards.size()):
		if fan.cards[i].uid == wood_card.uid: wood_idx = i; break
	assert(wood_idx >= 0, "wood_idx must be found in updated fan")
	
	print("Debug after wood clicked:")
	print("  bview.selected_resource_uid: ", bview.selected_resource_uid)
	print("  app.ui_state.battle_selection: ", app.ui_state.get("battle_selection", ""))
	print("  fan.selected_uids: ", fan.selected_uids)
	print("  wood_card.uid: ", wood_card.uid)
	print("  fan.cards[wood_idx].uid: ", fan.cards[wood_idx].uid)
	var raised_target_y = fan.target_positions[wood_idx].y
	var diff_y = initial_target_y - raised_target_y
	print("Raised target_y for wood: ", raised_target_y, " (raised by ", diff_y, "px)")
	assert(absf(diff_y - expected_raise) < 1.0, "Selected card must be raised by card_height / 3.0! Expected: %f, got: %f" % [expected_raise, diff_y])
	assert(fan.selected_uids.has(wood_card.uid), "fan.selected_uids must contain wood_card.uid")
	
	# Re-render app to verify persistence
	print("Triggering explicit app.render() to check persistent selection...")
	app.render()
	await settle()
	
	fan = app.find_child("hand_fan", true, false)
	bview = app.find_child("BattleHUDView", true, false)
	wood_idx = -1
	for i in range(fan.cards.size()):
		if fan.cards[i].uid == wood_card.uid: wood_idx = i; break
	assert(wood_idx >= 0, "wood_idx must be found after re-render")
	
	var re_rendered_target_y = fan.target_positions[wood_idx].y
	var re_diff_y = initial_target_y - re_rendered_target_y
	print("Re-rendered target_y for wood: ", re_rendered_target_y, " (raised by ", re_diff_y, "px)")
	assert(fan.selected_uids.has(wood_card.uid), "After re-render, fan.selected_uids must STILL contain wood_card.uid!")
	assert(absf(re_diff_y - expected_raise) < 1.0, "After re-render, card must REMAIN raised by 1/3! Expected: %f, got: %f" % [expected_raise, re_diff_y])
	print("PASS: Card selection persists across render and stays raised by 1/3!")
	
	# Capture screenshot of wood raised by 1/3
	await RenderingServer.frame_post_draw
	var img1 = root.get_texture().get_image()
	img1.save_png("res://evidence/verify_card_raised_third.png")
	print("Saved verify_card_raised_third.png")
	
	# Deselect wood (click again)
	bview.on_card_clicked(wood_card)
	await settle()
	fan = app.find_child("hand_fan", true, false)
	bview = app.find_child("BattleHUDView", true, false)
	wood_idx = -1
	for i in range(fan.cards.size()):
		if fan.cards[i].uid == wood_card.uid: wood_idx = i; break
	assert(wood_idx >= 0, "wood_idx must be found after deselect")
	
	var deselected_target_y = fan.target_positions[wood_idx].y
	print("After clicking again, target_y for wood: ", deselected_target_y)
	assert(absf(deselected_target_y - initial_target_y) < 1.0, "Clicking again must deselect card and drop it back down!")
	assert(not fan.selected_uids.has(wood_card.uid), "fan.selected_uids must no longer contain wood_card.uid")
	print("PASS: Clicking again drops card back down!")
	
	print("\n--- TEST 2: Double-Click Quick Action with Invalid Combo Warning ---")
	# Select Cloth (which only supports block, NOT attack)
	bview.on_card_clicked(cloth_card)
	await settle()
	fan = app.find_child("hand_fan", true, false)
	bview = app.find_child("BattleHUDView", true, false)
	assert(bview.selected_resource_uid == str(cloth_card.uid), "Cloth should be selected")
	
	# Double-click "攻击" (Attack)
	var attack_card: Dictionary = {}
	var block_card: Dictionary = {}
	for c in fan.cards:
		if c.uid == "virtual_action_attack": attack_card = c
		elif c.uid == "virtual_action_block": block_card = c
	assert(not attack_card.is_empty(), "Attack card must exist in fan")
	assert(not block_card.is_empty(), "Block card must exist in fan")
	
	var initial_hp = int(s.state.battle.hp)
	var initial_ap = int(s.state.battle.ap)
	
	print("Double-clicking attack with invalid combo (Cloth + Attack)...")
	bview.on_action_double_clicked(attack_card)
	await settle()
	
	# Monster HP and AP must NOT change
	assert(int(s.state.battle.hp) == initial_hp, "Invalid combo must NOT deal damage! HP should remain: %d" % initial_hp)
	assert(int(s.state.battle.ap) == initial_ap, "Invalid combo must NOT consume AP! AP should remain: %d" % initial_ap)
	
	fan = app.find_child("hand_fan", true, false)
	bview = app.find_child("BattleHUDView", true, false)
	var summary_lbl: Label = bview.find_child("BattlePreviewSummary", true, false)
	assert(summary_lbl != null, "BattlePreviewSummary must exist")
	print("Invalid combo summary text: ", summary_lbl.text)
	assert(summary_lbl.text.begins_with("【无法出招】"), "Must display invalid combination alert prefix 【无法出招】")
	assert(summary_lbl.text.contains("无法与"), "Must display mismatch explanation: %s" % summary_lbl.text)
	print("PASS: Double-click with invalid combo blocked and displayed warning!")
	
	await RenderingServer.frame_post_draw
	var img2 = root.get_texture().get_image()
	img2.save_png("res://evidence/verify_invalid_combo_feedback.png")
	print("Saved verify_invalid_combo_feedback.png")
	
	print("\n--- TEST 3: Double-Click Quick Action with Valid Combo (Wood + Attack) ---")
	# Reset selection, select Wood
	bview.clear_selection()
	await settle()
	fan = app.find_child("hand_fan", true, false)
	bview = app.find_child("BattleHUDView", true, false)
	bview.on_card_clicked(wood_card)
	await settle()
	fan = app.find_child("hand_fan", true, false)
	bview = app.find_child("BattleHUDView", true, false)
	assert(bview.selected_resource_uid == str(wood_card.uid), "Wood should be selected")
	
	print("Double-clicking attack with valid combo (Wood + Attack)...")
	bview.on_action_double_clicked(attack_card)
	await settle()
	
	# Wood + Attack deals 1 damage + 1 base = 1 damage, Wood adds 1 shield
	# Let's check HP decreased and AP decreased by 1
	var after_hp = int(s.state.battle.hp)
	var after_ap = int(s.state.battle.ap)
	print("After valid combo: monster hp=", after_hp, " ap=", after_ap)
	assert(after_hp == initial_hp - 1, "Monster HP must decrease by 1! Expected: %d, got: %d" % [initial_hp - 1, after_hp])
	assert(after_ap == initial_ap - 1, "Player AP must decrease by 1! Expected: %d, got: %d" % [initial_ap - 1, after_ap])
	print("PASS: Valid combo executed immediately upon double-click!")
	
	await RenderingServer.frame_post_draw
	var img3 = root.get_texture().get_image()
	img3.save_png("res://evidence/verify_double_click_attack_success.png")
	print("Saved verify_double_click_attack_success.png")
	
	print("\n--- TEST 4: Double-Click Quick Action with Insufficient AP Warning ---")
	# Set battle AP to 0
	s.state.battle.ap = 0
	app.render()
	await settle()
	fan = app.find_child("hand_fan", true, false)
	bview = app.find_child("BattleHUDView", true, false)
	
	print("Double-clicking defense with AP = 0...")
	bview.on_action_double_clicked(block_card)
	await settle()
	
	summary_lbl = bview.find_child("BattlePreviewSummary", true, false)
	print("AP=0 summary text: ", summary_lbl.text)
	assert(summary_lbl.text.contains("战斗AP不足"), "Must display AP insufficient alert: %s" % summary_lbl.text)
	print("PASS: Double-click with 0 AP blocked and displayed warning!")
	
	print("\nALL CARD SELECTION 1/3 PERSISTENCE AND DOUBLE-CLICK QUICK ACTION TESTS PASSED!")
	quit(0)
