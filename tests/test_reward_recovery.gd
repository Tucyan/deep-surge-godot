extends SceneTree
## Real I/O failures, paired slot reloads and a fresh shared-profile restore.
var total := 0
var failures := 0

func check(ok: bool, reason: String) -> void:
	total += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + reason)

func _init() -> void: call_deferred("run")

func scenario(block_slot: bool, bad_ending: bool) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await process_frame
	var directory := "user://reward-recovery-" + str(Time.get_ticks_usec())
	app.narrative_store = load("res://adapters/narrative_store.gd").new(directory)
	app.store.path = directory + "/profile.json"
	app.meta.path = directory + "/meta.json"
	app.persistence = true
	app.pending_narrative = {"mode":"new", "label":"reward recovery"}
	app.handle_command("new", {"mode":"story", "origin":"strong", "seed":22})
	app._close_narrative()
	app.narrative.current_beat = {}; app.narrative.current_scene = {}
	app.session.state.voyage = 4; app.session.state.completed = 3
	app.session.EnvironmentRules.start_round(app.session)
	app.session.Rules.candidates(app.session)
	app.narrative.data.state.applied_beats = ["C1-N01", "C1-N02", "C1-N03"]
	if not bad_ending: app.narrative.data.state.applied_beats.append("C1-N04")
	check(app.save_narrative_quiet(), "pre-ending slot saved")
	check(app._persist_profile(), "pre-ending profile saved")
	var slot_id: String = app.narrative_store.active_id()
	var run_id: String = app.session.state.run_id
	var stale: Dictionary = app.narrative_store.read(slot_id)
	var blocked: String = app.narrative_store.path_of(slot_id) if block_slot else app.store.path
	var tmp := ProjectSettings.globalize_path(blocked + ".tmp")
	check(DirAccess.make_dir_absolute(tmp) == OK, "temporary target blocked")
	var result := {}
	if bad_ending:
		app.narrative.begin("C1-N04")
		var player = load("res://story/story_player.gd").new()
		player.completed.connect(func(value): result.merge(value, true))
		check(player.load_story(app.narrative.prepare_scene()).ok, "bad ending loads")
		player.skip(); player.choose("n04_refuse"); player.skip()
		app._on_narrative_completed(result)
	else:
		app.handle_command("abandon")
	check(app.session.profile.points == 3, "initial settlement grants three points")
	check(not app.message.is_empty(), "write failure is visible")
	if not block_slot:
		var retry = app.Session.new(app.catalog)
		check(retry.restore(app.store.read()), "restart with pending shared write")
		app.session = retry
		check(app.load_story_run(slot_id), "recover while shared file remains blocked")
		check(app.session.profile.points == 3 and not app.message.is_empty(), "recovery retains credit and exposes retry failure")
	check(DirAccess.remove_absolute(tmp) == OK, "I/O failure removed")
	if not block_slot:
		app.save_narrative()
		check(app.store.read().profile.points == 3, "explicit save retries pending shared reward")
		check(app.message == "剧情进度已保存" and app.store.error.is_empty(), "successful retry clears the storage failure")
	# Simulate startup from the actual shared file; do not reuse credited memory.
	var fresh = app.Session.new(app.catalog)
	check(fresh.restore(app.store.read()), "shared profile restores after restart")
	app.session = fresh
	check(app.load_story_run(slot_id), "paired slot reloads after restart")
	if block_slot:
		if bad_ending:
			app.narrative_overlay.skip()
			app.narrative_overlay.choose("n04_refuse")
			app.narrative_overlay.skip()
		else:
			app.handle_command("abandon")
	check(app.session.profile.points == 3, "reload and repeat/recover never duplicates or loses points")
	check(app.store.read().profile.points == 3, "recovered reward is durable")
	# Spent points and later purchases must survive loading an ended slot.
	app.session.profile.points = 1
	app.session.profile.purchases.inheritance = 1
	check(app._persist_profile(), "later shared changes saved")
	check(app.load_story_run(slot_id), "ended slot reloads repeatedly")
	check(app.session.profile.points == 1, "already claimed reward does not refund spent points")
	check(app.session.profile.purchases.inheritance == 1, "loading preserves later shared purchases")
	# A copied pre-ending backup still belongs to the exact same run.
	check(app.narrative_store.write("nar-copy", stale), "copy stale slot")
	check(app.load_story_run("nar-copy"), "stale copy loads")
	if bad_ending:
		app.narrative_overlay.skip()
		app.narrative_overlay.choose("n04_refuse")
		app.narrative_overlay.skip()
	else:
		app.handle_command("abandon")
	check(app.session.profile.points == 1, "copied slot cannot claim same run twice")
	check(app.session.state.run_id == run_id, "copy preserves run identity")
	app.persistence = false
	app.queue_free()
	await process_frame

func receipt_validation() -> void:
	var catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(), "catalog loads for save validation")
	var game = load("res://core/game_session.gd").new(catalog)
	check(game.dispatch("new", {"mode":"story", "origin":"strong", "seed":22}), "validation story starts")
	var old: Dictionary = game.snapshot()
	var copy = load("res://core/game_session.gd").new(catalog)
	check(copy.restore(old), "older saves without reward receipts remain readable")
	game.state.completed = 3
	check(game.dispatch("abandon"), "validation run settles")
	var saved: Dictionary = game.snapshot()
	check(copy.restore(JSON.parse_string(JSON.stringify(saved))), "new receipts survive JSON round trip")
	var before: Dictionary = copy.snapshot()
	for invalid in [[], {"": {"points":3, "result":"abandon"}}, {"run":[]}, {"run":{"points":-1, "result":"abandon"}}, {"run":{"points":1.5, "result":"abandon"}}, {"run":{"points":3, "result":false}}]:
		var broken := saved.duplicate(true)
		broken.profile.run_rewards = invalid
		check(not copy.restore(broken) and copy.snapshot() == before, "bad receipt is rejected atomically")
	var shared: Dictionary = old.profile.duplicate(true)
	check(not game.Rewards.recover(shared, saved.state, old.profile) and shared == old.profile, "legacy ended slots never retroactively award points")
	var source: Dictionary = saved.profile.duplicate(true)
	source.run_rewards["unrelated"] = {"points":7, "result":"dead"}
	check(game.Rewards.recover(shared, saved.state, source) and shared.points == 3, "only current run's missing receipt is recovered")
	check(not shared.run_rewards.has("unrelated"), "unrelated receipts are not imported")
	check(not game.Rewards.recover(shared, saved.state, source) and shared.points == 3, "repeated recovery is idempotent")

func run() -> void:
	receipt_validation()
	for block_slot in [true, false]:
		for bad_ending in [true, false]:
			await scenario(block_slot, bad_ending)
	print("REWARD RECOVERY: %d checks, %d failures" % [total, failures])
	quit(0 if failures == 0 else 1)
