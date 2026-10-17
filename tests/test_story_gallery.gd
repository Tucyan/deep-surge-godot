extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)
func run() -> void:
	var script = load("res://adapters/story_gallery_store.gd")
	if script == null:
		check(false, "Story gallery archive exists"); quit(1); return
	var catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(), "Catalog loads")
	var session = load("res://core/game_session.gd").new(catalog)
	var archive = script.new()
	archive.path = "user://story-gallery-test.json"
	if FileAccess.file_exists(archive.path): DirAccess.remove_absolute(archive.path)
	check(archive.entries().size() == 1, "Opening is available without a run")
	check(archive.entries()[0].special and archive.entries()[0].id == "opening", "Opening counts as special story")
	check(session.dispatch("new", {"seed":22,"mode":"story","origin":"strong"}), "Start legal story run")
	check(session.dispatch("voyage", {"id":session.state.candidates[0].visit_id}), "Sail to tutorial")
	check(session.dispatch("enter"), "Enter first story")
	var before: Dictionary = session.snapshot()
	archive.capture(before, catalog)
	check(session.snapshot() == before, "Archiving never changes session or RNG")
	var same_version = load("res://core/game_session.gd").new(catalog)
	check(same_version.restore(before), "Existing same-version save still restores")
	check(archive.entries().size() == 2, "Only encountered story is collected")
	var entry: Dictionary = archive.entry("ST.L1.T01")
	check(entry.lines.size() == 1, "Unread continuation is not exposed")
	entry.lines.append("tampered")
	check(archive.entry("ST.L1.T01").lines.size() == 1, "Replay data is a copy")
	var bypassed: Dictionary = before.duplicate(true)
	bypassed.state.campaign.ledger["ST.L1.S04"] = {"status":"bypassed","visit_id":"test","voyage":1}
	archive.capture(bypassed, catalog)
	check(archive.entry("ST.L1.S04").is_empty(), "Bypassed story is not unlocked")
	check(session.dispatch("advance"), "Read continuation")
	archive.capture(session.snapshot(), catalog)
	check(archive.entry("ST.L1.T01").lines.size() == 2, "Reading unlocks continuation")
	check(archive.save_archive() == OK, "Archive saves independently")
	var restored = script.new(); restored.path = archive.path
	restored.load_archive()
	check(restored.entries() == archive.entries(), "Archive survives app reload")
	check(session.dispatch("abandon"), "Finish old run through dispatch")
	check(session.dispatch("new", {"seed":23,"mode":"challenge","origin":"strong"}), "New run")
	restored.capture(session.snapshot(), catalog)
	check(restored.entries().size() == 2, "New run retains collected stories")
	DirAccess.remove_absolute(archive.path)
	var damaged := FileAccess.open(archive.path, FileAccess.WRITE)
	damaged.store_string("corrupt"); damaged.close()
	var rejected = script.new(); rejected.path = archive.path; rejected.load_archive()
	check(rejected.blocked and rejected.save_archive() != OK, "Invalid archive is rejected without overwrite")
	check(FileAccess.get_file_as_string(archive.path) == "corrupt", "Original invalid archive is preserved")
	DirAccess.remove_absolute(archive.path)
	var replay = load("res://presentation/opening_intro.gd").new()
	if replay.get_property_list().any(func(p): return p.name == "persist_completion"):
		replay.persist_completion = false
		replay.preference_path = "user://gallery-replay-opening-test.cfg"
		if FileAccess.file_exists(replay.preference_path): DirAccess.remove_absolute(replay.preference_path)
		root.add_child(replay); await process_frame
		replay.finish()
		check(not FileAccess.file_exists(replay.preference_path), "Replay never writes first-launch preference")
		replay.queue_free(); await create_timer(0.15).timeout
	else:
		check(false, "Opening supports read-only replay"); replay.free()
	var app = load("res://scenes/main.tscn").instantiate()
	check(app.get_property_list().any(func(p): return p.name == "persistence"), "Main scene preserves app root interface")
	app.free()
	print("story_gallery: %d failures" % failures)
	quit(1 if failures else 0)
