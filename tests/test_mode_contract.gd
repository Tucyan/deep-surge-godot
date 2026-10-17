extends SceneTree
var failures := 0
var total := 0
func check(ok: bool, why: String) -> void:
	total += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + why)
func _init() -> void: call_deferred("run")
func run() -> void:
	var catalog = load("res://content/catalog.gd").new()
	catalog.load_catalog()
	var Session = load("res://core/game_session.gd")
	var story = Session.new(catalog)
	var challenge = Session.new(catalog)
	story.dispatch("new",{"mode":"story","origin":"strong","seed":22})
	challenge.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	check(story.state.candidates == challenge.state.candidates,"same seeded candidate rules including early safety")
	check(story.state.rng == challenge.state.rng,"same gameplay random stream")
	story.state.voyage = 11
	story.EnvironmentRules.start_round(story)
	story.Rules.candidates(story)
	var candidate: Dictionary = story.state.candidates[0]
	check(story.Encounter.eligible(story,candidate),"last story destination is eligible")
	var restored = Session.new(catalog)
	check(restored.restore(story.snapshot()),"final navigation snapshot restores")
	check(story.dispatch("voyage",{"id":candidate.visit_id}),"can depart on story voyage eleven")
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await process_frame
	app.narrative_store = load("res://adapters/narrative_store.gd").new("user://mode-contract-"+str(Time.get_ticks_usec()))
	app.pending_narrative = {"mode":"new","label":"transaction"}
	app.handle_command("new",{"mode":"story","origin":"strong","seed":22})
	app._close_narrative()
	app.narrative.current_beat = {}; app.narrative.current_scene = {}
	var before: Dictionary = app.session.snapshot()
	var before_story: Dictionary = app.narrative.export_data()
	app.handle_command("new",{"mode":"challenge","origin":"invalid","seed":22})
	check(app.session.snapshot() == before,"invalid challenge start retains story run")
	check(app.narrative.export_data() == before_story,"invalid challenge start retains narrative")
	app.queue_free()
	await process_frame
	print("MODE CONTRACT: %d checks, %d failures" % [total,failures])
	quit(0 if failures == 0 else 1)
