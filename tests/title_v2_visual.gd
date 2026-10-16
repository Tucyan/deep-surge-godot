extends SceneTree
var app
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL "+why)
func capture(id):
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/title-v2-"+id+".png")
func run():
	root.size=Vector2i(1600,900)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await create_timer(0.7).timeout
	var title=app.layout.find_child("Title_start",true,false).get_parent().get_parent()
	for button in title.buttons:
		check(absf(button.size.x/button.size.y - 3.0) < 0.001, "button preserves source aspect ratio")
		check(button.position.y+button.size.y<=title.REFERENCE.y,"button within composition")
	check(title.layout_debug==null,"debug layout panel is hidden from homepage")
	check(title.background.is_playing(),"background video playing")
	check(title.buttons[1].disabled,"continue requires a saved run")
	await capture("home")
	var position_before: float=title.background.stream_position
	await create_timer(1.1).timeout
	check(title.background.stream_position>position_before,"video time advances")
	await capture("moving")
	await create_timer(4.4).timeout
	check(title.background.is_playing(),"video remains playing after a full loop")
	check(title.background.stream_position<5.2,"video playback wraps at clip end")
	title._hover(3,true); await create_timer(0.25).timeout; await capture("hover")
	title.buttons[2].pressed.emit(); await process_frame; await process_frame
	check(app.session.panel=="encyclopedia","journal opens existing catalogue")
	check(app.layout.find_child("Title_start",true,false).disabled,"modal disables background texture buttons")
	app.handle_command("close"); await process_frame
	title=app.layout.find_child("Title_start",true,false).get_parent().get_parent()
	title.buttons[0].pressed.emit(); await process_frame; await capture("mode-select")
	var mode=title.find_children("*","Button",true,false).filter(func(b):return b.text=="挑战模式")[0]
	mode.pressed.emit(); await process_frame
	check(app.setup_mode=="challenge","challenge mode uses existing setup")
	check(app.layout.find_child("Title_start",true,false)==null,"setup replaces home menu")
	app.handle_ui("setup",""); root.size=Vector2i(1280,720); await create_timer(0.4).timeout; await capture("1280")
	app.queue_free(); await process_frame
	print("TITLE V2: PASS" if failures==0 else "TITLE V2: FAIL"); quit(0 if failures==0 else 1)
