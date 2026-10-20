extends SceneTree
## Walk the mobile screens at 21:9 (2520x1080 physical -> 1680x720 logical) and capture each.
## Usage:
##   Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/capture_mobile_21x9.gd
##   ... -- --out=res://evidence/mobile-21x9-20261020 --jpg
## Writes numbered PNGs (or JPEGs with --jpg) plus a short SHOT log line per screen.
var app
var index := 0
var out_dir := "res://tmp/r219"
var as_jpg := false

func settle(frames: int = 5):
	for i in range(frames): await process_frame
	await RenderingServer.frame_post_draw

func shot(name: String):
	await RenderingServer.frame_post_draw
	index += 1
	var path := out_dir + "/%02d-%s.%s" % [index, name, "jpg" if as_jpg else "png"]
	var image: Image = root.get_texture().get_image()
	var err := image.save_jpg(path, 0.88) if as_jpg else image.save_png(path)
	print("SHOT ", path, " ok=", err == OK, " size=", root.size, " logical=", root.get_visible_rect().size)

func _init():
	call_deferred("run")

## restore() parks the session on the home screen; walking a fixture needs game screen.
func resume_game():
	app.session.screen = "game"
	app.session.panel = ""
	app.local_panel = ""

func event_fixture(node_id: String, step: String, result_text: String = ""):
	app.session.state.node = app.catalog.entry("nodes", node_id).duplicate(true)
	app.session.state.node.visit_id = "cap-21x9-" + node_id
	app.session.Encounter.arrived(app.session)
	app.session.state.phase = "story"
	app.session.state.story_step = step
	app.session.panel = "story"
	app.session.state.result_text = result_text if result_text != "" else "你获得了一些物资，也失去了一点勇气。"
	app.render()
	await settle()

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_dir = arg.trim_prefix("--out=")
		if arg == "--jpg": as_jpg = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(2520, 1080)
	app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await settle()
	app.display_settings.mobile = true
	app.display_settings.ui_scale = 1.25
	app.display_settings.free_aspect = true
	app.apply_display_settings(false)
	await settle()

	await shot("home")
	app.setup_mode = "challenge"; app.render(); await settle()
	await shot("new-game")
	app.setup_mode = ""

	app.handle_command("new", {"mode": "challenge", "difficulty": "standard", "origin": "strong", "seed": 22})
	await settle()
	for id in ["wood", "plastic"]:
		app.session.give(id, 1, false, "cap")
	# A typical mid-run hand: 9 cards against a 12 capacity, so the badge is legal.
	app.session.state.player.limit = maxi(12, app.session.state.hand.size())
	app.render(); await settle()
	await shot("navigation")

	app.session.dispatch("voyage", {"id": app.session.view().candidates[0].visit_id})
	app.session.state.ap = 6
	app.render(); await settle()
	var preparation: Dictionary = app.session.snapshot()
	await shot("preparation")

	await event_fixture("drift", "intro"); await shot("event-intro")
	await event_fixture("drift", "choice")
	var choice_page = app.find_child("NodeEventBody", true, false)
	print("EVENT choice entries=", choice_page.entries.size())
	await shot("event-choice")
	var page = app.find_child("NodeEventBody", true, false)
	var usable: Array = page.entries.filter(func(e): return not e.button.disabled)
	if not usable.is_empty():
		page.press(usable[0]); await settle()
		await shot("event-preselect")
		page.set_preselect(""); await settle()
	await event_fixture("drift", "result"); await shot("event-result")

	# Shop
	app.session.restore(preparation); resume_game(); app.session.state.coins = 120
	app.session.state.node = app.catalog.entry("nodes", "trader").duplicate(true)
	app.session.state.node.visit_id = "cap-21x9-shop"
	app.session.state.phase = "story"; app.session.state.story_step = "choice"; app.session.state.panel = "story"
	app.session.give("corpse", 1, false, "cap")
	app.render(); await settle()
	app.request_command("shop_enter"); await settle(8)
	await shot("shop-buy")
	var sell_tab = app.find_child("ShopSellTab", true, false)
	if sell_tab != null: sell_tab.pressed.emit(); await settle()
	await shot("shop-sell")

	# Battle
	app.session.restore(preparation); resume_game()
	var state: Dictionary = app.session.state
	state.node = app.catalog.entry("nodes", "battle").duplicate(true)
	state.node.visit_id = "cap-21x9-battle"
	state.phase = "battle"
	state.battle = {"id": "biter", "hp": 18, "turn": 1, "ap": 3, "entry_hp": 18, "poison_until": 0, "fear_until": 0,
		"shields": [], "raft_target_cell": state.cells[0].id,
		"intent": {"type": "biter_bite", "target_cell": state.cells[0].id, "cell_damage": 1}}
	app.render(); await settle()
	await shot("battle")
	var battle_view = app.find_child("BattleHUDView", true, false)
	var fan = app.find_child("hand_fan", true, false)
	if battle_view != null and fan != null:
		var actions: Array = fan.cards.filter(func(c): return str(c.uid).begins_with("virtual_action"))
		if not actions.is_empty():
			battle_view.on_card_clicked(actions[0]); await settle()
			await shot("battle-selected")

	# Panels
	app.session.restore(preparation); resume_game()
	app.session.state.player.limit = 12
	app.render(); await settle()
	app.handle_command("panel", {"id": "craft"}); await settle(8)
	await shot("craft")
	var transmute_tab = app.find_child("TransmuteTabButton", true, false)
	if transmute_tab != null:
		transmute_tab.pressed.emit(); await settle(8)
		var mat = app.find_child("MatItem_wood", true, false)
		if mat != null:
			var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
			mat.gui_input.emit(event); await settle()
		var target = app.find_child("SelectTarget_plastic", true, false)
		if target != null: target.pressed.emit(); await settle(6)
		await shot("transmute")
	app.handle_command("close"); await settle()

	app.handle_command("panel", {"id": "collectibles"}); await settle(8)
	await shot("warehouse")
	app.handle_command("close"); await settle()

	# 图鉴只在首页开放，局内打开会得到“当前阶段没有这个入口”。
	app.handle_command("home"); await settle()
	app.handle_command("panel", {"id": "encyclopedia"}); await settle(8)
	await shot("encyclopedia")
	app.handle_command("close"); await settle()

	app.handle_ui("local_panel", "settings"); await settle(8)
	await shot("settings")
	app.handle_ui("local_panel", ""); await settle()

	print("CAPTURE DONE ", index)
	app.queue_free()
	await settle()
	quit(0)
