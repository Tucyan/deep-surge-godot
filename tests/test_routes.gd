extends SceneTree
## Current-version public routes are required; archived traces are counted only.
const Coverage = preload("res://tests/helpers/route_coverage.gd")
const Session = preload("res://core/game_session.gd")
const REQUIRED := ["standard-challenge","standard-story","hard-challenge","hard-story","nightmare-challenge","nightmare-story","standard-failure"]
var failures := 0
var executed := 0
var successes := 0
var losses := 0
var selected_route := ""
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + message)
func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}
func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--route":
		selected_route = arguments[1]
		check(selected_route in REQUIRED, "selected route is required and current")
	elif not arguments.is_empty():
		check(false, "usage: -- --route REQUIRED_ROUTE_ID")
	var catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(), "load catalogue")
	var manifest := read_json("res://tests/fixtures/routes/manifest.json")
	check(manifest.get("routes") is Array, "current route manifest exists")
	if failures > 0: quit(1); return
	var records: Array = []
	var routes: Array = []
	for row in manifest.routes:
		if not row is Dictionary or not str(row.get("path", "")).begins_with("res://tests/fixtures/routes/") or ".." in str(row.get("path", "")):
			check(false, "invalid fixture entry"); continue
		var trace := read_json(str(row.path))
		var initial: Dictionary = trace.get("initial", {}) if trace.get("initial", {}) is Dictionary else {}
		records.append({"id":str(row.get("id", "")), "version":initial.get("content_version", ""), "fingerprint":initial.get("fingerprint", "")})
		routes.append({"entry":row, "trace":trace})
	for path in manifest.get("historical_paths", []):
		var trace := read_json(str(path))
		records.append({"id":"history:"+str(path), "version":trace.get("initial",{}).get("content_version",""), "fingerprint":trace.get("initial",{}).get("fingerprint","")})
	var coverage: Dictionary = Coverage.evaluate(records, REQUIRED, Session.VERSION, catalog.fingerprint())
	for error in coverage.errors: check(false, str(error))
	if coverage.ok:
		for route in routes:
			var row: Dictionary = route.entry
			var trace: Dictionary = route.trace
			if not selected_route.is_empty() and str(row.id) != selected_route: continue
			if trace.get("initial",{}).get("content_version","")!=Session.VERSION: continue
			var agent = load("res://adapters/agent_session.gd").new(catalog)
			var response: Dictionary = agent.handle({"method":"replay", "params":{"trace":JSON.parse_string(JSON.stringify(trace))}})
			check(response.ok, "full route replays " + str(row.id))
			if not response.ok: continue
			executed += 1
			var result: Dictionary = agent.handle({"method":"result"}).data
			check(result.terminal and result.report.complete, "complete terminal report " + str(row.id))
			var expected: Dictionary = row.get("expected", {})
			check(result.phase==expected.get("phase") and result.outcome==expected.get("outcome") and result.completed==expected.get("completed"), "reviewed outcome " + str(row.id))
			for card in result.report.cards:
				var departures: int = card.use_consumed+card.cost_consumed+card.deployed+card.discarded+card.lost+card.cleared+card.get("sold",0)
				check(int(card.obtained)==int(card.remaining)+departures, "card conservation " + str(row.id)+"/"+str(card.id))
			var restored = Session.new(catalog)
			check(restored.restore(JSON.parse_string(JSON.stringify(agent._session.snapshot()))), "same-version terminal save restores " + str(row.id))
			if result.outcome=="survived":
				successes += 1
				if str(row.id).ends_with("-story"): check(result.completed==11, "story uses eleven shared gameplay nodes")
			if result.outcome in ["dead","mad"]: losses += 1
			print("ROUTE %s: %s / %s, %d nodes" % [row.id,result.phase,result.outcome,result.completed])
	if selected_route.is_empty():
		check(executed>=REQUIRED.size(), "all required current routes actually executed")
		check(successes>0 and losses>0, "current success and failure coverage")
	else:
		check(executed == 1, "selected current route actually executed")
	print("ROUTES: %s (executed=%d, stale=%d, failed=%d)" % ["PASS" if failures==0 else "FAIL",executed,coverage.stale,failures])
	quit(0 if failures==0 else 1)
