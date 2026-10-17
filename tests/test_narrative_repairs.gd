extends SceneTree
const Store = preload("res://adapters/narrative_store.gd")
const Content = preload("res://narrative/narrative_content.gd")
const Narrative = preload("res://narrative/narrative_session.gd")
var failures := 0
var total := 0

func check(ok: bool, reason: String) -> void:
	total += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + reason)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var content := Content.new()
	check(content.load_content(), "content loads")
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await process_frame
	var directory := "user://narrative-repairs-" + str(Time.get_ticks_usec())
	var store := Store.new(directory)
	app.narrative_store = store
	check(app.create_narrative("A"), "create original save")
	var original_id := store.active_id()
	var original: Dictionary = app.narrative.export_data()
	var other := Narrative.new(content)
	other.new_save("B")
	check(store.write("nar-b", other.export_data()), "create second slot")
	check(store.set_active(original_id), "restore active pointer")
	var working_pointer := store.active_path
	store.active_path = directory + "/missing/active.json"
	check(not app.attach_narrative("nar-b"), "failed pointer switch is rejected")
	check(app.narrative.export_data() == original, "failed switch retains original memory")
	check(store.active_id() == original_id, "failed switch retains active slot")
	check(not app.create_narrative("C"), "failed new slot is rejected")
	check(app.narrative.export_data() == original, "failed create retains original memory")
	check(store.active_id() == original_id, "failed create retains original binding")
	check(store.list_saves().size() == 2, "failed create leaves no orphan slot")
	var original_b := store.read("nar-b")
	other.new_save("B changed")
	check(not store.write("nar-b", other.export_data()), "failed bind rejects slot write")
	check(store.read("nar-b") == original_b, "failed pointer write restores existing slot data")
	check(store.active_id() == original_id, "failed write retains active id")
	store.active_path = working_pointer
	check(store.set_active(original_id) and store.error.is_empty(), "successful retry clears store error")
	check(app.narrative.export_data() == original, "retry does not replace original session")
	# A real unwritable temporary-file target, occupied by a directory.
	var blocked_tmp := ProjectSettings.globalize_path(store.path_of(original_id) + ".tmp")
	DirAccess.make_dir_absolute(blocked_tmp)
	app.narrative.begin("L1-B03")
	app._on_narrative_completed({"choices":[{"node_id":"n2", "choice_id":"answer"}]})
	check(app.message.contains("存档"), "autosave error remains visible after affinity gain")
	check(not store.error.is_empty(), "failed autosave reports store error")
	DirAccess.remove_absolute(blocked_tmp)
	app.save_narrative()
	check(app.message == "剧情进度已保存" and store.error.is_empty(), "save retry clears failure and confirms success")
	# Both the visible scene and result validation must enforce the same gate.
	app.narrative.new_save("gate")
	app.narrative.data.state.applied_beats = ["L1-B03", "L1-B06", "L1-B09", "L1-B12-close", "L1-B12-far"]
	app.session.state = {"mode":"story", "phase":"chapterComplete", "voyage":15}
	app.session.screen = "game"
	app._maybe_story()
	var visible: Array = app.narrative_overlay.player._story.nodes[2].choices
	check(not visible.any(func(c): return c.id == "stay"), "player scene omits unavailable ending")
	app._close_narrative()
	app.narrative.finish({"choices":[{"node_id":"n3", "choice_id":"stay"}]})
	check(not app.narrative.flags().has("ending_stay"), "forged unavailable choice cannot grant ending flag")
	check(app.narrative.affinity().is_empty(), "forged unavailable choice cannot grant affinity")
	check(not app.narrative.applied_beats().has("L1-B15"), "rejected result does not consume its beat")
	check(not app.narrative.current_beat.is_empty(), "rejected result leaves scene available for a valid retry")
	# Real fresh-save choices build enough affinity without editing save state.
	var fresh := Narrative.new(content)
	fresh.new_save("Reachable")
	for checkpoint in [4, 7, 10, 13]:
		var beat: Dictionary = fresh.next_beat(checkpoint, "navigation")
		if checkpoint == 13: check(beat.get("id") == "L1-B12-close", "friendly branch reachable from fresh save")
		fresh.begin(str(beat.get("id", "")))
		var player = load("res://story/story_player.gd").new()
		player.completed.connect(fresh.finish)
		player.load_story(fresh.prepare_scene())
		var guard := 0
		while player.get_view().get("status") == "playing" and guard < 80:
			guard += 1
			var node: Dictionary = player.get_view().node
			var best := {}
			for choice in node.get("choices", []):
				if best.is_empty() or int(choice.get("affinity", {}).get("leader", 0)) > int(best.get("affinity", {}).get("leader", 0)): best = choice
			if best.is_empty(): player.advance()
			else: player.choose(str(best.id))
	fresh.begin("L1-B15")
	var finale: Dictionary = fresh.prepare_scene()
	check(finale.nodes[2].choices.any(func(c): return c.id == "stay"), "gated ending reachable through real earlier choices")
	# A nightmare clear changes meta even though it unlocks no later difficulty.
	app.meta.path = directory + "/meta.json"
	app.session.state = {"phase":"chapterComplete", "result":"survived", "difficulty":"nightmare"}
	app._sync_meta_progress()
	var reloaded = load("res://adapters/meta_store.gd").new()
	reloaded.path = app.meta.path
	reloaded.read_meta()
	check(reloaded.cleared("nightmare"), "nightmare clear is persisted without a new unlock")
	app.queue_free()
	await process_frame
	print("NARRATIVE REPAIRS: %d checks, %d failures" % [total, failures])
	quit(0 if failures == 0 else 1)
