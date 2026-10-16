extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	if not ResourceLoader.exists("res://presentation/raft_camera_controls.gd"):
		check(false,"camera controls exist"); quit(1); return
	var controls=load("res://presentation/raft_camera_controls.gd").new()
	var base=Transform3D(Basis.IDENTITY,Vector3(0,8,12)).looking_at(Vector3.ZERO,Vector3.UP)
	check(not controls.locked,"view starts unlocked")
	controls.begin_drag(Vector2.ZERO); controls.drag_to(Vector2(3,0)); controls.end_drag()
	check(not controls.dragged and controls.apply_pose(base,Vector3.ZERO)==base,"tiny movement remains a click")
	controls.begin_drag(Vector2.ZERO); controls.drag_to(Vector2(80,40)); controls.end_drag()
	check(controls.dragged and controls.apply_pose(base,Vector3.ZERO)!=base,"drag changes orbit pose")
	controls.zoom_by(1000); check(controls.zoom>=.55,"zoom-in is bounded")
	controls.zoom_by(-1000); check(controls.zoom<=2.5,"zoom-out is bounded")
	controls.locked=true
	var locked=controls.apply_pose(base,Vector3.ZERO)
	controls.orbit(Vector2(30,40)); controls.zoom_by(1)
	check(controls.apply_pose(base,Vector3.ZERO)==locked,"locked view ignores orbit and zoom")
	controls.reset()
	check(controls.apply_pose(base,Vector3.ZERO)==base,"reset restores default even when locked")
	var prefs=load("res://presentation/display_settings.gd").new(false)
	check(not prefs.view_locked,"settings default is unlocked")
	prefs.path="user://camera-controls-test.cfg"; prefs.view_locked=true
	check(prefs.save_preferences()==OK,"save view lock")
	var copy=load("res://presentation/display_settings.gd").new(false); copy.path=prefs.path; copy.load_preferences()
	check(copy.view_locked,"view lock preference restores independently of game")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.path))
	print("CAMERA CONTROLS: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
