extends SceneTree
var failures := 0
var app
func _init() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + reason)
func settle() -> void:
	for i in range(6): await process_frame
func run() -> void:
	app = load("res://flow_app.gd").new(); app.persistence = false
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app); await settle()
	app.handle_command("new", load("res://core/tutorial_rules.gd").start_args())
	for command in ["voyage","salvage","salvage","craft","install","enter"]:
		var args := {}
		if command == "voyage": args.id = app.session.state.candidates[0].visit_id
		if command == "craft": args.id = "filter"
		if command == "install":
			args.uid = load("res://core/tutorial_rules.gd").hand_uid(app.session.state,"filter"); args.auto = true
		app.handle_command(command, args)
	await settle()
	check(app.session.phase() == "story", "reached the event in the supplied screenshot")
	for resolution in [Vector2i(1280,720),Vector2i(1600,900)]:
		for ui_scale in [1.0,1.25]:
			root.size = resolution
			app.display_settings.free_aspect = true; app.display_settings.ui_scale = ui_scale
			app.apply_display_settings(false); await settle()
			var banner: Control = app.find_child("TutorialBanner",true,false)
			var body: Control = app.find_child("NodeEventBodyHost",true,false)
			var hand: Control = app.find_child("VoyageHandTopBar",true,false)
			var options: Control = app.find_child("NodeEventOptions",true,false)
			print("EVENT GEOMETRY %s/%s app=%s banner=%s body=%s options=%s header=%s" % [resolution,ui_scale,app.size,banner.get_global_rect(),body.get_global_rect(),options.get_global_rect(),hand.get_global_rect()])
			check(banner.size.y <= 118, "hint is compact: %s %s" % [resolution,ui_scale])
			check(body.global_position.y >= banner.get_global_rect().end.y + 8, "event clears hint")
			check(options.get_global_rect().end.y <= hand.global_position.y - 8, "options clear AP and hand header: %s %s" % [resolution,ui_scale])
			for button in options.find_children("NodeEventAction_*","Button",true,false):
				check(options.get_global_rect().grow(1).encloses(button.get_global_rect()), "event action fits the available column")
			var scroll: ScrollContainer=app.find_child("NodeEventChoicesScroll",true,false)
			var bar: VScrollBar=scroll.get_v_scroll_bar()
			if bar.max_value > bar.page:
				var before_scroll: float=bar.value
				var point: Vector2=root.get_final_transform()*scroll.get_global_rect().get_center()
				for i in range(4):
					var wheel:=InputEventMouseButton.new()
					wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=true; wheel.position=point
					Input.parse_input_event(wheel); await process_frame
				check(bar.value > before_scroll,"mouse wheel reaches overflowing event choices")
				scroll.scroll_vertical=0; await settle()
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://evidence/tutorial-repair-event-%dx%d-%d.png" % [resolution.x,resolution.y,roundi(ui_scale*100)])
	app.handle_command("advance"); app.handle_command("option",{"id":"wood"}); app.handle_command("advance"); app.handle_command("end_voyage")
	for i in range(30):
		if app.session.phase()!="discard": break
		app.handle_command("discard",{"uid":app.session.state.hand[0].uid})
	for id in ["water","food"]:
		app.handle_command("play",{"uid":load("res://core/tutorial_rules.gd").hand_uid(app.session.state,id)})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.handle_command("enter"); app.handle_command("advance"); app.handle_command("fight"); await settle()
	check(app.session.phase()=="battle","reached the battle lesson")
	for ui_scale in [1.0,1.25]:
		app.display_settings.ui_scale=ui_scale; app.apply_display_settings(false); await settle()
		var hint_rect: Rect2=app.find_child("TutorialBanner",true,false).get_global_rect()
		for panel_name in ["MonsterPanel","EnemyIntentPanel","ActionPreviewPanel","CombatLogPanel"]:
			check(not hint_rect.intersects(app.find_child(panel_name,true,false).get_global_rect()),"battle hint clears "+panel_name)
	app.queue_free(); await process_frame
	print("TUTORIAL EVENT LAYOUT: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
