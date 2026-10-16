extends SceneTree
var app
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle() -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
func shot(id: String) -> void:
	await settle()
	root.get_texture().get_image().save_png("res://evidence/title-v3-"+id+".png")
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	app.display_settings.free_aspect=true; app.apply_display_settings(false)
	await settle()
	var before: Dictionary=app.session.snapshot()
	for pixels in [Vector2i(1350,900),Vector2i(1600,900),Vector2i(2100,900)]:
		root.size=pixels; await settle()
		var title=app.find_child("Title_start",true,false).get_parent().get_parent()
		for b in title.buttons:
			check(app.get_global_rect().encloses(b.get_global_rect()),"Menu button fits "+str(pixels)+": "+b.name)
		await shot("%dx%d" % [pixels.x,pixels.y])
		app.local_panel="settings"; app.render(); await settle()
		var picker=app.find_child("DesktopResolution",true,false)
		check(picker.item_count==4 and picker.get_item_text(0)=="流畅" and picker.get_item_text(3)=="超高清","Four named clarity options")
		check(app.find_child("AspectRatio",true,false).selected==1,"Free ratio selected")
		for b in app.layout.find_children("*","BaseButton",true,false):
			if b.is_visible_in_tree(): check(app.get_global_rect().encloses(b.get_global_rect()),"Settings fits "+str(pixels)+": "+b.name)
		await shot("settings-%dx%d" % [pixels.x,pixels.y])
		app.local_panel=""; app.render(); await settle()
	check(app.session.snapshot()==before,"Display and home do not mutate session")
	var player=app.title_backdrop.background
	var playback: float=player.stream_position
	await create_timer(0.6).timeout
	check(player.is_playing() and not is_equal_approx(player.stream_position,playback),"Lighthouse video advances")
	await create_timer(5.2).timeout
	check(player.is_playing() and player.stream_position<5.2,"Lighthouse video continues after looping")
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
	for pixels in [Vector2i(1350,900),Vector2i(2100,900)]:
		root.size=pixels; app.display_settings.ui_scale=1.25; app.apply_display_settings(false); await settle()
		for b in app.layout.find_children("*","BaseButton",true,false):
			if b.is_visible_in_tree(): check(app.get_global_rect().grow(2).encloses(b.get_global_rect()),"Game fits "+str(pixels)+": "+b.name)
		await shot("game-%dx%d" % [pixels.x,pixels.y])
	app.queue_free(); await process_frame
	print("TITLE V3 GPU: "+("PASS" if failures==0 else "FAIL")); quit(failures)
