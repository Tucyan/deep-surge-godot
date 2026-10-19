extends SceneTree
## Controller-owned, isolated-process probe. Never run against player user data.
const Session = preload("res://core/game_session.gd")
const Acquisition = preload("res://application/acquisition_projection.gd")
var checks := 0
var failures := 0
var config: Dictionary = {}
var app

func _init() -> void:
	call_deferred("run")

func check(value: bool, why: String) -> bool:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + why)
	return value

func read_json(path: String) -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "open output " + path): return
	file.store_string(JSON.stringify(value)); file.flush(); file.close()

func normalized(value):
	return JSON.parse_string(JSON.stringify(value))

func finish() -> void:
	print("CHALLENGE PROBE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func route(path: String) -> Dictionary:
	var trace := read_json(path)
	check(trace.get("initial", {}).get("content_version", "") == Session.VERSION, "route version is current")
	check(trace.get("initial", {}).get("fingerprint", "") == app.catalog.fingerprint(), "route fingerprint is current")
	return trace

func plan() -> void:
	var found: Dictionary = {}
	for name in ["standard-challenge", "hard-challenge", "nightmare-challenge"]:
		var path: String = "res://tests/fixtures/routes/" + str(name) + ".trace.json"
		var trace := route(path)
		var game = Session.new(app.catalog)
		if not check(game.restore(trace.initial), "plan route restores " + name): continue
		game.screen = "game"
		for index in range(-1, trace.steps.size()):
			var automatic := false
			var reward := false
			if index >= 0:
				var step: Dictionary = trace.steps[index]
				var old_voyage: int = game.state.voyage
				var cursor := Acquisition.capture(game)
				if not check(game.dispatch(step.command, step.args), "plan legal command %s/%d: %s" % [name,index,game.error]): break
				automatic = int(game.state.voyage) > old_voyage and step.command != "end_voyage"
				reward = not Acquisition.batches(game, cursor).is_empty() and step.command == "salvage"
			var labels: Array = []
			var phase: String = game.phase()
			# Existing reviewed policies avoid shops. Take a legal public branch
			# from their real navigation state, rather than fabricating shop state.
			if phase == "navigation" and (not found.has("shop") or not found.has("collectible")):
				for candidate in game.state.candidates:
					if candidate.get("kind", "") != "shop": continue
					var branch: Array = [{"command":"voyage","args":{"id":candidate.visit_id}}, {"command":"enter","args":{}}, {"command":"advance","args":{}}, {"command":"shop_enter","args":{}}]
					var shop = Session.new(app.catalog)
					var legal: bool = shop.restore(game.snapshot())
					shop.screen = "game"
					for move in branch:
						if legal: legal = shop.dispatch(move.command, move.args)
					if legal and shop.phase() == "interaction":
						if not found.has("shop"): found.shop = {"name":"shop", "route":path, "step":index, "branch":branch.duplicate(true)}
						if not found.has("collectible"):
							var quote: Dictionary = shop.Shop.view(shop)
							var cheapest: Dictionary = {}
							for relic in quote.relic_stock:
								if cheapest.is_empty() or relic.price < cheapest.price: cheapest = relic
							if not cheapest.is_empty():
								for card in quote.sellable:
									if shop.state.coins >= cheapest.price: break
									var sale := {"command":"sell", "args":{"uid":card.uid}}
									if shop.dispatch(sale.command, sale.args): branch.append(sale)
								var purchase := {"command":"buy_collectible", "args":{"id":cheapest.id, "payment":"coin"}}
								if shop.dispatch(purchase.command, purchase.args):
									branch.append(purchase)
									found.collectible = {"name":"collectible", "route":path, "step":index, "branch":branch.duplicate(true)}
						if found.has("collectible"): break
			if phase in ["navigation", "preparation", "battle", "aftermath", "finished"]: labels.append(phase)
			if phase == "story" and game.state.story_step == "choice" and game.state.node.kind != "shop": labels.append("event")
			if phase == "interaction": labels.append("shop")
			if automatic: labels.append("automatic_voyage")
			if reward: labels.append("reward_prompt")
			if phase == "finished" and not found.has("terminal_unsaved") and index >= 0:
				found.terminal_unsaved = {"name":"terminal_unsaved", "route":path, "step":index-1, "fail_command":trace.steps[index]}
			for label in labels:
				if not found.has(label): found[label] = {"name":label, "route":path, "step":index}
	for required in ["navigation", "preparation", "event", "shop", "collectible", "battle", "aftermath", "finished", "terminal_unsaved", "automatic_voyage", "reward_prompt"]:
		check(found.has(required), "real current routes cover " + required)
	write_json(str(config.output), {"checkpoints":found.values(), "checks":checks, "failures":failures})
	finish()

func command(command_name: String, args: Dictionary = {}) -> bool:
	var before: int = app.session.revision
	app.handle_command(command_name, args)
	return check(app.session.revision > before, "FlowApp accepts " + command_name + ": " + app.message)

func writer() -> void:
	var trace := route(str(config.route))
	var initial: Dictionary = trace.initial.state
	if not command("new", {"mode":"challenge", "origin":initial.origin, "seed":initial.seed, "difficulty":initial.difficulty}): finish(); return
	var target: int = int(config.step)
	var defer_pages: bool = str(config.get("name", "")) in ["terminal_unsaved", "finished", "collectible"]
	# Use the production transition's presentation deferral for the long route.
	# Dispatch, persistence and every complete-snapshot comparison still run.
	app._defer_transition_render = defer_pages
	var moves: Array = trace.steps.slice(0, target + 1) if target >= 0 else []
	moves.append_array(config.get("branch", []))
	for index in range(moves.size()):
		var step: Dictionary = moves[index]
		var control = Session.new(app.catalog)
		if not check(control.restore(app.session.snapshot()), "uninterrupted clone restores"): finish(); return
		control.screen = app.session.screen; control.panel = app.session.panel
		if not check(control.dispatch(step.command, step.args), "uninterrupted command is legal"): finish(); return
		if config.get("name", "") == "reward_prompt" and index == moves.size()-1:
			app.request_command(step.command, step.args)
			for frame in range(180):
				await process_frame
				if is_instance_valid(app.acquisition_overlay): break
			check(is_instance_valid(app.acquisition_overlay), "real acquisition prompt is visible before crash")
		else:
			if not command(step.command, step.args): finish(); return
		if not check(normalized(app.session.snapshot()) == normalized(control.snapshot()), "FlowApp matches uninterrupted full command snapshot at %d" % index): finish(); return
		if not check(app.store.read() == normalized(app.session.snapshot()), "every command's complete snapshot is durable at %d" % index): finish(); return
		# Render replaces pages via queue_free. Release old pages each operation,
		# as the live application does, instead of retaining an entire voyage UI.
		await process_frame
	app._defer_transition_render = false
	if defer_pages:
		await app.render()
		await process_frame
	var expected: Dictionary = normalized(app.session.snapshot())
	if config.get("name") == "collectible":
		check(not expected.state.collectibles.items.is_empty(), "real shop purchase creates held relic with effect counters")
	check(app.store.read() == expected, "checkpoint file equals every snapshot field")
	var next: Dictionary = trace.steps[target+1] if target+1 < trace.steps.size() else {}
	if config.has("branch"): next = {"command":"shop_leave", "args":{}}
	var extra: Dictionary = {}
	if config.has("fail_command"):
		var blocked := ProjectSettings.globalize_path(app.store.path + ".tmp")
		check(DirAccess.make_dir_absolute(blocked) == OK, "block real terminal write before settlement")
		next = config.fail_command
		command(next.command, next.args)
		check(app.session.phase() == "finished" and app.persistence_coordinator.save_pending, "real terminal reward granted in memory with failed persistence")
		check(app.store.read() == expected, "failed terminal write retains previous full checkpoint")
		extra = {"cleanup_tmp":blocked, "terminal_points":app.session.profile.points, "pending_snapshot":normalized(app.session.snapshot())}
	var output: Dictionary = {"snapshot":expected, "next":next, "user_dir":OS.get_user_data_dir(), "save_path":ProjectSettings.globalize_path(app.store.path), "checks":checks, "failures":failures}
	output.merge(extra)
	write_json(str(config.output), output)
	if failures > 0: finish(); return
	write_json(str(config.ready), {"ready":true, "run_id":expected.state.run_id, "revision":expected.revision})
	print("CRASH_PROBE_READY: " + str(config.name))
	# Remain alive: Python must terminate this process without normal quit hooks.

func reader() -> void:
	var expected := read_json(str(config.expected))
	var snapshot: Dictionary = expected.snapshot
	if config.get("reject", false):
		check(app.save_blocked, "bad checkpoint is protected on real startup")
		check(app.session.state.is_empty(), "bad checkpoint is not loaded")
		check(not app.message.is_empty(), "bad checkpoint rejection is visible")
		finish(); return
	check(not app.save_blocked, "startup accepts saved challenge")
	check(app.session.screen == "home", "real startup waits on home")
	check(normalized(app.session.snapshot()) == snapshot, "startup preserves complete snapshot, RNG, hand, cells, battle, relics, profile and revision")
	check(not is_instance_valid(app.acquisition_overlay), "startup does not replay old reward presentation")
	var before: Dictionary = normalized(app.session.snapshot())
	app.session.view(); app.session.view()
	check(normalized(app.session.snapshot()) == before, "home observations do not advance state or RNG")
	if app.session.active():
		var control = Session.new(app.catalog)
		check(control.restore(snapshot), "control restores checkpoint")
		control.auto_end_voyage = app.session.auto_end_voyage
		check(control.dispatch("resume"), "control resumes")
		command("resume")
		check(normalized(app.session.snapshot()) == normalized(control.snapshot()), "resume automatic rules exactly match uninterrupted control")
		var next: Dictionary = expected.get("next", {})
		if not next.is_empty():
			check(control.dispatch(next.command, next.args), "control next real route command succeeds")
			command(next.command, next.args)
			check(normalized(app.session.snapshot()) == normalized(control.snapshot()), "next route command matches every snapshot field")
			if expected.has("terminal_points"):
				check(app.session.phase() == "finished" and app.session.profile.points == expected.terminal_points, "recovered failed terminal settlement grants exactly the original reward once")
	else:
		check(app.session.phase() == "finished", "ended checkpoint remains terminal")
		check(normalized(app.session.snapshot()) == snapshot, "terminal startup never grants points again")
	write_json(str(config.output), {"checks":checks, "failures":failures, "snapshot":normalized(app.session.snapshot())})
	finish()

func fault() -> void:
	command("resume")
	var old_text := FileAccess.get_file_as_string(app.store.path)
	var target := ProjectSettings.globalize_path(app.store.path + ".tmp")
	if config.get("fault") == "rename":
		target = ProjectSettings.globalize_path(app.store.path)
		check(DirAccess.rename_absolute(target, target + ".old") == OK, "preserve previous checkpoint for rename fault")
	check(DirAccess.make_dir_absolute(target) == OK, "inject real directory collision")
	if config.get("fault") == "rename":
		var sentinel := FileAccess.open(target + "/occupied", FileAccess.WRITE)
		sentinel.store_string("force nonempty-directory replacement failure"); sentinel.close()
	command("abandon")
	check(app.persistence_coordinator.save_pending, "I/O failure leaves pending snapshot")
	var pending: Dictionary = normalized(app.session.snapshot())
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":23, "replace_current":true})
	check(normalized(app.session.snapshot()) == pending, "pending save blocks new rule session")
	check(FileAccess.get_file_as_string(app.store.path if config.get("fault") != "rename" else app.store.path + ".old") == old_text, "last complete checkpoint is intact")
	if config.get("fault") == "rename":
		check(DirAccess.remove_absolute(target + "/occupied") == OK, "remove collision sentinel")
	check(DirAccess.remove_absolute(target) == OK, "remove collision directory")
	if config.get("fault") == "rename":
		check(DirAccess.rename_absolute(target + ".old", target) == OK, "restore previous complete checkpoint")
	app.handle_ui("retry_save")
	check(not app.persistence_coordinator.save_pending, "retry_save clears pending state")
	check(app.store.read() == pending, "retry_save persists exact pending terminal snapshot")
	app.handle_ui("retry_save")
	check(app.store.read() == pending, "repeated retry never duplicates settlement reward")
	write_json(str(config.output), {"checks":checks, "failures":failures, "snapshot":pending})
	finish()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		check(false, "requires isolated controller config path"); finish(); return
	config = read_json(args[0])
	if not check(config.get("isolated", false) and OS.get_environment("DEEP_SURGE_CRASH_PROBE") == "isolated", "controller isolation marker required"):
		finish(); return
	var intro := ConfigFile.new()
	intro.set_value("opening", "watched", true)
	check(intro.save("user://opening-intro.cfg") == OK, "isolated opening marked watched before startup")
	if config.get("mode") == "write":
		var source := read_json(str(config.route))
		var difficulty: String = source.get("initial", {}).get("state", {}).get("difficulty", "standard")
		if difficulty in ["hard", "nightmare"]:
			# Account prerequisite fixture only; voyage state still comes exclusively
			# from real new/route commands in the main scene.
			var meta = load("res://adapters/meta_store.gd").new()
			meta.record_clear("standard")
			if difficulty == "nightmare": meta.record_clear("hard")
			check(meta.write_meta(), "isolated difficulty prerequisite saved")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	print("CRASH_PROBE_INITIALIZED: " + str(config.mode))
	match str(config.mode):
		"plan": plan()
		"write": await writer()
		"read": reader()
		"fault": fault()
		_: check(false, "unknown probe mode"); finish()
