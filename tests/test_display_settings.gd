extends SceneTree
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+why)
func _init() -> void: call_deferred("run")
func run() -> void:
	if not ResourceLoader.exists("res://presentation/display_settings.gd"):
		check(false,"Missing persistent platform-specific display settings"); quit(1); return
	var script = load("res://presentation/display_settings.gd")
	var mobile = script.new(true)
	var desktop = script.new(false)
	check(mobile.ui_scale==1.25 and desktop.ui_scale==1.0,"Mobile starts with larger UI")
	check(not mobile.supports_window_options() and desktop.supports_window_options(),"Fullscreen and resolution are desktop-only")
	check(mobile.render_size(Vector2(1280,720),Vector2i(2400,1080))==Vector2i(1920,1080),"Clarity uses physical height and preserves scene aspect")
	mobile.quality=0
	check(mobile.render_size(Vector2(1280,720),Vector2i(2400,1080))==Vector2i(960,540),"Mobile low clarity reduces only scene pixels")
	check(desktop.render_size(Vector2(1600,900),Vector2i(1280,720))==desktop.render_size(Vector2(1280,720),Vector2i(1280,720)),"UI enlargement does not change scene resolution")
	mobile.path="user://display-settings-test.cfg"
	mobile.ui_scale=1.2; mobile.quality=0; mobile.fullscreen=true
	check(mobile.save_preferences()==OK,"Settings save separately from run")
	var restored=script.new(true); restored.path=mobile.path; restored.load_preferences()
	check(is_equal_approx(restored.ui_scale,1.2) and restored.quality==0,"Settings survive reload")
	check(not restored.fullscreen,"Mobile cannot restore desktop fullscreen")
	var bad:=ConfigFile.new(); bad.set_value("display","ui_scale",99.0); bad.set_value("display","quality",-8)
	bad.set_value("display","resolution",Vector2i(-1,0)); bad.save(mobile.path)
	restored.load_preferences()
	check(restored.ui_scale<=1.25 and restored.quality>=0 and restored.resolution.x>=960,"Invalid settings are bounded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mobile.path))
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame; await process_frame
	var entry=app.find_child("HomeSettings",true,false)
	check(entry!=null,"Home has top-right settings entry")
	if entry!=null: check(entry.position.x>app.size.x*0.7 and entry.position.y<app.size.y*0.2,"Settings entry is really in top-right corner")
	if entry!=null: entry.pressed.emit()
	await process_frame; await process_frame
	check(app.local_panel=="settings","Home entry opens settings")
	check(app.find_child("DesktopResolution",true,false)!=null and app.find_child("DesktopFullscreen",true,false)!=null,"Desktop exposes resolution and fullscreen")
	app.display_settings.mobile=true; app.render()
	await process_frame; await process_frame
	check(app.find_child("MobileQuality",true,false)!=null and app.find_child("DesktopFullscreen",true,false)==null and app.find_child("DesktopResolution",true,false)==null,"Mobile exposes clarity only")
	var before: Dictionary=app.session.snapshot()
	app.display_settings.ui_scale=1.25; app.apply_display_settings()
	await process_frame; await process_frame
	check(is_equal_approx(root.content_scale_factor,1.25),"UI scale actually changes canvas scale")
	check(app.session.snapshot()==before,"Display settings never mutate rules or random streams")
	for b in descendants(app.layout):
		if b is BaseButton and b.is_visible_in_tree(): check(app.get_global_rect().grow(2).encloses(b.get_global_rect()),"Enlarged settings stays visible: "+b.name)
	app.local_panel=""; app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	await process_frame; await process_frame
	for b in descendants(app):
		if b is BaseButton and b.is_visible_in_tree():
			check(app.get_global_rect().grow(2).encloses(b.get_global_rect()),"Enlarged UI button stays visible: "+b.name)
	app.queue_free(); root.content_scale_factor=1.0; await process_frame
	print("DISPLAY SETTINGS: "+("PASS" if failures==0 else "FAIL")); quit(failures)
func descendants(node: Node) -> Array:
	var result: Array=[]
	for child in node.get_children(): result.append(child); result.append_array(descendants(child))
	return result
