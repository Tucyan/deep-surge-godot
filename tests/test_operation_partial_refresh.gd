extends SceneTree
## A continuing salvage action should refresh values without replacing stable HUD regions.
var app
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + why)

func settle(frames: int = 4) -> void:
	for i in range(frames): await process_frame

func node_id(node) -> int:
	return node.get_instance_id() if is_instance_valid(node) else 0

func stable_regions() -> Dictionary:
	var cells: Node = app.world_view.cells
	var cell = cells.get_child(0) if is_instance_valid(cells) and cells.get_child_count() > 0 else null
	return {
		"layout": node_id(app.layout),
		"hand": node_id(app.find_child("hand_fan", true, false)),
		"status": node_id(app.find_child("SurgeStatusHUD", true, false)),
		"interaction": node_id(app.find_child("RaftInteraction", true, false)),
		"cell": node_id(cell),
	}

func run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://flow_app.gd").new()
	app.persistence = false
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app)
	await settle()
	app.handle_command("new", {"mode": "challenge", "origin": "strong", "seed": 22})
	await settle()
	var destination: String = str(app.session.state.candidates[0].visit_id)
	app.select_navigation(destination)
	await settle()
	app.find_child("NavigationDepart", true, false).pressed.emit()
	await settle()
	check(app.session.phase() == "preparation", "voyage reaches the preparation operation phase")
	var before_state: Dictionary = app.session.snapshot()
	var before_regions := stable_regions()

	app.handle_command("salvage")
	await settle()
	check(app.session.snapshot() != before_state, "salvage changes the rule state")
	check(app.session.phase() == "preparation", "salvage remains in the same phase")
	check(stable_regions() == before_regions, "salvage retains stable HUD, hand, raft interaction and cell instances")
	check(app.current_page.context.revision == app.session.revision, "retained page context tracks the new revision")
	var live_fan=app.find_child("hand_fan",true,false)
	var displayed_uids: Array=[]
	for card in live_fan.cards: displayed_uids.append_array(card.get("stack_uids",[card.uid]))
	var expected_uids: Array=[]
	for card in app.session.view().hand: expected_uids.append(str(card.uid))
	displayed_uids.sort(); expected_uids.sort()
	check(displayed_uids==expected_uids, "retained hand fan reconciles the new salvage cards")

	app.queue_free()
	await process_frame
	print("OPERATION PARTIAL REFRESH: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
