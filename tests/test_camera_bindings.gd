extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	var script=load("res://presentation/display_settings.gd")
	var prefs=script.new(false)
	check(prefs.get("camera_orbit_button")==MOUSE_BUTTON_RIGHT,"default right drag rotates")
	check(prefs.get("camera_pan_button")==MOUSE_BUTTON_LEFT,"default left drag pans")
	if not prefs.has_method("set_camera_mouse_binding"):
		check(false,"camera bindings can change"); quit(1); return
	check(prefs.set_camera_mouse_binding("orbit",MOUSE_BUTTON_LEFT),"change rotation binding")
	check(prefs.camera_orbit_button==MOUSE_BUTTON_LEFT and prefs.camera_pan_button==MOUSE_BUTTON_RIGHT,"conflicting mouse bindings swap")
	check(prefs.set_camera_mouse_binding("pan",MOUSE_BUTTON_MIDDLE),"middle button remains selectable")
	check(not prefs.set_camera_mouse_binding("orbit",MOUSE_BUTTON_WHEEL_UP),"wheel cannot become a drag button")
	prefs.camera_reset_key=KEY_F6; prefs.path="user://camera-binding-test.cfg"
	check(prefs.save_preferences()==OK,"save bindings")
	var copy=script.new(false); copy.path=prefs.path; copy.load_preferences()
	check(copy.camera_orbit_button==MOUSE_BUTTON_LEFT and copy.camera_pan_button==MOUSE_BUTTON_MIDDLE and copy.camera_reset_key==KEY_F6,"bindings survive reload")
	var config:=ConfigFile.new(); config.set_value("display","camera_orbit_button",MOUSE_BUTTON_RIGHT); config.set_value("display","camera_pan_button",MOUSE_BUTTON_RIGHT); config.set_value("display","camera_reset_key",KEY_ESCAPE); config.save(prefs.path)
	copy.load_preferences()
	check(copy.camera_orbit_button==MOUSE_BUTTON_RIGHT and copy.camera_pan_button==MOUSE_BUTTON_LEFT and copy.camera_reset_key==KEY_R,"invalid or conflicting configuration falls back to defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.path))
	print("CAMERA BINDINGS: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
