extends SceneTree
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)
func _init() -> void:
	if not ResourceLoader.exists("res://tests/helpers/route_coverage.gd"):
		check(false, "current-version route coverage gate is missing")
		quit(1); return
	var gate = load("res://tests/helpers/route_coverage.gd")
	var a := {"id":"challenge", "version":"v25", "fingerprint":"current"}
	var b := {"id":"story", "version":"v25", "fingerprint":"current"}
	var old := {"id":"history", "version":"v22", "fingerprint":"old"}
	check(not gate.evaluate([], ["challenge"], "v25", "current").ok, "zero current routes fail")
	check(not gate.evaluate([old], ["challenge"], "v25", "current").ok, "only stale routes fail")
	check(not gate.evaluate([a], ["challenge","story"], "v25", "current").ok, "missing required mode fails")
	check(not gate.evaluate([a,a], ["challenge"], "v25", "current").ok, "duplicate identity fails")
	var changed := a.duplicate(); changed.fingerprint = "different"
	check(not gate.evaluate([changed], ["challenge"], "v25", "current").ok, "same version with different content fails")
	var result: Dictionary = gate.evaluate([a,b,old], ["challenge","story"], "v25", "current")
	check(result.ok and result.current==2 and result.stale==1, "complete current coverage passes with separate stale count")
	print("ROUTE COVERAGE: %s" % ("PASS" if failures==0 else "FAIL"))
	quit(failures)
