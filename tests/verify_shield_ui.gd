extends SceneTree

func settle():
	await process_frame; await process_frame

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
	s.state.node.visit_id = "test-shield-ui"
	s.state.phase = "battle"
	# Initial battle: 2 points break next turn (expires_turn: 1), 1 point persists (expires_turn: 2)
	s.state.battle = {
		"id": "biter",
		"hp": 28,
		"turn": 1,
		"ap": 3,
		"entry_hp": 40,
		"poison_until": 0,
		"fear_until": 0,
		"shields": [
			{"uid":"s1", "source":"木盾", "amount":2, "expires_turn":1},
			{"uid":"s2", "source":"骨片", "amount":1, "expires_turn":2}
		],
		"raft_target_cell": "cell-0",
		"intent": {"type":"biter_bite", "target_cell":"cell-0", "cell_damage":1}
	}
	s.give("wood", 2, false, "fixture")
	s.give("iron", 1, false, "fixture")
	
	app.render()
	await settle()
	
	# 1. Assert shield badge on card topbar far right
	var topbar = app.find_child("VoyageHandTopBar", true, false)
	assert(topbar != null, "VoyageHandTopBar must exist")
	
	var shield_badge = app.find_child("BattleShieldSummary", true, false)
	assert(shield_badge != null, "BattleShieldSummary must exist on topbar")
	assert(shield_badge.get_parent() == topbar, "BattleShieldSummary must be a child of VoyageHandTopBar")
	
	var ShieldIconClass = preload("res://presentation/shield_icon.gd")
	var icons: Array = []
	for child in shield_badge.find_children("*", "Control", true, false):
		if child.get_script() == ShieldIconClass:
			icons.append(child)
	
	assert(icons.size() == 3, "There must be 3 shield icons for 3 points of shield (1 icon per 1 shield)")
	var dashed_count := 0
	var solid_count := 0
	for icon in icons:
		if icon.is_dashed: dashed_count += 1
		else: solid_count += 1
	assert(dashed_count == 2, "2 icons expiring next turn must be dashed")
	assert(solid_count == 1, "1 icon persisting must be solid")
	print("Verified shield icons: total=", icons.size(), " dashed (breaks next turn)=", dashed_count, " solid=", solid_count)
	
	# 2. Assert complete removal of ShieldBackdrop (no blue overlay or shatter backdrop)
	var shield_backdrop = app.find_child("ShieldBackdrop", true, false)
	assert(shield_backdrop == null, "ShieldBackdrop must be completely removed from the scene tree!")
	var topbar_style: StyleBoxFlat = topbar.get_theme_stylebox("panel")
	assert(topbar_style.bg_color == Color(0.025, 0.055, 0.08, 0.88), "Topbar bg_color must remain default solid dark, not blue translucent")
	print("Verified: ShieldBackdrop is completely removed and topbar has clean solid background.")
	
	# Capture shield active evidence
	await RenderingServer.frame_post_draw
	var img1 = root.get_texture().get_image()
	img1.save_png("res://evidence/verify_shield_active.png")
	print("Saved verify_shield_active.png")
	
	# 3. Test Empty shield state (0 shields)
	s.state.battle.shields = []
	app.render()
	await settle()
	
	var shield_badge_empty = app.find_child("BattleShieldSummary", true, false)
	assert(shield_badge_empty != null, "BattleShieldSummary must still exist on topbar")
	var empty_icons: Array = []
	for child in shield_badge_empty.find_children("*", "Control", true, false):
		if child.get_script() == ShieldIconClass:
			empty_icons.append(child)
	assert(empty_icons.size() == 1 and empty_icons[0].is_empty_shield == true, "Empty shield state must show empty slot icon")
	assert(app.find_child("ShieldBackdrop", true, false) == null, "ShieldBackdrop must remain null in 0 shield state")
	print("Verified empty shield state with no blue effects.")
	
	await RenderingServer.frame_post_draw
	var img2 = root.get_texture().get_image()
	img2.save_png("res://evidence/verify_shield_empty.png")
	print("Saved verify_shield_empty.png")
	
	print("ALL CLEAN SHIELD UI & MULTI-ICON VERIFICATIONS PASSED!")
	quit(0)
