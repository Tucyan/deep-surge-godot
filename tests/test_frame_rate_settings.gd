extends SceneTree
const VALUES := [30,60,90,120,0]
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func run() -> void:
	var script=load("res://presentation/display_settings.gd")
	var prefs=script.new(false)
	if not prefs.get_property_list().any(func(p):return p.name=="fps_limit"):
		check(false,"Missing persistent frame-rate limit preference"); quit(1); return
	check(prefs.fps_limit==60,"Default limit is 60 FPS")
	var old_cap: int=Engine.max_fps
	prefs.path="user://frame-rate-test.cfg"
	for limit in VALUES:
		prefs.fps_limit=limit; prefs.apply_window(root,false)
		check(Engine.max_fps==limit,"Frame cap applies immediately: "+str(limit))
		check(prefs.save_preferences()==OK,"Frame cap saves")
		var restored=script.new(true); restored.path=prefs.path; restored.load_preferences()
		check(restored.fps_limit==limit,"Mobile and desktop retain cap after reload")
	var config:=ConfigFile.new(); config.save(prefs.path)
	var legacy=script.new(false); legacy.path=prefs.path; legacy.load_preferences()
	check(legacy.fps_limit==60,"Old preferences without a cap use default")
	for invalid in [-1,45,240,"60",true]:
		config.set_value("display","fps_limit",invalid); config.save(prefs.path)
		var restored=script.new(false); restored.path=prefs.path; restored.load_preferences()
		check(restored.fps_limit==60,"Malformed or unsupported limits use valid default")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.path))
	root.size=Vector2i(1280,720)
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_ui("local_panel","settings"); await settle()
	var before: Dictionary=app.session.snapshot()
	for mobile in [false,true]:
		app.display_settings.mobile=mobile
		app.display_settings.ui_scale=1.25; app.apply_display_settings(false); await settle()
		for index in range(VALUES.size()):
			var selector=app.find_child("FrameRateLimit",true,false)
			check(selector is OptionButton,"Both platforms expose frame cap selector")
			if selector==null: continue
			check(selector.item_count==5 and selector.get_item_text(4)=="无限制","Exactly five frame-rate options")
			selector.item_selected.emit(index); await settle()
			check(Engine.max_fps==VALUES[index] and app.display_settings.fps_limit==VALUES[index],"Selector binds immediately to engine frame cap")
			check(app.find_child("FrameRateLimit",true,false).selected==index,"Selected frame limit survives UI rebuild")
			if DisplayServer.get_name()!="headless": check(DisplayServer.window_get_vsync_mode(root.get_window_id())==DisplayServer.VSYNC_DISABLED,"VSync does not silently override selected cap")
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/settings-fps-%s-125.png" % ("mobile" if mobile else "desktop"))
	check(app.session.snapshot()==before,"Frame cap leaves game rules and RNG untouched")
	app.queue_free(); root.content_scale_factor=1.0; Engine.max_fps=old_cap; await process_frame
	print("FRAME RATE SETTINGS: "+("PASS" if failures==0 else "FAIL")); quit(failures)
