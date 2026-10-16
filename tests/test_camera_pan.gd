extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	var controls=load("res://presentation/raft_camera_controls.gd").new()
	if not controls.has_method("pan"):
		check(false,"horizontal pan exists"); quit(1); return
	var base=Transform3D(Basis.IDENTITY,Vector3(0,8,12)).looking_at(Vector3.ZERO,Vector3.UP)
	controls.pan(Vector2(60,30),base.basis,.02)
	var pose: Transform3D=controls.apply_pose(base,Vector3.ZERO)
	check(pose.origin.distance_to(base.origin)>.1,"pan translates camera")
	check(is_equal_approx(pose.origin.y,base.origin.y) and pose.basis==base.basis,"pan preserves altitude and rotation")
	controls.locked=true; controls.pan(Vector2(20,40),base.basis,.02)
	check(controls.apply_pose(base,Vector3.ZERO)==pose,"view lock blocks pan")
	controls.reset(); check(controls.apply_pose(base,Vector3.ZERO)==base,"reset clears pan")
	controls.locked=false
	controls.begin_drag(Vector2.ZERO,"pan"); controls.drag_to(Vector2(40,20),base.basis,.02); controls.end_drag()
	check(controls.dragged and is_zero_approx(controls.yaw) and controls.pan_offset.length()>.1,"pan gesture does not orbit")
	controls.reset()
	for i in range(20): controls.pan(Vector2(10000,10000),base.basis,.02)
	check(controls.pan_offset.length()<=3.0001 and is_zero_approx(controls.pan_offset.y),"diagonal and repeated pan stay within three-metre horizontal radius")
	var at_limit: Vector3=controls.pan_offset
	controls.pan(Vector2(-10,-10),base.basis,.02)
	check(controls.pan_offset.length()<at_limit.length(),"reverse drag moves away from boundary immediately")
	controls.reset(); controls.orbit(Vector2(100,20))
	controls.pan(Vector2(-10000,10000),controls.apply_pose(base,Vector3.ZERO).basis,.04)
	check(controls.pan_offset.length()<=3.0001,"limit also applies after rotating and changing pan scale")
	print("CAMERA PAN: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
