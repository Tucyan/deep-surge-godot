extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures += 1; printerr("FAIL: " + why)
func settle():
	for i in range(6): await process_frame
func run():
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false; root.add_child(app); await settle()
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":22})
	app.display_settings.camera_orbit_button = MOUSE_BUTTON_MIDDLE
	app.display_settings.camera_pan_button = MOUSE_BUTTON_RIGHT
	app.display_settings.camera_reset_key = KEY_F
	for mobile in [false, true]:
		app.display_settings.mobile = mobile
		root.size = Vector2i(960,540) if mobile else Vector2i(1280,720)
		root.content_scale_factor = 1.25 if mobile else 1.0
		await settle(); app.render(); await settle()
		var before: Dictionary = app.session.snapshot()
		var entry = app.find_child("GameHelpEntry",true,false)
		check(is_instance_valid(entry), "question mark has discoverable game help entry")
		if is_instance_valid(entry): entry.pressed.emit()
		else: app.handle_ui("local_panel", "help")
		await settle()
		var tabs = app.find_child("GameHelpTabs",true,false) as TabContainer
		check(is_instance_valid(tabs), "question mark opens categorized guide")
		if is_instance_valid(tabs):
			check(tabs.get_tab_count()==3, "phone, computer and game flow are available")
			check(tabs.get_tab_bar().size.y >= (56 if mobile else 44), "tabs have comfortable click and touch height")
			check(tabs.current_tab==(0 if mobile else 1), "defaults to current device")
			for i in range(3):
				tabs.current_tab=i; await settle()
				var scroll = tabs.get_child(i) as ScrollContainer
				check(scroll!=null, "each guide scrolls")
				if scroll==null: continue
				var bounds = Rect2(Vector2.ZERO, app.size).grow(1)
				check(bounds.encloses(tabs.get_global_rect()), "guide fits viewport")
				check(scroll.get_child(0).size.x<=scroll.size.x+1, "guide wraps without horizontal overflow")
				var bar = scroll.get_v_scroll_bar()
				scroll.scroll_vertical=int(bar.max_value); await settle()
				var last = scroll.get_child(0).get_children().back() as Control
				check(last.get_global_rect().end.y<=scroll.get_global_rect().end.y+2,"last instruction is reachable")
				if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
					scroll.scroll_vertical=0; await settle(); await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://evidence/game-help-%s-%d.png" % ["mobile" if mobile else "desktop",i])
			var desktop_text := ""
			for label in tabs.get_child(1).find_children("*","Label",true,false): desktop_text+=label.text
			check("中键" in desktop_text and "右键" in desktop_text and "F" in desktop_text,"computer instructions reflect customized bindings")
		var close = app.find_child("ModalSurface",true,false).find_child("CloseX",true,false)
		check(Rect2(Vector2.ZERO,app.size).grow(1).encloses(close.get_global_rect()),"close button stays on screen")
		close.pressed.emit(); await settle()
		check(app.local_panel=="", "guide can return to game")
		check(app.session.snapshot()==before, "reading, switching and closing guide preserve gameplay and RNG")
	app.queue_free(); await process_frame
	print("GAME HELP: " + ("PASS" if failures==0 else "FAIL")); quit(failures)
