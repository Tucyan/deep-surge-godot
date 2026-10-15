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
	s.state.node.visit_id = "test-battle-new-ui"
	s.state.phase = "battle"
	s.state.battle = {
		"id": "biter",
		"hp": 28,
		"turn": 1,
		"ap": 3,
		"entry_hp": 40,
		"poison_until": 0,
		"fear_until": 0,
		"shields": [{"uid":"s1", "source":"木盾", "amount":2, "expires_turn":1}],
		"raft_target_cell": "cell-0",
		"intent": {"type":"biter_bite", "target_cell":"cell-0", "cell_damage":1}
	}
	s.give("wood", 2, false, "fixture")
	s.give("iron", 1, false, "fixture")
	s.give("rope", 1, false, "fixture")
	
	app.render()
	await settle()
	
	# Assert layout existence
	var backdrop = app.find_child("BattleBackdrop", true, false)
	assert(backdrop != null, "BattleBackdrop must exist over ocean/raft")
	
	var monster_panel = app.find_child("MonsterPanel", true, false)
	assert(monster_panel != null, "Yellow MonsterPanel must exist")
	
	var action_panel = app.find_child("ActionPreviewPanel", true, false)
	assert(action_panel != null, "Red ActionPreviewPanel must exist")
	
	var log_panel = app.find_child("CombatLogPanel", true, false)
	assert(log_panel != null, "Blue CombatLogPanel must exist")
	
	var attack_btn = app.find_child("BattleAttack", true, false)
	var block_btn = app.find_child("BattleBlock", true, false)
	assert(attack_btn != null, "Hand must contain BattleAttack fixed card")
	assert(block_btn != null, "Hand must contain BattleBlock fixed card")
	
	var confirm_btn = app.find_child("ConfirmBattleAction", true, false)
	assert(confirm_btn != null, "Bottom right confirm button must exist")
	print("Initial confirm button disabled: ", confirm_btn.disabled)
	assert(confirm_btn.disabled == true, "Confirm button should be disabled when nothing selected")
	
	# Capture initial battle scene
	await RenderingServer.frame_post_draw
	var img1 = root.get_texture().get_image()
	img1.save_png("res://evidence/verify_battle_initial.png")
	print("Saved verify_battle_initial.png")
	
	# Select Wood resource and Attack card
	var bview = app.find_child("BattleHUDView", true, false)
	assert(bview != null, "BattleHUDView must exist")
	
	var wood_card = s.state.hand.filter(func(c): return c.id == "wood")[0]
	bview.on_card_clicked(wood_card)
	await settle()
	
	confirm_btn = app.find_child("ConfirmBattleAction", true, false)
	print("After wood selected: confirm disabled=", confirm_btn.disabled)
	assert(confirm_btn.disabled == true, "Selecting only wood is incomplete combo, must be disabled")
	
	bview = app.find_child("BattleHUDView", true, false)
	var attack_card = {"uid": "virtual_action_attack", "id": "action_attack", "action_id": "attack"}
	bview.on_card_clicked(attack_card)
	await settle()
	
	confirm_btn = app.find_child("ConfirmBattleAction", true, false)
	print("After attack selected: confirm disabled=", confirm_btn.disabled)
	assert(confirm_btn.disabled == false, "Wood + Attack is valid combo, confirm must be enabled!")
	
	# Capture selected / combo preview scene
	await RenderingServer.frame_post_draw
	var img2 = root.get_texture().get_image()
	img2.save_png("res://evidence/verify_battle_combo_selected.png")
	print("Saved verify_battle_combo_selected.png")
	
	# Click Confirm (迎击)
	confirm_btn.pressed.emit()
	await settle()
	
	print("After attack executed: monster hp=", s.state.battle.hp, " player battle ap=", s.state.battle.ap)
	assert(s.state.battle.hp < 28, "Monster should take damage")
	assert(s.state.battle.ap == 2, "AP should be spent")
	
	# Capture after attack scene
	await RenderingServer.frame_post_draw
	var img3 = root.get_texture().get_image()
	img3.save_png("res://evidence/verify_battle_after_attack.png")
	print("Saved verify_battle_after_attack.png")
	
	print("ALL BATTLE NEW UI TESTS PASSED SUCCESSFULLY!")
	app.queue_free()
	quit(0)
