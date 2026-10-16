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
	root.get_texture().get_image().save_png("res://evidence/environment-hud-v12-"+id+".png")
func panel(): return app.layout.find_child("NodeEventChoices",true,false)
func choices(): return panel().find_children("*","Button",true,false)
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
	# Render the reported non-full health state with the new two-row layout.
	stat.set_stat("health",38,41)
	stat.set_stat("satiety",80,110)
	stat.set_stat("water",110,110)
	stat.set_stat("sanity",14,100)
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size=resolution; await settle()
		check(app.get_global_rect().grow(2).encloses(stat.get_global_rect()),"two-row status inside viewport")
		check(app.get_global_rect().grow(2).encloses(ap.get_global_rect()),"second-row AP inside viewport")
		await shot("health-aligned-%d" % resolution.x)
	check(app.session.snapshot()==before,"status layout fixture leaves game state untouched")
	root.size=Vector2i(1600,900); await settle()
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.handle_command("enter"); await settle()
	check(panel()!=null,"conditional story panel")
	await shot("intro")
	var p = panel(); choices()[0].pressed.emit(); await settle()
	check(app.session.state.story_step=="choice","native button advances real story")
	await shot("choice")
	for resolution in [Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720)]:
		root.size=resolution; await settle()
		var bounds = app.get_global_rect().grow(2)
		for b in choices():
			if b is Control: check(bounds.encloses(b.get_global_rect()),"choice controls inside viewport")
	await shot("choice-1280")
	p=panel()
	var disabled_snapshot=app.session.snapshot(); var disabled_button=choices()[0]; disabled_button.disabled=true
	var mouse := InputEventMouseButton.new(); mouse.button_index=MOUSE_BUTTON_LEFT; mouse.position=disabled_button.get_global_rect().get_center(); mouse.pressed=true
	root.push_input(mouse,true); mouse=mouse.duplicate(); mouse.pressed=false; root.push_input(mouse,true); await settle()
	check(app.session.snapshot()==disabled_snapshot,"disabled choice cannot dispatch")
	disabled_button.disabled=false; disabled_button.pressed.emit(); await settle()
	check(app.session.snapshot()!=disabled_snapshot and app.message=="","native choice dispatches actual option ID")
	check(app.find_children("*","ScrollContainer",true,false).is_empty(),"no scroll containers")
	p=panel()
	# Read-only seven-choice fixture uses the current native event page, not the retired addon API.
	var native_page=p.get_parent()
	for child in p.get_children(): child.queue_free()
	await settle()
	for title in ["迎战","离开遭遇","编网打捞木料","换取食物与淡水","检查受损设备","修补外围筏格","继续航行"]:
		native_page.choice(p,title,"advance",{})
	await settle()
	check(choices().size()==7,"all seven options presented")
	for b in choices(): check(p.get_global_rect().encloses(b.get_global_rect()),"seven choices remain within panel")
	check(app.get_global_rect().encloses(p.get_global_rect()),"seven-option panel within viewport")
	await shot("seven-options-1280")
	app.queue_free(); await process_frame; print("SUPPLIED HUD INTEGRATION: PASS" if failures==0 else "SUPPLIED HUD INTEGRATION: FAIL"); quit(0 if failures==0 else 1)
