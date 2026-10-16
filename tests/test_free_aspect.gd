extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+why)
func run() -> void:
	var script = load("res://presentation/display_settings.gd")
	var prefs = script.new(false)
	check(script.RESOLUTIONS.size()==4,"Four clarity tiers")
	check(prefs.get("free_aspect") == false,"Fixed ratio remains default with a free-ratio option")
	if prefs.get("free_aspect") == null: quit(1); return
	prefs.free_aspect=true
	prefs.path="user://free-aspect-test.cfg"
	prefs.save_preferences()
	var restored=script.new(false); restored.path=prefs.path; restored.load_preferences()
	check(restored.free_aspect,"Free ratio persists independently of game saves")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.path))
	prefs.resolution=Vector2i(960,540)
	for physical in [Vector2i(1350,900),Vector2i(1440,900),Vector2i(1600,900),Vector2i(2100,900)]:
		var rendered: Vector2i=prefs.render_size(Vector2(physical),physical)
		check(absf(float(rendered.x)/rendered.y-float(physical.x)/physical.y)<0.005,"Scene keeps ratio: "+str(physical))
		check(mini(rendered.x,rendered.y)<=540,"Free-window clarity caps scene pixels: "+str(physical))
	prefs.apply_window(root,false)
	check(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_EXPAND,"Free ratio expands canvas without letterboxing")
	prefs.free_aspect=false; prefs.apply_window(root,false)
	check(root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_KEEP,"Fixed ratio restores 16:9 letterboxing")
	print("FREE ASPECT: "+("PASS" if failures==0 else "FAIL")); quit(failures)
