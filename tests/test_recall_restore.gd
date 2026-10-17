extends SceneTree
var failures := 0
var total := 0

func _init() -> void: call_deferred("run")
func check(ok: bool, reason: String) -> void:
	total += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + reason)
func settle() -> void:
	await process_frame
	await process_frame
func run() -> void:
	root.size = Vector2i(1600, 900)
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await settle()
	var before: Dictionary = app.session.snapshot()
	var narrative_before: Dictionary = app.narrative.export_data()
	app.find_child("Title_recall", true, false).pressed.emit()
	await settle()
	var gallery = app.layout.find_child("StoryGallery", true, false)
	check(gallery != null, "title recall button opens the gallery")
	if gallery != null:
		var card = gallery.find_child("StoryCard_opening", true, false)
		check(card != null, "opening is available without a completed run")
		card.pressed.emit()
		await settle()
		check(is_instance_valid(app.story_replay), "opening card starts replay")
		check(app.story_replay.scenes.size() == 5, "all five opening scenes preserved")
		check(not app.story_replay.persist_completion, "replay never writes first-launch preference")
		app.story_replay.finish()
		await settle()
		check(not is_instance_valid(app.story_replay) and is_instance_valid(gallery), "exit returns to gallery")
		app.story_gallery.records["legacy.test"] = {"id":"legacy.test", "title":"旧记录", "subtitle":"航程剧情", "special":false, "art":"opening.image.03", "lines":["已接触正文"], "results":["已选结果"]}
		app.render()
		await settle()
		app.layout.find_child("StoryCard_legacy_test", true, false).pressed.emit()
		await settle()
		check(app.story_replay.scenes.size() == 2, "legacy record replays archived prose and results")
		app.story_replay.finish()
		await settle()
	check(app.session.snapshot() == before, "review leaves gameplay and RNG unchanged")
	check(app.narrative.export_data() == narrative_before, "review leaves independent narrative unchanged")
	app.queue_free()
	await settle()
	print("RECALL RESTORE: %d checks, %d failures" % [total, failures])
	quit(1 if failures else 0)
