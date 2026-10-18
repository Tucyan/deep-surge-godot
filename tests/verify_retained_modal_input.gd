extends SceneTree
var app
var failures:=0
func _init(): call_deferred("run")
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle(): await process_frame; await process_frame; await RenderingServer.frame_post_draw
func click(point: Vector2):
	var physical: Vector2=root.get_final_transform()*point
	var move:=InputEventMouseMotion.new(); move.position=physical; move.global_position=physical
	Input.parse_input_event(move)
	for down in [true,false]:
		var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=down; e.position=physical; e.global_position=physical
		Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	await RenderingServer.frame_post_draw
func press(button: Button): await click(button.get_global_rect().get_center())
func run():
	if DisplayServer.get_name()=="headless": quit(1); return
	Input.use_accumulated_input=false
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	for config in [Vector3(1280,720,1),Vector3(1280,720,1.25),Vector3(1600,900,1)]:
		root.size=Vector2i(config.x,config.y)
		app.local_panel=""; app.display_settings.ui_scale=config.z; app.display_settings.free_aspect=true
		app.apply_display_settings(false)
		app.session=preload("res://core/game_session.gd").new(app.catalog)
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
		check(app.message.is_empty(),"fresh scenario starts without an active-run warning")
		var old_layout: int=app.layout.get_instance_id()
		var old_hand: int=app.find_child("hand_fan",true,false).get_instance_id()
		var menu=app.find_child("VoyageMenu",true,false)
		var settings: Button=menu.get_children().filter(func(n):return n is Button and n.text=="设置")[0]
		await press(settings)
		check(app.local_panel=="settings","real settings click opens modal")
		check(app.layout.get_instance_id()==old_layout and app.find_child("hand_fan",true,false).get_instance_id()==old_hand,"settings retains layout and hand at %s" % config)
		var rules: Dictionary=app.session.snapshot()
		await press(app.find_child("SalvageEntry",true,false))
		check(app.session.snapshot()==rules,"modal shade blocks real background salvage click")
		var fan=app.find_child("hand_fan",true,false)
		await click(fan.get_global_rect().end-Vector2(30,12))
		check(fan.pressed_index==-1 and app.session.snapshot()==rules,"modal blocks global hand input")
		check(not app.world_view.camera_input_enabled,"modal blocks camera at every scale")
		var modal=app.find_child("GameModalLayer",true,false)
		check(modal.get_global_rect().encloses(app.find_child("ModalSurface",true,false).get_global_rect()),"settings surface fits viewport")
		await press(modal.find_child("CloseX",true,false))
		check(app.local_panel=="" and app.layout.get_instance_id()==old_layout,"real close restores retained HUD")
		# UI-scale rebuild inside settings must leave a functional raft afterwards.
		app.handle_ui("local_panel","settings"); await settle()
		app.display_settings.ui_scale=1.13 if config.z==1.0 else 1.25
		app.apply_display_settings(false); await settle()
		await press(app.find_child("GameModalLayer",true,false).find_child("CloseX",true,false))
		var interaction=app.find_child("RaftInteraction",true,false)
		check(interaction!=null and interaction.can_process() and interaction.surface.visible,"raft interaction restores after modal scale rebuild")
		await create_timer(.8).timeout
		var cell: Dictionary=app.session.state.cells[0]
		await click(interaction.surface.screen_point(cell))
		check(interaction.selected.get("id","")==cell.id,"real raft cell click works after modal scale rebuild")
		if config.z==1.25:
			root.get_texture().get_image().save_png("res://evidence/interaction-fixed-modal-restored-125.png")
		interaction.select_target({})
	# Embedded event page keeps fresh command revisions through a core modal.
	app.display_settings.ui_scale=1.0; app.apply_display_settings(false)
	var id: String=app.session.state.candidates[0].visit_id
	app.handle_command("voyage",{"id":id}); app.handle_command("enter"); await settle()
	app.handle_command("panel",{"id":"raft"}); await settle()
	await press(app.find_child("GameModalLayer",true,false).find_child("CloseX",true,false))
	var story=app.layout.find_children("*","",true,false).filter(func(n):return n.get_script()!=null and n.get_script().resource_path=="res://pages/flow_story.gd")
	check(story.size()==1,"embedded event page retained")
	if story.size()==1:
		check(story[0].context.revision==app.session.revision,"embedded event sends current command revision")
		story[0].send("advance"); await settle()
		check(app.message.is_empty(),"embedded event command after modal is accepted")
	app.queue_free(); await process_frame
	print("RETAINED MODAL INPUT: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
