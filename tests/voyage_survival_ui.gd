extends SceneTree
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void:
	call_deferred("run"); call_deferred("watchdog")
func watchdog() -> void:
	await create_timer(30).timeout; printerr("SURVIVAL UI timeout"); quit(2)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	for size in [Vector2i(1280,720),Vector2i(1600,900)]:
		if app.session.active(): app.handle_command("abandon")
		root.size=size
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
		var s=app.session
		app.handle_command("voyage",{"id":s.state.candidates[0].visit_id})
		check(s.state.player.hunger==40 and s.state.player.hp==16,"UI departure preserves survival")
		s.state.phase="aftermath"; s.state.hand=[]; app.render()
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/survival-v17-before-%dx%d.png" % [size.x,size.y])
		var buttons=app.find_children("*","Button",true,false).filter(func(b):return b.text=="结束航行")
		check(buttons.size()==1,"end voyage button visible")
		if buttons.size()!=1: quit(1); return
		check(app.get_global_rect().encloses(buttons[0].get_global_rect()),"button fits viewport")
		buttons[0].pressed.emit()
		await process_frame; await process_frame
		check(s.state.player.hunger==10 and s.state.player.hydration==10 and s.state.player.hp==16 and s.state.voyage==2,"real button settles food water once")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/survival-v17-after-%dx%d.png" % [size.x,size.y])
	app.queue_free(); await process_frame
	print("SURVIVAL UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
