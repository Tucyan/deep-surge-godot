extends SceneTree
var failures := 0
var app: Control
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func click_at(position: Vector2) -> void:
	position = root.get_final_transform() * position
	var motion := InputEventMouseMotion.new(); motion.position = position; Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		Input.parse_input_event(event); await process_frame
	await settle()
func escape() -> void:
	var key := InputEventKey.new(); key.keycode = KEY_ESCAPE; key.pressed = true
	Input.parse_input_event(key); await settle()
func shot(path: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/" + path + ".png")
func run() -> void:
	root.size = Vector2i(1600,900)
	app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app); await settle()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	app.handle_command("new", {"mode":"story","seed":22,"origin":"strong"})
	app.handle_command("voyage", {"id":app.session.state.candidates[0].visit_id})
	app.handle_command("enter")
	app.handle_command("advance")
	app.handle_command("abandon")
	app.handle_command("home")
	check(not app.session.last_settlement.is_empty(), "Existing report fixture is real")
	app.handle_ui("local_panel", "recall"); await settle()
	check(app.layout.find_child("StoryGallery",true,false) != null, "Recall opens gallery despite a saved settlement")
	var before: Dictionary = app.session.snapshot()
	for dimensions in [Vector2i(1600,900),Vector2i(1280,720),Vector2i(1920,820)]:
		root.size = dimensions; await settle()
		var card = app.layout.find_child("StoryCard_opening",true,false)
		check(card != null, "Special opening card is present")
		var title = card.find_child("StoryTitle",true,false)
		check(title.get_global_rect().position.y >= card.find_child("Cover",true,false).get_global_rect().end.y, "Title sits below image")
		check(card.get_global_rect().end.y <= root.size.y, "Cards fit the viewport")
		await shot("story-gallery-%dx%d" % [dimensions.x,dimensions.y])
	# A title click activates the same card as the image.
	var opening = app.layout.find_child("StoryCard_opening",true,false)
	await click_at(opening.find_child("StoryTitle",true,false).get_global_rect().get_center())
	check(is_instance_valid(app.story_replay) and app.story_replay.scenes.size()==5, "Title click replays complete opening")
	check(not app.story_replay.persist_completion, "Review disables first-launch preference writes")
	app.story_replay.advance()
	await shot("story-gallery-opening-replay")
	await escape()
	check(not is_instance_valid(app.story_replay), "Esc returns to the gallery")
	var regular = app.layout.find_child("StoryCard_ST_L1_T01",true,false)
	await click_at(regular.find_child("Cover",true,false).get_global_rect().get_center())
	check(is_instance_valid(app.story_replay) and app.story_replay.scenes.size()==2, "Image click reviews only archived lines")
	app.story_replay.advance()
	await shot("story-gallery-recorded-replay")
	await click_at(app.story_replay.find_child("OpeningExit",true,false).get_global_rect().get_center())
	check(not is_instance_valid(app.story_replay), "Return button restores gallery")
	check(app.session.snapshot() == before, "Browsing and all replays preserve session, rewards and RNG")
	# Pagination fixtures contain no unreached story information.
	for i in range(7):
		app.story_gallery.records["fixture.%d"%i] = {"id":"fixture.%d"%i,"title":"翻页测试片段%d"%i,"subtitle":"测试夹具","special":false,"art":"opening.image.03","lines":["用于验证分页。"],"results":[]}
	app.render(); await settle()
	var gallery = app.layout.find_child("StoryGallery",true,false)
	check(gallery.records.size()==9, "Nine test entries including special story")
	for step in range(2):
		var next: Button = gallery.nav.get_child(2)
		if not next.disabled: await click_at(next.get_global_rect().get_center())
	check(gallery.page_index > 0, "Next-page pointer interaction works")
	app.queue_free(); await create_timer(0.2).timeout
	print("story_gallery GPU: %d failures" % failures)
	quit(1 if failures else 0)
