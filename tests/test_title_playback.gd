extends SceneTree
var failures := 0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func videos(node: Node) -> Array:
	var result: Array = []
	if node is VideoStreamPlayer: result.append(node)
	for child in node.get_children(): result.append_array(videos(child))
	return result
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await process_frame
	var player: VideoStreamPlayer = videos(app)[0]
	var player_id := player.get_instance_id()
	for action in ["journal", "shop", "recall"]:
		await create_timer(0.4).timeout
		var position := videos(app)[0].stream_position as float
		var title = app.layout.get_child(0).get_child(0)
		title.menu_action.emit(action)
		await process_frame
		check(videos(app).size() == 1, "Only one title video player")
		check(videos(app)[0].get_instance_id() == player_id, action + " preserves video player")
		check(videos(app)[0].stream_position >= position, action + " does not reset playback position")
		check(app.title_backdrop.is_visible_in_tree(), "Title background remains visible under panel")
		if action == "recall": app.handle_ui("local_panel", "")
		else: app.handle_command("close")
		await process_frame
		check(videos(app)[0].get_instance_id() == player_id, "Closing panel preserves video player")
	app.handle_ui("setup", "challenge")
	await process_frame
	app.handle_ui("setup", "")
	await process_frame
	check(videos(app)[0].get_instance_id() == player_id, "Returning from setup preserves video player")
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":22})
	await process_frame
	check(videos(app).is_empty(), "Leaving home releases title video")
	app.handle_command("home")
	await process_frame
	check(videos(app).size() == 1, "Returning home creates one video player")
	app.queue_free()
	await process_frame
	print("TITLE PLAYBACK: " + ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
