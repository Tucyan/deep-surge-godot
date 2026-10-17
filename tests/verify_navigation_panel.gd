extends SceneTree
var app
var failures := 0
func _init(): call_deferred("run")
func check(ok, message):
	if not ok: failures += 1; printerr("FAIL: "+message)
func settle():
	for i in range(5): await process_frame
func run():
	root.size=Vector2i(1600,900)
	app=load("res://flow_app.gd").new(); app.persistence=false; app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
	var before=app.session.snapshot()
	for resolution in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(1920,820)]:
		for scale_value in [1.0,1.25]:
			root.size=resolution; app.display_settings.free_aspect=true; app.display_settings.ui_scale=scale_value
			app.apply_display_settings(false); await settle()
			var frame=app.find_child("VoyageOperationFrame",true,false)
			var actions=app.find_child("VoyageOperationActions",true,false)
			check(app.get_global_rect().grow(2).encloses(frame.get_global_rect()),"operation in viewport")
			check(frame.get_global_rect().end.y<app.find_child("VoyageHandTopBar",true,false).global_position.y,"clears hand header")
			check(absf(actions.get_global_rect().end.y-frame.get_global_rect().end.y+18)<2,"buttons at panel bottom")
			for b in actions.find_children("*","Button",true,false): check(frame.get_global_rect().encloses(b.get_global_rect()),"button fits panel")
			print("LAYOUT %s %s panel=%s actions=%s" % [resolution,scale_value,frame.get_global_rect(),actions.get_global_rect()])
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/navigation-panel-%dx%d-%d.png" % [resolution.x,resolution.y,roundi(scale_value*100)])
	check(app.session.snapshot()==before,"layout preserves state and random stream")
	# Use a native destination button to verify command wiring survives reparenting.
	var buttons=app.find_child("VoyageOperationActions",true,false).find_children("*","Button",true,false)
	buttons[0].pressed.emit(); await settle()
	check(app.session.state.phase=="preparation","departure button dispatches")
	app.queue_free(); await process_frame
	print("NAVIGATION PANEL: "+("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
