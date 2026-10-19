extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures += 1; printerr("FAIL: " + why)
func run():
	var script = load("res://presentation/display_settings.gd")
	var path := "user://test-display-aspect-defaults.cfg"
	for mobile in [false, true]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var prefs = script.new(mobile); prefs.path=path
		check(prefs.free_aspect==mobile,"platform-specific initial aspect")
		prefs.load_preferences()
		check(prefs.free_aspect==mobile,"missing file keeps platform default")
		var config := ConfigFile.new()
		config.set_value("display","ui_scale",1.1)
		check(config.save(path)==OK,"write preferences without aspect")
		prefs=script.new(mobile); prefs.path=path; prefs.load_preferences()
		check(prefs.free_aspect==mobile,"missing aspect setting uses platform default")
		prefs.apply_window(root,false)
		check(root.content_scale_aspect==(Window.CONTENT_SCALE_ASPECT_EXPAND if mobile else Window.CONTENT_SCALE_ASPECT_KEEP),"platform default applies to actual canvas")
		for choice in [false,true]:
			prefs.free_aspect=choice
			check(prefs.save_preferences()==OK,"save explicit aspect choice")
			var restored=script.new(mobile); restored.path=path; restored.load_preferences()
			check(restored.free_aspect==choice,"explicit choice survives reload on either platform")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("DISPLAY ASPECT DEFAULTS: "+("PASS" if failures==0 else "FAIL")); quit(failures)
