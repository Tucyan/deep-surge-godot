extends SceneTree
## Graphical diagnosis only. Run with isolated APPDATA and LOCALAPPDATA.
var app
var rows: Array = []
var original: Dictionary
var output := "res://evidence/frame-bottleneck-20261019.json"
var focus_ui := false
var compare_paper := false

func _init(): call_deferred("run")

func summary(values: Array) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[int(ceil(values.size()*.95))-1]}

func sample(label: String, count: int = 90):
	for i in range(30): await process_frame
	var frames: Array = []
	var draws: Array = []
	var primitives: Array = []
	var last := Time.get_ticks_usec()
	for i in range(count):
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-last)/1000.0); last=now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var row := {"label":label,"frame_ms":summary(frames),"draw_calls":summary(draws),"primitives":summary(primitives),"window":str(root.size),"render_size":str(app.world_view.viewport.size),"cap":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode()}
	rows.append(row)
	print("FRAME_PROBE "+JSON.stringify(row))

func run():
	if DisplayServer.get_name()=="headless":
		printerr("Graphical renderer required"); quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg=="--focus-ui": focus_ui=true
		if arg=="--compare-paper": compare_paper=true
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	app.display_settings.fps_limit=0
	app.display_settings.apply_window(root,false)
	app.handle_command("new",{"mode":"challenge","difficulty":"standard","origin":"strong","seed":22})
	app.render()
	await create_timer(1.0).timeout
	original=app.session.snapshot()
	var world=app.world_view
	print("FRAME_PROBE GPU="+RenderingServer.get_video_adapter_name())
	if compare_paper:
		world.motion=false; world._time=3.3; world._process(0)
		var border=get_nodes_in_group("hand_fans")[0].border
		var current_script=border.get_script()
		var legacy_script=load("res://tests/fixtures/paper_frame_legacy.gd")
		var reference_image: Image
		for i in range(3):
			for legacy in [true,false]:
				border.set_script(legacy_script if legacy else current_script)
				border.paper=true; border.queue_redraw()
				await sample(("legacy_paper_" if legacy else "batched_paper_")+str(i))
				if i==0:
					await RenderingServer.frame_post_draw
					var captured:=root.get_texture().get_image()
					captured.save_png("res://evidence/paper-game-%s.png" % ("before" if legacy else "after"))
					if legacy: reference_image=captured
					else:
						var before:=reference_image.get_data(); var after:=captured.get_data()
						var changed:=0; var max_error:=0
						for channel in range(before.size()):
							var error:=absi(int(before[channel])-int(after[channel]))
							if error>0: changed+=1; max_error=maxi(max_error,error)
						var comparison:={"size":str(captured.get_size()),"pixels_equal":before==after,"changed_channels":changed,"max_byte_error":max_error}
						var visual_file:=FileAccess.open("res://evidence/paper-game-visual-20261019.json",FileAccess.WRITE)
						visual_file.store_string(JSON.stringify(comparison,"\t")); visual_file.close()
						print("FRAME_VISUAL "+JSON.stringify(comparison))
						if max_error>1: printerr("Paper visual comparison exceeds one RGBA byte"); quit(1); return
		world.motion=true
		app.display_settings.fps_limit=60; app.display_settings.apply_window(root,false)
		await sample("batched_motion_default_cap60")
		await finish(); return
	if focus_ui:
		world.motion=false; world._time=3.3; world._process(0)
		var fans=get_nodes_in_group("hand_fans")
		if fans.size()!=1:
			printerr("Expected one visible hand"); quit(1); return
		var border=fans[0].border
		var points := range(12,int(border.size.x)-12,5).size()*range(12,int(border.size.y)-12,7).size()
		print("FRAME_PROBE paper_border=%s size=%s grain_circles=%d" % [border.get_path(),border.size,points])
		for i in range(3):
			await sample("ui_baseline_"+str(i))
			border.paper=false; border.queue_redraw()
			await sample("paper_off_"+str(i))
			border.paper=true; border.queue_redraw()
			await sample("paper_restored_"+str(i))
			border.hide()
			await sample("border_hidden_"+str(i))
			border.show()
		await finish(); return
	# Real desktop settings: each clarity tier selects a different window size.
	for tier in [0,1,2,3]:
		app.display_settings.resolution=app.display_settings.RESOLUTIONS[tier]
		app.apply_display_settings(true,false)
		await sample("desktop_"+str(tier))
	root.size=Vector2i(1280,720)
	app.display_settings.mobile=true
	for tier in [0,1,2,3]:
		app.display_settings.quality=tier
		app.apply_display_settings(false,false)
		await sample("mobile_scale_"+str(tier))
	app.display_settings.quality=2
	app.apply_display_settings(false,false)
	await sample("baseline")
	# Freeze the pose before further ablations, retaining the exact scene/camera.
	world.motion=false
	await sample("motion_off")
	var surface=app.find_child("RaftInteraction",true,false).surface
	world.set_process(false); surface.set_process(false)
	await sample("world_and_ghost_process_off")
	world.set_process(true); surface.set_process(true)
	var lights=world.world.find_children("*","DirectionalLight3D",true,false)
	for light in lights: light.shadow_enabled=false
	await sample("directional_shadow_off")
	for light in lights: light.shadow_enabled=true
	world.toon_ocean.visible=false
	await sample("ocean_hidden")
	world.toon_ocean.visible=true
	var near_material=world.toon_ocean.near.material_override
	var far_material=world.toon_ocean.far.material_override
	var flat:=StandardMaterial3D.new(); flat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; flat.albedo_color=Color("102040")
	world.toon_ocean.near.material_override=flat; world.toon_ocean.far.material_override=flat
	await sample("ocean_flat_shader")
	world.toon_ocean.near.material_override=near_material; world.toon_ocean.far.material_override=far_material
	app.layout.visible=false
	await sample("hud_hidden")
	app.layout.visible=true
	world.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	await sample("3d_render_disabled")
	world.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	await sample("baseline_repeat")
	await finish()

func finish():
	var unchanged: bool=app.session.snapshot()==original
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"rules_unchanged":unchanged,"rows":rows},"\t")); file.close()
	app.queue_free(); await process_frame
	print("FRAME_PROBE rules_unchanged="+str(unchanged)); quit(0 if unchanged else 1)
