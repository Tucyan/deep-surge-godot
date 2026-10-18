extends SceneTree
## GPU inspection of shared text buttons in real pages and pointer states.
const W = preload("res://presentation/widgets.gd")
var app
var failures := 0
var audited := 0
var capture := false
var mobile := false

func _init() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	mobile = "--mobile" in OS.get_cmdline_user_args()
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for i in range(5): await process_frame

func shot(id: String) -> void:
	await settle()
	for button in app.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree() or button.get_class() != "Button": continue
		audited += 1
		# Flat recipe icons intentionally use their child texture as the full skin.
		var image_skin: bool = button.flat and button.get_children().any(func(child): return child is TextureRect and child.texture!=null)
		check(button.has_node("SurgeTextButtonArt") or button.has_theme_stylebox_override("normal") or image_skin, "Button has supplied or dedicated skin: " + button.text)
		var fits: bool=app.get_global_rect().grow(2).encloses(button.get_global_rect())
		if mobile and not fits:
			var ancestor=button.get_parent()
			while ancestor!=null and not ancestor is ScrollContainer: ancestor=ancestor.get_parent()
			if ancestor is ScrollContainer:
				var previous: int=ancestor.scroll_vertical
				ancestor.scroll_vertical+=int(button.get_global_rect().end.y-ancestor.get_global_rect().end.y)
				await settle()
				fits=ancestor.get_global_rect().grow(2).encloses(button.get_global_rect())
				ancestor.scroll_vertical=previous;await settle()
		check(fits, "Button fits screen or is reachable by scrolling: " + id + " / " + button.text)
	if capture:
		await RenderingServer.frame_post_draw
		var capture_id:= "mobile-"+id if mobile and not id.contains("mobile-") else id
		root.get_texture().get_image().save_png("res://evidence/text-buttons-" + capture_id + ".png")

func run() -> void:
	var configs := [Vector3(1260,540,1.25), Vector3(1280,720,1.25), Vector3(1680,720,1)] if mobile else [Vector3(1280,720,1), Vector3(1280,720,1.25), Vector3(1600,900,1)]
	for config in configs:
		app = load("res://scenes/main.tscn").instantiate()
		app.persistence = false
		root.add_child(app)
		await settle()
		root.size = Vector2i(config.x, config.y)
		app.display_settings.mobile = mobile
		app.display_settings.free_aspect = true
		app.display_settings.ui_scale = config.z
		app.apply_display_settings(false)
		var suffix := ("mobile-" if mobile else "") + "%dx%d-%d" % [config.x,config.y,roundi(config.z*100)]
		app.handle_command("home")
		app.handle_ui("setup", "challenge")
		await shot("setup-" + suffix)
		var difficulty = app.current_page.find_child("DifficultyChoice", true, false)
		difficulty.select(1); difficulty.item_selected.emit(1)
		app.current_page.find_child("NewGameNext", true, false).pressed.emit()
		await shot("resources-" + suffix)
		app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":22})
		check(app.session.screen == "game", "Fresh fixture starts a real game")
		app.world_view.motion = false
		await shot("voyage-" + suffix)
		var before: Dictionary = app.session.snapshot()
		app.handle_ui("local_panel", "settings")
		await shot("settings-" + suffix)
		app.settings_tab = "game"; app.render()
		await shot("preferences-" + suffix)
		app.handle_ui("local_panel", "")
		for id in ["craft", "raft"]:
			app.handle_command("panel", {"id":id})
			await shot(id + "-" + suffix)
			if id == "craft":
				app.handle_ui("craft_tab", "transmute")
				await shot("transmute-" + suffix)
			app.handle_command("close")
		check(app.session.state == before.state, "Viewing buttons leaves rules and RNG unchanged")
		# Isolated trader fixture, following node_shop_visual.gd; no player saves.
		app.session.state.node = app.catalog.entry("nodes", "trader")
		app.session.state.node.visit_id = "text-button-trader-fixture"
		app.session.state.node.erase("variants")
		app.session.state.phase = "story"; app.session.state.story_step = "choice"
		app.session.state.candidates = []; app.session.Encounter.arrived(app.session)
		app.session.screen = "game"; app.session.panel = "story"; app.render()
		app.handle_command("shop_enter")
		await shot("shop-" + suffix)
		var shop_page = app.current_page
		check(shop_page.get_script() == load("res://pages/shop_page.gd"), "Trader fixture opens formal shop")
		if shop_page.get_script() == load("res://pages/shop_page.gd"):
			var stock: Array = shop_page.context.get("shop", {}).get("stock", [])
			if not stock.is_empty():
				var before_quote: Dictionary = app.session.snapshot()
				shop_page.select_buy(stock[0]); await settle()
				for button in [shop_page.confirmation.get_ok_button(), shop_page.confirmation.get_cancel_button()]:
					check(button.has_node("SurgeTextButtonArt"), "Native trade dialog button uses supplied artwork")
					check(Rect2(Vector2.ZERO, Vector2(shop_page.confirmation.size)).encloses(button.get_global_rect()), "Trade confirmation button fits its dialog")
				check(app.session.snapshot() == before_quote, "Opening trade confirmation preserves state and RNG")
				if capture:
					await RenderingServer.frame_post_draw
					shop_page.confirmation.get_texture().get_image().save_png("res://evidence/text-buttons-buy-confirm-" + suffix + ".png")
				shop_page.cancel_selection()
		# Same battle-only presentation fixture used by test_battle_panel_art.gd.
		app.session.panel = ""
		app.session.state.node = app.catalog.entry("nodes", "battle")
		app.session.state.node.visit_id = "text-button-battle-fixture"
		app.session.state.phase = "battle"
		app.session.state.battle = {"id":"biter", "hp":6, "turn":1, "ap":3, "entry_hp":40, "shields":[], "raft_target_cell":"cell-0", "intent":{"type":"biter_bite", "target_cell":"cell-0"}}
		app.render()
		await shot("battle-" + suffix)
		app.handle_command("home")
		for id in ["encyclopedia", "meta_shop"]:
			app.handle_command("panel", {"id":id})
			await shot(id + "-" + suffix)
			app.handle_command("close")
		app.queue_free()
		await settle()
	# A real pointer checks hover, held press, release, keyboard focus and disable.
	app = Control.new(); root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.theme = W.theme()
	var box := VBoxContainer.new(); app.add_child(box)
	box.position = Vector2(100,100); box.size = Vector2(640,320)
	W.text(box, "深潮文字按钮 · 原生交互四态", 26)
	var clicks := [0]
	var live := W.button(box, "确认行动", func(): clicks[0] += 1)
	W.button(box, "暂不可用", func(): clicks[0] += 100, true, "保留原禁用原因")
	var row := HBoxContainer.new(); box.add_child(row)
	for label in ["−", "+", "X"]: W.button(row, label, func(): pass)
	await settle()
	var point: Vector2 = root.get_final_transform() * live.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
	Input.parse_input_event(motion); await settle()
	check(live.is_hovered(), "Decorative artwork does not intercept hover")
	await shot("hover-and-disabled")
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true; press.position = point; press.global_position = point
	Input.parse_input_event(press); await settle()
	check(live.is_pressed(), "Native button receives held press")
	await shot("pressed")
	press = press.duplicate(); press.pressed = false; Input.parse_input_event(press)
	await settle()
	check(clicks[0] == 1, "Release invokes original callback exactly once")
	live.grab_focus(); check(live.has_focus(), "Keyboard focus remains available")
	await shot("focus")
	app.queue_free(); await process_frame
	print("TEXT BUTTONS GPU: %s (%d visible button checks)" % ["PASS" if failures == 0 else "FAIL", audited])
	quit(failures)
