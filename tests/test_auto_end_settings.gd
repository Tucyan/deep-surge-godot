extends SceneTree
var failures:=0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func run():
	root.size=Vector2i(1280,720)
	var prefs=load("res://presentation/display_settings.gd").new()
	check(prefs.auto_end_voyage,"auto-end defaults to enabled")
	prefs.path="user://test-auto-end-settings.cfg"; prefs.auto_end_voyage=false
	check(prefs.save_preferences()==OK,"save preference")
	var restored=load("res://presentation/display_settings.gd").new()
	restored.path=prefs.path; restored.load_preferences()
	check(not restored.auto_end_voyage,"preference survives reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.path))
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	app.settings_tab="game"; app.handle_ui("local_panel","settings"); await process_frame
	var toggle=app.find_child("AutoEndVoyageToggle",true,false)
	check(is_instance_valid(toggle) and toggle.button_pressed,"game settings contains enabled checkbox")
	if not is_instance_valid(toggle): app.queue_free(); quit(1); return
	if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
		await create_timer(.3).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/auto-end-settings.png")
	toggle.button_pressed=false; await process_frame
	check(not app.display_settings.auto_end_voyage and not app.session.auto_end_voyage,"toggle applies immediately")
	app.handle_ui("local_panel","")
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	check(not app.session.auto_end_voyage,"new session retains local preference")
	app.handle_ui("local_panel","settings"); await process_frame
	check(not app.find_child("AutoEndVoyageToggle",true,false).button_pressed,"reopened settings reflects disabled preference")
	if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
		await create_timer(.3).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/auto-end-settings-game.png")
	app.handle_ui("local_panel","")
	app.session.state.phase="story"; app.session.state.story_step="result"; app.session.state.ap=0
	app.session.state.hand=[]; app.session.state.coins=0
	app.request_command("advance")
	check(not app.transition_busy and app.session.phase()=="aftermath","disabled preference waits for manual end")
	app.request_command("end_voyage")
	check(app.transition_busy,"manual end still animates when auto-end disabled")
	await create_timer(2.0).timeout
	check(app.session.state.voyage==2 and not app.transition_busy,"manual end finishes once")
	app.queue_free(); await process_frame
	print("AUTO END SETTINGS: "+("PASS" if failures==0 else "FAIL")); quit(failures)
