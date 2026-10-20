extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + why)

func settle() -> void:
	await process_frame
	await process_frame

func node_id(app: Node, path: String) -> int:
	var node := app.find_child(path, true, false)
	return node.get_instance_id() if is_instance_valid(node) else 0

func run() -> void:
	root.size = Vector2i(1280, 720)
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await settle()
	app.handle_command("new", {"mode": "challenge", "origin": "strong", "seed": 22})
	app.session.give("wood", 3, false, "craft-partial-refresh-test")
	app.handle_command("panel", {"id": "craft"})
	app.handle_ui("craft_tab", "transmute")
	await settle()

	var page_id: int = app.current_page.get_instance_id()
	var revision_before: int = app.session.revision
	var snapshot_before: Dictionary = app.session.snapshot()
	var panel_id: int = node_id(app, "TransmutePanel")
	var material_id: int = node_id(app, "MatItem_wood")
	var output_id: int = node_id(app, "TransmuteOutputIcon")
	var input_slot_id: int = node_id(app, "DiagramSlot1")
	app.handle_ui("transmute_uids", str(app.session.state.hand.filter(func(card): return card.id == "wood")[0].uid))
	await settle()
	check(app.current_page.get_instance_id() == page_id, "material selection keeps the craft page instance")
	check(node_id(app, "TransmutePanel") == panel_id, "material selection keeps the transmute panel instance")
	check(node_id(app, "MatItem_wood") == material_id, "material selection keeps the material item instance")
	check(node_id(app, "TransmuteOutputIcon") == output_id, "material selection keeps the target preview instance")
	check(node_id(app, "DiagramSlot1") == input_slot_id, "material selection keeps the invested slot instance")
	check(node_id(app, "DiagramSlot1") != 0 and app.find_child("DiagramSlot1", true, false).get_child_count() > 0, "selected input appears in the retained slot")
	check(app.find_child("MatQuantity_wood", true, false).text == "1/3", "selected quantity updates in place")
	check(app.session.revision == revision_before and app.session.snapshot() == snapshot_before, "selection does not dispatch or alter rules and RNG")

	app.handle_ui("transmute_target", "iron")
	await settle()
	check(node_id(app, "TransmuteOutputIcon") == output_id, "target change keeps the output icon instance")
	check(app.ui_state.transmute_target == "iron", "target change remains in UI state")
	check(app.session.state.ap > 0, "selection changes do not dispatch a transmute")
	check(app.session.revision == revision_before and app.session.snapshot() == snapshot_before, "target change does not dispatch or alter rules and RNG")
	app.handle_ui("craft_tab", "craft")
	await settle()
	check(app.current_page.get_instance_id() == page_id, "switching to recipes keeps the craft page instance")
	app.handle_ui("craft_tab", "transmute")
	await settle()
	check(app.current_page.get_instance_id() == page_id, "switching back to transmute keeps the craft page instance")

	app.queue_free()
	await process_frame
	print("CRAFT PARTIAL REFRESH: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
