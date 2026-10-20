extends SceneTree
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void:
	call_deferred("run"); call_deferred("watchdog")
func watchdog() -> void:
	await create_timer(30).timeout; printerr("SURVIVAL UI timeout"); quit(2)
func wait_for_input(app) -> void:
	var frames := 0
	while (app.transition_busy or app._ui_command_pending) and frames < 240:
		if is_instance_valid(app.acquisition_overlay) and not app.acquisition_overlay.collecting:
			app.acquisition_overlay.collect()
		await process_frame
		frames += 1
	check(not app.transition_busy and not app._ui_command_pending,"voyage transition and acquisition finish before next input")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("FAIL: survival UI requires a graphical run"); quit(1); return
	Engine.max_fps=60
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	for size in [Vector2i(1280,720),Vector2i(1600,900)]:
		if app.session.active(): app.handle_command("abandon")
		root.size=size
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
		var s=app.session
		app.handle_command("voyage",{"id":s.state.candidates[0].visit_id})
		check(s.state.player.hunger==20 and s.state.player.hydration==20 and s.state.player.sanity==65 and s.state.player.hp==16,"UI departure charges food, water and SAN together")
		s.state.phase="aftermath"; s.state.hand=[]; app.render()
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://evidence/survival-departure-20261021/direct-before-%dx%d.png" % [size.x,size.y]) == OK,"save current survival UI evidence")
		var buttons=app.find_children("*","Button",true,false).filter(func(b):return b.text=="结束航行")
		check(buttons.size()==1,"end voyage button visible")
		if buttons.size()!=1: quit(1); return
		check(app.get_global_rect().encloses(buttons[0].get_global_rect()),"button fits viewport")
		buttons[0].pressed.emit()
		await process_frame; await process_frame
		await wait_for_input(app)
		check(s.state.player.hunger==20 and s.state.player.hydration==20 and s.state.player.hp==16 and s.state.player.sanity==65 and s.state.voyage==2,"real end-voyage button never charges survival again")
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://evidence/survival-departure-20261021/direct-after-%dx%d.png" % [size.x,size.y]) == OK,"save current survival UI evidence")
	app.queue_free(); await process_frame
	print("SURVIVAL UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
