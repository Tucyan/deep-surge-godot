extends SceneTree
var failures:=0
var app
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func bounds(world) -> Rect2:
	var lo:=Vector2(INF,INF); var hi:=Vector2(-INF,-INF)
	for mesh in world.raft.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or not mesh.is_visible_in_tree(): continue
		for i in range(8):
			var point: Vector2=world.camera.unproject_position(mesh.global_transform*mesh.mesh.get_aabb().get_endpoint(i))
			lo=lo.min(point); hi=hi.max(point)
	return Rect2(lo,hi-lo)
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	if app.world_view.get("framing_rect")==null:
		check(false,"Missing camera fit region linked to HUD"); app.queue_free(); await process_frame; quit(1); return
	for scale_value in [1.0,1.25]:
		if app.session.active(): app.handle_command("abandon"); app.handle_ui("settlement_exit")
		app.display_settings.ui_scale=scale_value; app.apply_display_settings(false)
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
		app.session.give("wood",8,false,"camera-fixture"); app.render(); app.world_view.motion=false
		await create_timer(.9).timeout
		var world=app.world_view; var old: Transform3D=world.camera.global_transform
		app.handle_command("expand",{"x":0,"y":2}); await process_frame; await process_frame
		var intermediate: Transform3D=world.camera.global_transform
		await create_timer(.9).timeout
		var final: Transform3D=world.camera.global_transform
		check(old.origin.distance_to(final.origin)>.05,"Expansion changes camera position")
		check(intermediate.origin.distance_to(old.origin)<old.origin.distance_to(final.origin)*.8,"Camera moves smoothly instead of jumping")
		var rect: Rect2=world.framing_rect
		var safe:=Rect2(rect.position*Vector2(world.viewport.size),rect.size*Vector2(world.viewport.size))
		check(safe.grow(2).encloses(bounds(world)),"Expanded raft fits unobstructed HUD area at %s" % scale_value)
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/raft-camera-expanded-%d.png" % roundi(scale_value*100))
	app.queue_free(); await process_frame
	print("RAFT CAMERA FIT: "+("PASS" if failures==0 else "FAIL")); quit(failures)
