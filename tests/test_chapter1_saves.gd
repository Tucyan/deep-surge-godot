extends SceneTree
var total := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	total += 1
	if not ok: failures += 1; printerr("FAIL: " + reason)
func _init() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false
	root.add_child(app); await process_frame
	var directory := "user://chapter1-saves-" + str(Time.get_ticks_usec())
	app.narrative_store = load("res://adapters/narrative_store.gd").new(directory)
	app.store.path = directory + "/profile.json"
	app.meta.path = directory + "/meta.json"
	app.persistence = true
	app.session.profile.purchases.supply = 1
	app.session.profile.pending.supply = 1
	app.pending_narrative = {"mode":"new", "label":"A"}
	app.handle_command("new", {"mode":"story", "origin":"strong", "seed":22})
	check(app.store.read().get("profile", {}).get("pending", {}).get("supply", -1) == 0,"new story persists consumed shared supply")
	var id: String = app.narrative_store.active_id()
	app._close_narrative()
	app.narrative.current_beat = {}; app.narrative.current_scene = {}
	var before: Dictionary = app.session.snapshot()
	var original: Dictionary = app.narrative.export_data()
	var working: String = app.narrative_store.active_path
	app.narrative_store.active_path = directory + "/missing/active.json"
	app.pending_narrative = {"mode":"new", "label":"B"}
	app.handle_command("new", {"mode":"story", "origin":"strong", "seed":23})
	check(app.session.snapshot() == before,"failed new slot retains gameplay")
	check(app.narrative.export_data() == original,"failed new slot retains narrative")
	check(app.narrative_store.active_id() == id,"failed new slot retains binding")
	app.narrative_store.active_path = working
	# Semantically malformed and syntactically broken files stay visible, without
	# throwing from list_saves during every HUD render.
	for pair in [["nar-broken", "{"], ["nar-shape", '{"schema":1,"state":{},"gameplay":[]}']]:
		var file := FileAccess.open(app.narrative_store.path_of(pair[0]), FileAccess.WRITE)
		file.store_string(pair[1]); file.close()
	check(app.narrative_store.list_saves().size() == 3,"damaged slots are retained and listed safely")
	check(not app.load_story_run("nar-shape"),"malformed slot load rejected")
	check(app.session.snapshot() == before,"bad load preserves active run")
	var malformed := original.duplicate(true)
	malformed.state.items = {}
	check(not app.narrative.load_data(malformed),"malformed narrative collection rejected")
	check(app.narrative.export_data() == original,"malformed narrative load is atomic")
	# A bad ending uses the existing per-completed-node reward, persisted globally.
	app.session.state.voyage = 4; app.session.state.completed = 3
	app.session.EnvironmentRules.start_round(app.session)
	app.session.Rules.candidates(app.session)
	app.narrative.begin("C1-N04")
	var player = load("res://story/story_player.gd").new()
	var result := {}
	player.completed.connect(func(value): result.merge(value, true))
	player.load_story(app.narrative.prepare_scene())
	player.skip(); player.choose("n04_refuse"); player.skip()
	var points: int = app.session.profile.points
	app._on_narrative_completed(result)
	check(app.session.phase() == "finished", "bad ending closes story voyage")
	check(app.session.state.result == "story_bad_end", "bad ending gets truthful settlement label")
	check(app.session.profile.points == points + 3,"only local completed-node points are granted")
	check(app.store.read().profile.points == points + 3,"ending shared rewards survive restart")
	check(app.narrative_store.read(id).state.ending == "BAD_END_1","ending stored with paired run")
	check(app.narrative_store.read(id).gameplay.state.phase == "finished","ended run stored with narrative")
	app.persistence = false
	app.queue_free(); await process_frame
	print("CHAPTER1 SAVES: %d checks, %d failures" % [total, failures])
	quit(0 if failures == 0 else 1)
