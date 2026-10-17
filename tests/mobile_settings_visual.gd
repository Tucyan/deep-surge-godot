extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle():
	for i in range(5): await process_frame
func run():
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.display_settings.mobile=true; app.display_settings.ui_scale=1.25; app.display_settings.free_aspect=true
	app.apply_display_settings(false)
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_ui("local_panel","settings")
	for resolution in [Vector2i(1260,540),Vector2i(1680,720),Vector2i(2520,1080),Vector2i(960,540)]:
		root.size=resolution; await settle()
		for tab in ["display","game","narrative"]:
			app.settings_tab=tab; app.render(); await settle()
			var scroll=app.find_child("MobileSettingsScroll",true,false)
			var surface=app.find_child("ModalSurface",true,false)
			check(app.get_global_rect().grow(2).encloses(surface.get_global_rect()),"settings fit screen %s %s" %[resolution,tab])
			check(scroll.size.y>40,"scroll body remains usable")
			check(app.find_child("TabGame",true,false).size.y>=44,"tabs have touch target")
			scroll.scroll_vertical=10000; await settle()
			var last=app.find_child("HandGestureHelp",true,false)
			if tab=="game": check(scroll.get_global_rect().grow(2).encloses(last.get_global_rect()),"gesture help reachable by scrolling")
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://evidence/mobile-settings-%dx%d-%s.png" %[resolution.x,resolution.y,tab])==OK,"save mobile screenshot")
	app.queue_free(); await settle()
	print("MOBILE SETTINGS VISUAL: "+("PASS" if failures==0 else "FAIL")); quit(failures)
