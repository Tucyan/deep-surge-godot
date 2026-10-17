extends SceneTree
var failures := 0
var page
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func capture(id: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/story-page-" + id + ".png")
func click(control: Control) -> void:
	var pos := control.get_global_transform() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
func run() -> void:
	root.size = Vector2i(1600, 900)
	var module = load("res://pages/story_page.gd")
	check(module != null, "standalone story page exists")
	if module == null:
		quit(1)
		return
	page = module.new()
	root.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.4).timeout
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://story/demo_story.json"))
	check(page.load_story(data).ok, "page loads story")
	for image_control in page.find_children("*", "TextureRect", true, false):
		check(image_control.texture == null or not image_control.texture.resource_path.begins_with("res://"), "story page uses no image assets")
	await create_timer(0.15).timeout
	check(page.body.visible_characters < page.body.text.length(), "typewriter begins gradually")
	await click(page.next_button)
	check(page.body.visible_characters == -1, "first click reveals full line")
	await capture("dialogue-1600")
	await click(page.skip_button)
	check(page.player.get_view().node.id == "signal", "actual mouse skip stops at decision")
	check(page.choice_buttons.size() == 2 and page.choice_buttons[0].visible, "choices displayed above dialogue")
	await capture("choices-1600")
	await click(page.log_button)
	check(page.log_overlay.visible, "mouse opens log")
	var before: Dictionary = page.player.get_view()
	var chars: int = page.body.visible_characters
	await create_timer(0.2).timeout
	page.advance()
	check(page.player.get_view() == before and page.body.visible_characters == chars, "log pauses playback and commands")
	await capture("log-1600")
	check(page.find_children("*", "ScrollContainer", true, false).size() == 1, "log uses continuous scrolling")
	for control in page.log_overlay.find_children("*", "Button", true, false):
		check(not "上一页" in control.text and not "下一页" in control.text, "log has no pagination buttons")
	await click(page.log_close)
	check(not page.log_overlay.visible, "close log returns to same line")
	await click(page.choice_buttons[0])
	check(page.player.get_view().node.id == "listen", "actual mouse chooses correct branch")
	check(page.player.get_log()[-2].choice_text != "", "selected choice in log")
	await click(page.next_button)
	root.size = Vector2i(1280, 720)
	await create_timer(0.1).timeout
	await capture("dialogue-1280")
	for button in [page.skip_button, page.log_button, page.next_button]:
		var transform: Transform2D = root.get_final_transform() * button.get_global_transform()
		var bounds := Rect2(transform * Vector2.ZERO, button.size * transform.get_scale())
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(bounds), "button inside small viewport")
	await click(page.skip_button)
	check(page.player.get_view().status == "completed", "page signals completion")
	await capture("completed-1280")
	var stress: Dictionary = data.duplicate(true)
	stress.nodes[2].text = "海".repeat(160)
	stress.nodes[2].description = "雾".repeat(80)
	stress.nodes[2].choices.append({"id":"third", "text":"绕过浮标，继续观察", "next":"sail"})
	check(page.load_story(stress).ok, "page can be reused with maximum-length content")
	page.skip()
	await process_frame
	var line_height: float = page.body.get_theme_font("font").get_height(page.body.get_theme_font_size("font_size"))
	check(page.body.size.y <= 100, "long text does not expand Label beyond dialogue area")
	check(page.body.get_line_count() * line_height <= page.body.size.y, "maximum dialogue fits text area")
	check(page.choice_buttons.size() == 3, "three-choice layout supported")
	await capture("three-choices-1280")
	page.open_log()
	await capture("log-1280")
	page.close_log()
	var long_story: Dictionary = data.duplicate(true)
	long_story.nodes = []
	long_story.entry = "line0"
	for i in range(20):
		var row := {"id": "line%d" % i, "speaker": "旁白", "text": "记录%d：" % i + "海".repeat(100)}
		if i < 19: row["next"] = "line%d" % (i + 1)
		long_story.nodes.append(row)
	check(page.load_story(long_story).ok, "long log fixture loads")
	page.skip()
	page.open_log()
	await create_timer(0.15).timeout
	var bar: VScrollBar = page.log_scroll.get_v_scroll_bar()
	check(bar.max_value > bar.page, "long log overflows viewport")
	check(absf(page.log_scroll.scroll_vertical - (bar.max_value - bar.page)) <= 1, "log opens at latest entry")
	check(page.log_text.text.find("记录0：") < page.log_text.text.find("记录19："), "log order is oldest to newest")
	page.log_scroll.scroll_vertical = 0
	await process_frame
	check(page.log_scroll.scroll_vertical == 0 and page.player.get_view().status == "completed", "scrolling preserves playback")
	page.close_log()
	page.open_log()
	await create_timer(0.15).timeout
	check(absf(page.log_scroll.scroll_vertical - (bar.max_value - bar.page)) <= 1, "reopening returns to bottom")
	await capture("log-scroll-1280")
	page.queue_free()
	await process_frame
	print("STORY PAGE GPU: " + ("PASS" if failures == 0 else "FAIL") + ", failures=" + str(failures))
	quit(0 if failures == 0 else 1)
