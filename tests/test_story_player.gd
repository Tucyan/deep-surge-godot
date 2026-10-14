extends SceneTree
var failures := 0
var total := 0
func check(ok: bool, reason: String) -> void:
	total += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + reason)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var module = load("res://story/story_player.gd")
	check(module != null, "independent story player exists")
	if module == null:
		quit(1)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://story/demo_story.json"))
	var p = module.new()
	check(p.load_story(data).ok, "valid story starts")
	check(p.get_view().node.id == "wake", "starts at declared entry")
	check(p.get_log().size() == 1, "records current line once")
	var copy = p.get_view()
	copy.node.text = "mutated"
	check(p.get_view().node.text != "mutated", "view is a deep copy")
	check(not p.choose("listen").ok, "cannot choose before choice node")
	check(p.skip().ok, "skip advances to decision")
	check(p.get_view().node.id == "signal", "skip stops at choice")
	check(not p.advance().ok, "advance cannot bypass choice")
	var log_before = p.get_log().size()
	check(p.skip().ok and p.get_log().size() == log_before, "repeat skip cannot duplicate or bypass choice")
	check(not p.choose("missing").ok, "unknown choice rejected")
	check(p.choose("listen").ok, "valid choice advances branch")
	check(p.get_view().node.id == "listen", "correct branch selected")
	check(p.get_log()[-2].choice_id == "listen", "choice recorded with originating line")
	var history = p.get_log()
	history.clear()
	check(p.get_log().size() > 0, "log copy cannot mutate history")
	var events: Array = []
	p.completed.connect(func(result): events.append(result))
	check(p.skip().ok and p.get_view().status == "completed", "skip reaches terminal")
	check(events.size() == 1 and events[0].reason == "skipped", "completion emitted exactly once")
	check(not p.advance().ok and events.size() == 1, "completed story cannot re-emit")
	check(p.load_story(data).ok and p.get_log().size() == 1, "reload resets history")
	p.advance()
	p.advance()
	check(p.choose("sail").ok and p.get_view().node.id == "sail", "alternate branch works")
	p.advance()
	p.advance()
	check(p.get_view().status == "completed", "manual completion works")
	var broken: Dictionary = data.duplicate(true)
	broken.nodes[0].next = "unknown"
	check(not p.load_story(broken).ok, "dangling node rejected")
	check(p.get_view().status == "completed", "invalid load leaves prior state intact")
	broken = data.duplicate(true)
	broken.nodes[1].next = "wake"
	check(not p.load_story(broken).ok, "cycles rejected for bounded skip")
	broken = data.duplicate(true)
	broken.nodes[0].id = "signal"
	check(not p.load_story(broken).ok, "duplicate IDs rejected")
	check(not p.load_story({"schema_version":2}).ok, "unsupported schema rejected")
	check(not p.load_story({"schema_version":1,"nodes":[]}).ok, "empty content rejected")
	broken = data.duplicate(true)
	broken.nodes[0].text = "海".repeat(161)
	check(not p.load_story(broken).ok, "oversized dialogue rejected instead of overflowing page")
	broken = data.duplicate(true)
	broken.nodes[0].description = "海".repeat(81)
	check(not p.load_story(broken).ok, "oversized description rejected")
	broken = data.duplicate(true)
	broken.nodes[2].choices[0].text = "海".repeat(21)
	check(not p.load_story(broken).ok, "oversized choice rejected")
	broken = data.duplicate(true)
	broken.nodes[0].text = "海\n".repeat(40)
	check(not p.load_story(broken).ok, "multi-paragraph text must be split into nodes")
	print("STORY PLAYER: %d checks, %d failures" % [total, failures])
	quit(0 if failures == 0 else 1)
