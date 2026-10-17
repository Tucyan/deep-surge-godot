extends SceneTree
var failures := 0
var app
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)
func settle() -> void:
	for i in range(5): await process_frame
func click(control: Control) -> void:
	var position := root.get_final_transform() * control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = position; Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position = position
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; Input.parse_input_event(event)
		await process_frame
	await settle()
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate(); app.persistence = false
	root.add_child(app); await settle()
	app.handle_command("new", {"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("home"); app.handle_command("panel", {"id":"encyclopedia"}); await settle()
	var before: Dictionary = app.session.snapshot()
	var grid = app.current_page.find_child("EncyclopediaGrid",true,false)
	check(grid != null, "Encyclopedia has a preview card grid")
	if grid == null:
		app.queue_free(); await settle(); quit(1); return
	check(app.current_page.find_child("DetailCopy",true,false).text == "在航程中发现后解锁详情。", "Undiscovered details stay hidden")
	for config in [Vector3(1600,900,1),Vector3(1280,720,1),Vector3(1280,720,1.25),Vector3(1920,820,1.25)]:
		root.size = Vector2i(config.x,config.y); app.display_settings.free_aspect = true
		app.display_settings.ui_scale = config.z; app.apply_display_settings(false); app.render(); await settle()
		grid = app.current_page.find_child("EncyclopediaGrid",true,false)
		var detail = app.current_page.find_child("EncyclopediaDetail",true,false)
		var surface = app.layout.find_child("ModalSurface",true,false)
		check(surface.global_position.distance_to(app.global_position) < 1 and surface.size.distance_to(app.size) < 1, "Encyclopedia fills the screen within container pixel rounding")
		check(grid.columns == 3 and grid.get_child_count() == 6, "Three columns and two rows")
		check(grid.size.x > detail.get_parent().size.x, "Card area takes the larger left side")
		for card in grid.get_children():
			var cover = card.find_child("Cover",true,false); var title = card.find_child("EntryTitle",true,false)
			check(title.get_global_rect().position.y >= cover.get_global_rect().end.y, "Title sits below preview")
			check(card.get_global_rect().encloses(title.get_global_rect()), "Title fits card")
		check(app.get_global_rect().encloses(detail.get_global_rect()), "Details fit viewport")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/encyclopedia-%dx%d-%d.png" % [config.x,config.y,roundi(config.z*100)])
	# Both image and title are pointer targets for their containing card.
	await click(grid.get_child(1).find_child("Cover",true,false))
	check(app.ui_state.selected_id == app.catalog.table("cards").keys()[1], "Image selects entry")
	grid = app.current_page.find_child("EncyclopediaGrid",true,false)
	await click(grid.get_child(0).find_child("EntryTitle",true,false))
	check(app.ui_state.selected_id == app.catalog.table("cards").keys()[0], "Title selects entry")
	await click(app.current_page.find_child("EncyclopediaStoryTab",true,false))
	check(app.ui_state.get("encyclopedia_tab") == "story", "Story tab switches")
	await click(app.current_page.find_child("EncyclopediaDescriptionTab",true,false))
	check(app.ui_state.get("encyclopedia_tab") == "description", "Description tab switches")
	var known_id := ""
	for id in app.catalog.table("cards"):
		if "card."+id in app.session.profile.discovered: known_id = id; break
	check(known_id != "", "Legal new run discovers resource entries")
	app.handle_ui("selected_id",known_id); await settle()
	check(app.current_page.find_child("DetailCopy",true,false).text == app.catalog.entry("cards",known_id).description, "Discovered entry shows its real description")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/encyclopedia-discovered.png")
	await click(app.current_page.find_child("EncyclopediaStoryTab",true,false))
	check(app.current_page.find_child("DetailCopy",true,false).text == "故事内容暂未收录。", "Missing story uses an honest placeholder")
	app.handle_ui("list_page","1"); await settle()
	check(app.current_page.find_child("EncyclopediaGrid",true,false).get_child(0).get_meta("entry_id") == app.catalog.table("cards").keys()[6], "Pagination selects next six entries")
	for category in ["enemies","relics","endings"]:
		app.handle_ui("category",category); await settle()
		check(app.current_page.selected_table == category, "Category switches: " + category)
	check(app.session.snapshot() == before, "Browsing preserves session, discovery and RNG")
	await click(app.layout.find_child("CloseX",true,false))
	check(app.session.panel == "", "Top-right X closes the full-screen page")
	app.queue_free(); await settle()
	print("encyclopedia GPU: %d failures" % failures); quit(1 if failures else 0)
