extends SceneTree
var app
var failures:=0
func _init() -> void: call_deferred("run")
func capture(label: String) -> void:
	await process_frame; await process_frame; await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/display-"+label+".png")
	for control in descendants(app.layout):
		if control is BaseButton and control.is_visible_in_tree():
			if not app.get_global_rect().grow(2).encloses(control.get_global_rect()):
				failures+=1; printerr("Out of bounds: "+label+" / "+control.name)
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	await capture("home-desktop-100")
	app.handle_ui("local_panel","settings"); await capture("settings-desktop-100")
	app.display_settings.mobile=true; app.display_settings.ui_scale=1.25; app.apply_display_settings(false)
	await capture("settings-mobile-125")
	app.local_panel=""; app.render(); await capture("home-mobile-125")
	app.handle_ui("setup","challenge"); await capture("setup-mobile-125")
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); app.world_view.motion=false
	await capture("navigation-mobile-125")
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id}); await capture("preparation-mobile-125")
	app.handle_command("panel",{"id":"craft"}); await capture("craft-mobile-125")
	app.handle_command("close"); app.handle_command("panel",{"id":"raft"}); await capture("raft-mobile-125")
	app.handle_command("close"); app.handle_ui("local_panel","settings"); app.settings_tab="game"; app.render()
	await capture("game-settings-mobile-125")
	app.local_panel=""; app.render(); app.display_settings.quality=0; app.apply_display_settings(false)
	await capture("clarity-low-mobile-125")
	app.handle_command("enter"); await capture("event-mobile-125")
	app.handle_command("home"); app.handle_command("panel",{"id":"encyclopedia"}); await capture("encyclopedia-mobile-125")
	app.handle_command("close"); app.handle_command("panel",{"id":"meta_shop"}); await capture("shop-mobile-125")
	print("DISPLAY VISUAL: "+("PASS" if failures==0 else "FAIL")); app.queue_free(); await process_frame; quit(failures)
func descendants(node: Node) -> Array:
	var result: Array=[]
	for child in node.get_children(): result.append(child); result.append_array(descendants(child))
	return result
