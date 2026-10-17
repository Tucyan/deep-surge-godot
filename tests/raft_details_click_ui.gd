extends SceneTree
var app
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func _init() -> void: call_deferred("run")
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func tap(point: Vector2, touch: bool) -> void:
	for pressed in [true,false]:
		if touch:
			var e := InputEventScreenTouch.new(); e.index=0; e.pressed=pressed; e.position=root.get_final_transform()*point
			Input.parse_input_event(e)
		else:
			var e := InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=pressed; e.position=root.get_final_transform()*point; e.global_position=e.position
			Input.parse_input_event(e)
		await process_frame
	await settle()
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); app.world_view.motion=false; await create_timer(.8).timeout
	for scale_value in [1.0,1.25]:
		app.display_settings.ui_scale=scale_value; app.apply_display_settings(false); await settle(); await create_timer(.8).timeout
		var interaction=app.find_child("RaftInteraction",true,false)
		var root_cell: Dictionary=app.world_view.raft_models.root_cells(app.world_view._raft_layout)[0]
		var second_root: Dictionary=app.world_view.raft_models.root_cells(app.world_view._raft_layout)[1]
		await tap(interaction.surface.screen_point(second_root),false)
		check(app.session.panel=="","cell 2 does not open raft details")
		var before: Dictionary=app.session.snapshot(); before.erase("revision")
		await tap(interaction.surface.screen_point(root_cell),scale_value>1.0)
		check(app.session.panel=="raft","click/touch cell 1 opens retained raft details at scale %s" % scale_value)
		var after: Dictionary=app.session.snapshot(); after.erase("revision")
		check(after==before,"opening details preserves rule state and RNG")
		app.handle_command("close"); await settle()
		check(app.session.panel=="","details closes normally")
	if "--capture" in OS.get_cmdline_user_args():
		app.handle_command("panel",{"id":"raft"}); await settle(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/raft-details-click.png")
	app.queue_free(); await process_frame
	print("RAFT DETAILS CLICK UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
