extends SceneTree
var failures := 0
var app
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)
func settle() -> void:
	await process_frame; await process_frame
func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/chapter1-" + label + ".png")
func click(button: Control) -> void:
	var pos := button.get_global_transform() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new(); motion.position = pos
	root.push_input(motion, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
		root.push_input(event, true)
		await process_frame
func find_button(text: String) -> Button:
	for button in app.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree(): return button
	return null
func run() -> void:
	root.size = Vector2i(1600,900)
	app = load("res://scenes/main.tscn").instantiate(); app.persistence = false
	root.add_child(app); await settle()
	app.narrative_store = load("res://adapters/narrative_store.gd").new("user://chapter1-visual")
	await click(app.find_child("Title_start", true, false))
	check(find_button("剧情模式") != null, "mode chooser opens by mouse")
	await capture("mode-1600")
	await click(find_button("剧情模式"))
	check(app.layout.find_child("NarrativeName",true,false) != null,"story picker opens only after mode choice")
	await capture("slots-1600")
	app.pick_new_narrative("第一章试玩")
	check(app.current_page.chosen_difficulty == "standard", "story defaults to formal difficulty")
	app.current_page.find_child("NewGameNext",true,false).pressed.emit()
	await settle()
	app.current_page.find_child("StartVoyage",true,false).pressed.emit()
	await settle()
	check(app.narrative_playing,"first story automatically plays")
	app.narrative_overlay.advance()
	await capture("dialogue-1600")
	app.narrative_overlay.skip()
	await settle()
	check(app.narrative_overlay.choice_buttons.size() == 2,"first source choices visible")
	await capture("choices-1600")
	for resolution in [Vector2i(1600,900),Vector2i(1280,720)]:
		root.size = resolution
		await settle()
		for button in app.narrative_overlay.choice_buttons:
			check(button.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,"long choices wrap")
			var transform: Transform2D = root.get_final_transform() * button.get_global_transform()
			var bounds := Rect2(transform * Vector2.ZERO, button.size * transform.get_scale())
			check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(bounds),"choice fits viewport")
		await capture("choices-%d" % resolution.x)
	# Stress the longest options plus disabled item gates, with the live VN page.
	app._close_narrative()
	var story = load("res://narrative/narrative_session.gd").new(app.narrative_content)
	story.new_save("门槛预览"); story.begin("C1-N10")
	app.narrative = story
	app._open_narrative(story.prepare_scene())
	app.narrative_overlay.skip()
	app.narrative_overlay.choose("n10_investigate")
	app.narrative_overlay.skip()
	await settle()
	check(app.narrative_overlay.choice_buttons.size() == 3,"disabled branches include return path")
	check(app.narrative_overlay.choice_buttons[0].disabled and app.narrative_overlay.choice_buttons[1].disabled,"missing item branches disabled")
	await capture("locked-1280")
	app.narrative_overlay.choose("return_to_rest")
	check(app.narrative_overlay.player.get_view().node.id.begins_with("n10_rest"),"fallback returns to original rest text")
	app._close_narrative()
	app.queue_free(); await process_frame
	print("CHAPTER1 GPU: " + ("PASS" if failures == 0 else "FAIL") + ", failures=" + str(failures))
	quit(0 if failures == 0 else 1)
