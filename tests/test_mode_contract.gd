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
	app.narrative.data.state.applied_beats = [str(app.narrative_content.beats[0].id)]
	app.pending_narrative = {"mode":"attach", "id":app.narrative_store.active_id()}
	var before: Dictionary = app.session.snapshot()
	var before_story: Dictionary = app.narrative.export_data()
	var game_id: int = app.session.get_instance_id()
	var story_id: int = app.narrative.get_instance_id()
	var pending: Dictionary = app.pending_narrative.duplicate(true)
	var slot: String = app.narrative_store.active_id()
	for invalid in [{"origin":"invalid"}, {"seed":-1}, {"starting_resources":["unknown"]}, {"revision":app.session.revision-1}]:
		var args := {"mode":"challenge", "origin":"strong", "seed":22}
		args.merge(invalid, true)
		app.handle_command("new",args)
		check(app.session.snapshot()==before and app.session.get_instance_id()==game_id, "rejected challenge retains gameplay session")
		check(app.narrative.export_data()==before_story and app.narrative.get_instance_id()==story_id, "rejected challenge retains narrative session")
		check(app.pending_narrative==pending and app.narrative_store.active_id()==slot, "rejected challenge retains pending selection and slot binding")
		check(not app.message.is_empty(), "rejection reports its validation error")
	# A command stamped by the currently displayed story page remains valid when
	# the candidate challenge is constructed; its revision must not reset to zero.
	app.handle_command("new",{"mode":"challenge", "origin":"strong", "seed":22, "revision":before.revision})
	check(app.session.state.get("mode","")=="challenge", "valid challenge commits candidate")
	check(app.session.get_instance_id()!=game_id and app.narrative.get_instance_id()!=story_id, "valid switch replaces the session pair together")
	check(not app.narrative.has_save() and app.pending_narrative.is_empty(), "valid challenge clears only in-memory narrative")
	check(app.narrative_store.active_id()==slot and app.narrative_store.read(slot).get("gameplay",{}).get("state",{}).get("mode","")=="story", "valid challenge preserves stored story slot")
	app.queue_free()
	await process_frame
	print("MODE CONTRACT: %d checks, %d failures" % [total,failures])
	quit(0 if failures == 0 else 1)
