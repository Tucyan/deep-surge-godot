extends SceneTree
const Apps = preload("res://tests/helpers/challenge_app.gd")
var total := 0
var failures := 0
func check(ok: bool, reason: String) -> void:
	total += 1
	if not ok: failures += 1; printerr("FAIL: " + reason)
func _init() -> void: call_deferred("run")
func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func run() -> void:
	var directory := "user://challenge-resume-" + str(Time.get_ticks_usec())
	var app = Apps.create(self, directory)
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":22})
	app.handle_command("voyage", {"id":app.session.state.candidates[0].visit_id})
	var expected: Dictionary = app.session.snapshot()
	check(same(app.store.read(),expected), "formal autosave retains entire challenge checkpoint")
	app.queue_free(); await process_frame
	app = Apps.create(self, directory)
	check(same(app.session.snapshot(),expected), "actual entry restores challenge state, profile and random streams")
	check(app.session.screen == "home", "restart waits at home")
	if app.session.state.is_empty():
		app.queue_free(); await process_frame
		print("CHALLENGE RESUME: %d checks, %d failures" % [total,failures]); quit(1); return
	var before: Dictionary = app.session.snapshot()
	app.hud_view(); app.hud_view()
	app.handle_ui("local_panel", "help"); app.handle_ui("local_panel", "")
	check(app.session.snapshot() == before, "view and cancel do not alter checkpoint or RNG")
	var title = app.current_page.get_child(0)
	app.current_page.select_mode(title)
	check(app.current_page.find_child("ContinueChallenge",true,false) != null, "home offers explicit continue challenge")
	var clone = app.Session.new(app.catalog)
	check(clone.restore(before), "uninterrupted comparison clone")
	clone.dispatch("resume")
	app.handle_command("resume")
	check(app.session.snapshot() == clone.snapshot(), "continue follows same rules as uninterrupted session")
	clone.dispatch("salvage"); app.handle_command("salvage")
	check(app.session.snapshot() == clone.snapshot(), "post-restore action has identical resources and RNG")
	check(same(app.store.read(),app.session.snapshot()), "post-restore actions are durable")
	before = app.session.snapshot()
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":23})
	check(app.session.snapshot() == before, "new challenge waits for replacement confirmation")
	app.handle_ui("cancel_replacement")
	check(app.session.snapshot() == before, "cancel replacement preserves active challenge")
	app.handle_command("new", {"mode":"challenge", "origin":"invalid", "seed":23, "replace_current":true})
	check(app.session.snapshot() == before, "invalid replacement preserves checkpoint")
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":23, "replace_current":true})
	check(app.session.state.seed == 23 and same(app.store.read(),app.session.snapshot()), "confirmed new challenge commits complete candidate")
	app.handle_command("abandon")
	check(app.session.phase() == "finished", "challenge terminates")
	var terminal: Dictionary = app.session.snapshot()
	app.queue_free(); await process_frame
	app = Apps.create(self,directory)
	check(same(app.session.snapshot(),terminal), "terminal checkpoint retains settlement without rewarding again")
	check(not app.hud_view().get("can_resume", true), "terminal does not offer active resume")
	app.current_page.select_mode(app.current_page.get_child(0))
	var summary = app.current_page.find_child("LastChallengeSettlement",true,false)
	check(summary != null and str(summary.text).contains(str(terminal.last_settlement.outcome_name)), "home displays actual retained last settlement")
	app.queue_free(); await process_frame
	print("CHALLENGE RESUME: %d checks, %d failures" % [total,failures])
	quit(0 if failures == 0 else 1)
