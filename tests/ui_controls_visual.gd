extends SceneTree
var app
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func capture(id: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/ui-controls-"+id+".png")
func pointer(pressed: bool, point: Vector2) -> void:
	var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=pressed; e.position=point; e.global_position=point
	Input.parse_input_event(e); await process_frame
func click(button: Button) -> void:
	var point: Vector2=root.get_final_transform()*button.get_global_rect().get_center()
	await pointer(true,point); await pointer(false,point); await settle()
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); app.world_view.motion=false
	app.handle_ui("local_panel","settings"); await settle()
	var slider=app.find_child("UIScale",true,false)
	var rect: Rect2=slider.get_global_rect()
	var start: Vector2=root.get_final_transform()*(rect.position+Vector2(10,rect.size.y/2))
	await pointer(true,start)
	var point: Vector2=root.get_final_transform()*(rect.position+Vector2(rect.size.x*.53,rect.size.y/2))
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion); await settle()
	check(is_instance_valid(slider),"Real pointer drag preserves slider instance")
	await pointer(false,point); await settle()
	check(app.display_settings.ui_scale>1.0 and app.display_settings.ui_scale<1.25,"Real drag applies intermediate UI scale")
	await capture("slider-drag")
	slider=app.find_child("UIScale",true,false); slider.grab_focus(); var previous: float=slider.value
	for pressed in [true,false]:
		var key:=InputEventKey.new(); key.keycode=KEY_RIGHT; key.pressed=pressed; Input.parse_input_event(key); await process_frame
	await settle()
	slider=app.find_child("UIScale",true,false)
	check(slider.value>previous and slider.has_focus(),"Keyboard adjusts scale and keeps slider focus")
	await click(app.find_child("ModalSurface",true,false).find_child("CloseX",true,false))
	check(app.local_panel=="","Real X click closes settings")
	for value in [1.0,1.13,1.25]:
		app.display_settings.ui_scale=value; app.apply_display_settings(false); await settle()
		await capture("hud-%d" % roundi(value*100))
		app.handle_command("panel",{"id":"craft"}); await capture("craft-%d" % roundi(value*100))
		var close=app.find_child("ModalSurface",true,false).find_child("CloseX",true,false)
		await click(close)
		check(app.session.panel=="","Real craft X returns to game")
	app.handle_ui("local_panel","settings"); await capture("settings-125")
	app.settings_tab="game"; app.render(); await capture("settings-game-125")
	app.queue_free(); await process_frame
	print("UI CONTROLS GPU: "+("PASS" if failures==0 else "FAIL")); quit(failures)
