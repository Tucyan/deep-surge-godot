extends SceneTree
var app
var failures := 0
func check(ok: bool, why: String):
	if not ok: failures += 1; printerr("FAIL "+why)
func _init(): call_deferred("run")
func settle():
	await process_frame; await process_frame
func shot(id):
	await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/supplied-hud-"+id+".png")
func panel(): return app.layout.find_child("SurgeEventChoicePanel",true,false)
func run():
	root.size = Vector2i(1600,900)
	app = load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"story","origin":"fool","seed":22}); await settle()
	var stat = app.layout.find_child("SurgeStatusHUD",true,false)
	var ap = app.layout.find_child("SurgeActionPointHUD",true,false)
	check(stat.health==app.session.state.player.hp and stat.satiety==app.session.state.player.hunger,"HUD binds real stats")
	check(ap.current_ap==app.session.state.ap and ap.max_ap==app.session.state.player.base_ap,"HUD binds actual AP")
	check(panel()==null,"event panel absent before entering node")
	var before = app.session.snapshot()
	stat.queue_redraw(); ap.queue_redraw(); await settle()
	check(app.session.snapshot()==before,"draw does not mutate rules/RNG")
	await shot("navigation")
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.handle_command("enter"); await settle()
	check(panel()!=null,"conditional story panel")
	await shot("intro")
	var p = panel(); p._list.get_child(0).pressed.emit(); await settle()
	check(app.session.state.story_step=="choice","native button advances real story")
	await shot("choice")
	for resolution in [Vector2i(1600,900),Vector2i(1280,720)]:
		root.size=resolution; await settle()
		var bounds = app.get_global_rect().grow(2)
		for b in panel()._list.get_children():
			if b is Control: check(bounds.encloses(b.get_global_rect()),"choice controls inside viewport")
	await shot("choice-1280")
	p=panel()
	var disabled_snapshot=app.session.snapshot(); p.choice_disabled[0]=1; p._refresh(); p._list.get_child(0).pressed.emit(); await settle()
	check(app.session.snapshot()==disabled_snapshot,"disabled choice cannot dispatch")
	p=panel(); p.choice_disabled[0]=0; p._refresh(); p._list.get_child(0).pressed.emit(); await settle()
	check(app.session.snapshot()!=disabled_snapshot and app.message=="","native choice dispatches actual option ID")
	check(app.find_children("*","ScrollContainer",true,false).is_empty(),"no scroll containers")
	app.queue_free(); await process_frame; print("SUPPLIED HUD INTEGRATION: PASS" if failures==0 else "SUPPLIED HUD INTEGRATION: FAIL"); quit(0 if failures==0 else 1)
