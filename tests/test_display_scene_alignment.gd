extends SceneTree
var failures:=0
var app
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); app.world_view.motion=false
	var marker:=MeshInstance3D.new(); var quad:=QuadMesh.new(); quad.size=Vector2(0.12,0.12); marker.mesh=quad
	var material:=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(1,0,1); material.no_depth_test=true; material.disable_fog=true
	marker.material_override=material; app.world_view.world.add_child(marker)
	var before: Dictionary=app.session.snapshot()
	for scale_value in [1.0,1.1,1.13,1.2,1.25,1.0]:
		for quality in [2,0]:
			app.display_settings.mobile=true; app.display_settings.ui_scale=scale_value; app.display_settings.quality=quality
			app.apply_display_settings(false)
			await process_frame; await process_frame; await process_frame
			await create_timer(.75).timeout
			var world=app.world_view
			marker.global_position=world.camera.project_position(Vector2(world.viewport.size)*world.RAFT_SCREEN_CENTER,2.0)
			marker.global_basis=world.camera.global_basis
			await process_frame; await RenderingServer.frame_post_draw
			var img:=root.get_texture().get_image(); var sum:=Vector2.ZERO; var count:=0
			for y in range(img.get_height()):
				for x in range(img.get_width()):
					var color:=img.get_pixel(x,y)
					if color.r>0.55 and color.b>0.55 and color.g<0.25: sum+=Vector2(x,y); count+=1
			var target: Vector2=Vector2(root.size)*world.RAFT_SCREEN_CENTER
			var centre:=sum/maxi(1,count); var error:=centre.distance_to(target)
			print("scale=",scale_value," quality=",quality," marker=",centre," target=",target," error=",error)
			if count==0 or error>3:
				failures+=1; printerr("FAIL: scene projection must keep its screen position at every UI scale and clarity")
			if "--capture" in OS.get_cmdline_user_args():
				marker.hide(); await process_frame; await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://evidence/alignment-ui-%d-quality-%d.png" % [roundi(scale_value*100),quality]); marker.show()
	if app.session.snapshot()!=before: failures+=1; printerr("FAIL: presentation altered session")
	app.queue_free(); await process_frame
	print("DISPLAY SCENE ALIGNMENT: "+("PASS" if failures==0 else "FAIL")); quit(failures)
