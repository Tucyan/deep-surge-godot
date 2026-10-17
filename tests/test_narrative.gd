extends SceneTree
## Headless checks for the independent narrative layer: content, affection-gated
## branching, idempotent application and multi-slot storage.
var failures := 0
var total := 0

func check(ok: bool, reason: String) -> void:
	total += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + reason)

func _init() -> void:
	call_deferred("run")

func choice_ids(scene: Dictionary, node_id: String) -> Array:
	for node in scene.get("nodes", []):
		if str(node.get("id", "")) == node_id:
			var ids: Array = []
			for choice in node.get("choices", []): ids.append(str(choice.id))
			return ids
	return []

func run() -> void:
	var Content = load("res://narrative/narrative_content.gd")
	var Session = load("res://narrative/narrative_session.gd")
	var Store = load("res://adapters/narrative_store.gd")
	var content = Content.new()
	check(content.load_content(), "narrative content loads: " + content.error)
	if content.length == 0:
		print("NARRATIVE: %d checks, %d failures" % [total, failures])
		quit(1)
		return
	check(content.length == 15, "first chapter is 15 voyages")
	check(content.beats.size() == 6, "five checkpoints with one extra branch variant")
	check(content.characters.size() == 2, "two affinity characters")

	# --- Scheduling: only stable boundaries may open a beat ---
	var s = Session.new(content)
	s.new_save("测试档")
	check(s.next_beat(1, "navigation").is_empty(), "no beat on first departure")
	check(s.next_beat(3, "preparation").is_empty(), "preparation never opens a beat")
	check(s.next_beat(4, "battle").is_empty(), "battle never opens a beat")
	var beat = s.next_beat(4, "navigation")
	check(beat.get("id", "") == "L1-B03", "third completed voyage opens B03")

	# --- Scene and choice effects ---
	var scene = s.begin("L1-B03")
	check(scene.get("id", "") == "L1.s03", "beat opens its declared scene")
	var prepared = s.prepare_scene()
	check(choice_ids(prepared, "n2").size() == 2, "unconditional options survive preparation")
	check(s.begin("L1-B03").is_empty(), "an open beat cannot be opened twice")
	var changes = s.finish({"choices": [
		{"node_id": "n2", "choice_id": "answer"},
		{"node_id": "n4", "choice_id": "accept"}
	]})
	check(int(changes.affinity.get("leader", 0)) == 10, "choice affinity applied")
	check(int(s.affinity().get("leader", 0)) == 10, "affinity stored on the save")
	check(s.flags().has("convoy"), "choice flag stored")
	check(s.applied_count() == 1, "applied beat recorded once")
	check(s.begin("L1-B03").is_empty(), "applied beat never replays")
	check(s.next_beat(4, "navigation").is_empty(), "no duplicate beat right after applying")
	var again = s.finish({"choices": [{"node_id": "n2", "choice_id": "answer"}]})
	check(again.affinity.is_empty() and int(s.affinity().leader) == 10, "finish without an open beat cannot double count")

	# --- Catch-up order and low-affection branch ---
	check(s.next_beat(7, "navigation").get("id", "") == "L1-B06", "next beat catches up at voyage 7")
	for id in ["L1-B06", "L1-B09"]:
		s.begin(id)
		s.finish({"choices": []})
	var branch = s.next_beat(13, "navigation")
	check(branch.get("id", "") == "L1-B12-far", "low affection selects the distant variant")
	check(branch.get("scene", "") == "L1.s12b", "distant variant has its own scene")
	s.begin("L1-B12-far")
	s.finish({"choices": [{"node_id": "n2", "choice_id": "reply"}]})
	check(s.next_beat(13, "navigation").is_empty(), "sibling variant never plays later")
	check(s.export_data().state.skipped_beats.has("L1-B12-close"), "unmet variant is recorded as skipped")

	# --- High-affection branch on the same checkpoint ---
	var high = Session.new(content)
	var crafted = s.export_data()
	crafted.state.affinity = {"leader": 60, "carpenter": 0}
	crafted.state.applied_beats = ["L1-B03", "L1-B06", "L1-B09"]
	crafted.state.skipped_beats = []
	check(high.load_data(crafted), "crafted high-affection save loads")
	check(high.next_beat(13, "navigation").get("id", "") == "L1-B12-close", "high affection selects the close variant")
	high.begin("L1-B12-close")
	high.finish({"choices": [{"node_id": "n3", "choice_id": "leader"}]})
	check(high.export_data().state.skipped_beats.has("L1-B12-far"), "low variant is skipped after the close variant")

	# --- Affection-gated option inside a scene ---
	var finale = s.next_beat(15, "chapterComplete")
	check(finale.get("id", "") == "L1-B15", "finale opens on chapter completion")
	s.begin("L1-B15")
	var low_scene = s.prepare_scene()
	check(choice_ids(low_scene, "n3") == ["ask", "decide"], "gated option hidden at low affection")
	s.finish({"choices": [{"node_id": "n4", "choice_id": "seal"}]})
	check(s.flags().has("ending_seal"), "finale choice records an ending flag")

	var high2 = Session.new(content)
	high2.load_data(crafted)
	high2.next_beat(13, "navigation")
	high2.begin("L1-B12-close")
	high2.finish({"choices": []})
	high2.next_beat(15, "chapterComplete")
	high2.begin("L1-B15")
	var high_scene = high2.prepare_scene()
	check(choice_ids(high_scene, "n3").has("stay"), "gated option appears at high affection")

	# --- Save round trip and tolerance ---
	var saved = s.export_data()
	var copy = Session.new(content)
	check(copy.load_data(saved), "narrative save restores")
	check(int(copy.affinity().get("leader", 0)) == int(s.affinity().get("leader", 0)), "affinity survives a round trip")
	check(copy.flags().has("convoy"), "flags survive a round trip")
	check(copy.applied_count() == 5, "applied beats survive a round trip")
	check(copy.next_beat(15, "chapterComplete").is_empty(), "restored save skips all fixed beats")
	check(copy.export_data().state.skipped_beats.has("L1-B12-close"), "skipped variants survive a round trip")
	var broken = saved.duplicate(true)
	broken.state.affinity.leader = 999
	var clamped = Session.new(content)
	check(clamped.load_data(broken) and int(clamped.affinity().leader) == 100, "affinity is clamped on load")
	broken = saved.duplicate(true)
	broken.state.applied_beats = ["L2-unknown"]
	var tolerant = Session.new(content)
	check(tolerant.load_data(broken), "unknown applied beat does not block loading")
	check(not tolerant.next_beat(4, "navigation").is_empty(), "unknown beat is ignored, real beat still due")
	broken = saved.duplicate(true)
	broken.schema = 9
	check(not Session.new(content).load_data(broken), "unsupported save schema rejected")

	# --- Multi-slot storage ---
	var test_dir := "user://narrative-test"
	var absolute := ProjectSettings.globalize_path(test_dir)
	if DirAccess.dir_exists_absolute(absolute):
		for file in DirAccess.get_files_at(test_dir):
			DirAccess.remove_absolute(absolute + "/" + file)
	var store = Store.new(test_dir)
	var first: String = store.create_id()
	check(first.begins_with("nar-"), "store creates a stable id")
	check(store.write(first, saved), "store writes a new slot: " + store.error)
	check(store.active_id() == first, "written slot becomes active")
	check(store.read(first).get("label", "") == "测试档", "store reads back the slot")
	check(store.list_saves().size() == 1, "slot list has one entry")
	var second: String = store.create_id()
	check(store.write(second, saved), "store writes a second slot")
	check(store.list_saves().size() == 2, "slot list has two entries")
	check(store.set_active(second) and store.active_id() == second, "active slot can be switched")
	check(store.set_active(""), "active slot can be detached")
	check(store.active_id() == "", "detach clears the active id")
	check(not store.write("../evil", saved), "path traversal ids are rejected")
	check(store.read("nar-missing").is_empty(), "missing slot reads empty")
	var reopened = Store.new(test_dir)
	check(reopened.list_saves().size() == 2, "slots survive reopening the store")

	print("NARRATIVE: %d checks, %d failures" % [total, failures])
	quit(0 if failures == 0 else 1)
