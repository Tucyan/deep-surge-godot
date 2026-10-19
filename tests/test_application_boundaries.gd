extends SceneTree
var failures := 0
var total := 0
func check(ok: bool, why: String) -> void:
	total += 1
	if not ok: failures += 1; printerr("FAIL: " + why)
func _init() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await process_frame
	if DisplayServer.get_name()!="headless":
		# The real app queues one recipe-page preheat job. Let it finish before
		# this otherwise synchronous test tears down the app and quits Godot.
		var art_ids: Array = []
		for recipe in app.catalog.table("recipes").keys().slice(0, app.PAGES.craft.PAGE_SIZE):
			art_ids.append("card."+str(app.catalog.entry("recipes", recipe).output))
		var frames := 0
		while frames<120 and art_ids.any(func(id): return not app.assets._cache.has(id)):
			await process_frame
			frames += 1
		check(frames<120, "queued art preheat completes before GPU teardown")
	var store = load("res://tests/helpers/counting_narrative_store.gd").new("user://architecture-slots-"+str(Time.get_ticks_usec()))
	var story = load("res://narrative/narrative_session.gd").new(app.narrative_content)
	story.new_save("first")
	var id: String = store.create_id()
	check(store.write(id, story.export_data()), "create real slot")
	app.narrative_store = store
	store.reads = 0
	for i in range(5):
		check(app.hud_view().has_story_saves, "HUD knows slots exist")
	check(store.reads == 0, "ordinary HUD does not parse narrative save files")
	var rows: Array = store.list_saves()
	var reads: int = store.reads
	store.list_saves()
	check(store.reads == reads, "slot metadata is reused between mutations")
	check(rows.size()==1 and rows[0].label=="first", "slot list uses stored metadata")
	story.data.label = "second"
	check(store.write(id, story.export_data()), "update slot")
	check(store.list_saves()[0].label=="second", "successful write invalidates metadata")
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":22})
	var before: Dictionary = app.session.snapshot()
	var signature: String = app._retained_hud_signature()
	app.session.state.logs.append("diagnostic-only log")
	app.session.state.stats.events.append({"diagnostic":true})
	check(app._retained_hud_signature()==signature, "history does not invalidate visible HUD")
	app.session.state.phase = "battle"
	var combat_signature: String = app._retained_hud_signature()
	app.session.state.logs.append("战斗记录：护盾抵挡伤害")
	check(app._retained_hud_signature()!=combat_signature, "visible combat logs invalidate battle HUD")
	app.session.state.phase = "navigation"
	app.session.state.player.hp -= 1
	check(app._retained_hud_signature()!=signature, "visible state invalidates HUD")
	app.session.state = before.state.duplicate(true)
	var layout_id: int = app.layout.get_instance_id()
	app.handle_ui("local_panel", "help")
	app.handle_ui("local_panel", "")
	check(app.layout.get_instance_id()==layout_id, "modal lifecycle retains HUD")
	check(app.session.snapshot()==before, "projection and modal operations preserve rules and RNG")
	app.queue_free()
	await process_frame
	print("APPLICATION BOUNDARIES: %d checks, %d failures" % [total, failures])
	quit(0 if failures==0 else 1)
