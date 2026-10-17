extends SceneTree
var failures := 0
var app: Control

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + why)

func _init() -> void:
	call_deferred("run")

func settle() -> void:
	await process_frame
	await process_frame

func capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	img.save_png(path)
	print("Saved screenshot: " + path)

func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await settle()
	
	app.handle_command("new", {"mode": "challenge", "origin": "strong", "seed": 42})
	for id in ["wood", "wood", "wood", "wood", "wood", "wood", "iron", "plastic", "rope"]:
		app.session.give(id, 1, false, "fixture")
	app.session.state.ap = 3
	app.render()
	await settle()
	
	# Open craft panel
	app.handle_command("panel", {"id": "craft"})
	await settle()
	
	# Switch to transmute tab
	app.handle_ui("craft_tab", "transmute")
	await settle()
	
	# Verify CloseX does not overlap TransmuteTabButton
	var close_x = app.find_child("CloseX", true, false)
	var transmute_tab = app.find_child("TransmuteTabButton", true, false)
	check(close_x != null and transmute_tab != null, "CloseX and TransmuteTabButton exist")
	if close_x and transmute_tab:
		var close_rect = Rect2(close_x.global_position, close_x.size)
		var tab_rect = Rect2(transmute_tab.global_position, transmute_tab.size)
		check(not close_rect.intersects(tab_rect), "No overlap between CloseX and TransmuteTabButton")
		print("CloseX Rect: ", close_rect, " Tab Rect: ", tab_rect)
	
	var s1 = app.find_child("DiagramSlot1", true, false)
	var out = app.find_child("DiagramOutputSlot", true, false)
	check(s1 != null and out != null, "DiagramSlot1 and DiagramOutputSlot exist")
	
	# Capture Transmute 3-column view
	await capture("res://evidence/verify_transmute_tab.png")
	
	# Show explicitly selected inputs (the page no longer auto-selects).
	var uids: Array = app.session.state.hand.filter(func(c): return c.id == "wood").slice(0, 3).map(func(c): return c.uid)
	app.handle_ui("transmute_uids", ",".join(uids))
	await settle()
	await capture("res://evidence/verify_transmute_selected.png")
	
	app.queue_free()
	await settle()
	
	print("VISUAL TRANSMUTE VERIFICATION: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
