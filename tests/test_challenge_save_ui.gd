extends SceneTree
const Apps = preload("res://tests/helpers/challenge_app.gd")
var total := 0
var failures := 0
func check(ok: bool, why: String) -> void:
	total += 1
	if not ok: failures += 1; printerr("FAIL: " + why)
func _init() -> void: call_deferred("run")
func capture(name: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://evidence/" + name + ".png") == OK,"save UI evidence " + name)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("FAIL: actual-window UI check requires --gpu"); quit(1); return
	root.size = Vector2i(1280,720)
	var app = Apps.create(self,"user://challenge-ui-" + str(Time.get_ticks_usec()))
	for i in range(15): await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("home")
	app.current_page.select_mode(app.current_page.get_child(0))
	for i in range(3): await process_frame
	var button = app.current_page.find_child("ContinueChallenge",true,false)
	check(button != null and button.is_visible_in_tree(),"continue challenge visible in actual window")
	if button != null:
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(button.get_global_rect()),"continue button fits window")
	await capture("challenge-resume-home")
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":23})
	check(app.find_child("ConfirmReplacement",true,false) != null,"replacement confirmation visible")
	await capture("challenge-replace-confirmation")
	app.handle_ui("cancel_replacement")
	app.handle_command("resume")
	var tmp := ProjectSettings.globalize_path(app.store.path + ".tmp")
	DirAccess.make_dir_absolute(tmp)
	app.handle_command("salvage")
	var retry = app.find_child("RetrySave",true,false)
	check(retry != null and retry.is_visible_in_tree(),"save failure exposes retry in actual window")
	await capture("challenge-save-failure")
	DirAccess.remove_absolute(tmp)
	app.handle_ui("retry_save")
	check(app.get_node_or_null("SaveFailureNotice") == null,"successful retry removes warning")
	# Let the normal recipe preheat queue drain before destroying GPU resources.
	for i in range(15): await process_frame
	app.queue_free(); await process_frame
	print("CHALLENGE SAVE UI: %d checks, %d failures" % [total,failures])
	quit(0 if failures == 0 else 1)
