extends RefCounted
## Narrative save state and commands. Independent from GameSession:
## reads no game state and writes no gameplay value.
const Schedule = preload("res://narrative/narrative_schedule.gd")

const SAVE_SCHEMA := 1
const AFFINITY_MIN := 0
const AFFINITY_MAX := 100

var content: RefCounted
var data: Dictionary = {}
var error := ""
var current_beat: Dictionary = {}
var current_scene: Dictionary = {}

func _init(content_ref: RefCounted) -> void:
	content = content_ref

func has_save() -> bool:
	return not data.is_empty()

## Detaches without deleting the stored slot.
func clear() -> void:
	data = {}
	current_beat = {}
	current_scene = {}

func new_save(label: String) -> void:
	var stamp := int(Time.get_unix_time_from_system())
	data = {
		"schema": SAVE_SCHEMA,
		"chapter": content.chapter,
		"version": content.version,
		"label": label if not label.strip_edges().is_empty() else "未命名剧情",
		"created_at": stamp,
		"updated_at": stamp,
		"state": {
			"affinity": {},
			"flags": {},
			"applied_beats": [],
			"skipped_beats": [],
			"seen_scenes": [],
			"choices": [],
			"cursor": {"beat_id": "", "scene_id": ""},
			"prefs": {"skip_seen": true}
		}
	}

func load_data(save: Variant) -> bool:
	if not save is Dictionary or int(save.get("schema", 0)) != SAVE_SCHEMA:
		return _fail("剧情存档版本无效")
	var state: Variant = save.get("state")
	if not state is Dictionary: return _fail("剧情存档缺少状态")
	# A different narrative version is readable: unknown applied beats are ignored,
	# and scenes always come from the current content.
	var affinity := {}
	for id in state.get("affinity", {}):
		if content.character(str(id)).is_empty(): continue
		affinity[str(id)] = clampi(int(state.affinity[id]), AFFINITY_MIN, AFFINITY_MAX)
	var flags := {}
	for id in state.get("flags", {}):
		if state.flags[id] == true: flags[str(id)] = true
	var applied: Array = []
	for id in state.get("applied_beats", []):
		if id is String and not applied.has(id): applied.append(id)
	var skipped: Array = []
	for id in state.get("skipped_beats", []):
		if id is String and not skipped.has(id): skipped.append(id)
	var seen: Array = []
	for id in state.get("seen_scenes", []):
		if id is String and not seen.has(id): seen.append(id)
	var choices: Array = []
	for entry in state.get("choices", []):
		if not entry is Dictionary or not entry.get("choice_id") is String: continue
		choices.append({"beat_id":str(entry.get("beat_id", "")), "node_id":str(entry.get("node_id", "")), "choice_id":str(entry.choice_id)})
	data = {
		"schema": SAVE_SCHEMA,
		"chapter": str(save.get("chapter", content.chapter)),
		"version": str(save.get("version", content.version)),
		"label": str(save.get("label", "剧情存档")),
		"created_at": int(save.get("created_at", 0)),
		"updated_at": int(save.get("updated_at", 0)),
		"state": {
			"affinity": affinity,
			"flags": flags,
			"applied_beats": applied,
			"skipped_beats": skipped,
			"seen_scenes": seen,
			"choices": choices,
			"cursor": {"beat_id":"", "scene_id":""},
			"prefs": {"skip_seen": bool(state.get("prefs", {}).get("skip_seen", true))}
		}
	}
	current_beat = {}
	current_scene = {}
	return true

func export_data() -> Dictionary:
	return data.duplicate(true)

## Resolves the next due checkpoint. Condition-failed variants are recorded as
## skipped so a later checkpoint can never resurrect them.
func next_beat(voyage: int, phase: String) -> Dictionary:
	if data.is_empty(): return {}
	var decision: Dictionary = Schedule.evaluate(content, data.state.applied_beats, data.state.skipped_beats, affinity(), voyage, phase)
	if decision.has("skip"):
		for id in decision.skip:
			if not data.state.skipped_beats.has(id): data.state.skipped_beats.append(id)
		return {}
	return decision.get("beat", {})

## Filtered scene for the player: options the current affection does not allow
## are removed. Content validation guarantees at least one unconditional option.
func prepare_scene() -> Dictionary:
	var scene: Dictionary = current_scene.duplicate(true)
	for node in scene.get("nodes", []):
		if node.get("choices", []).is_empty(): continue
		var kept: Array = []
		for choice in node.choices:
			if Schedule.meets(choice, affinity()): kept.append(choice)
		node.choices = kept
	return scene

## Opens a beat and returns its scene definition, or {} when it cannot play.
func begin(beat_id: String) -> Dictionary:
	if data.is_empty() or not current_beat.is_empty(): return {}
	if data.state.applied_beats.has(beat_id): return {}
	var beat: Dictionary = content.beat(beat_id)
	if beat.is_empty(): return {}
	var scene: Dictionary = content.scenes.get(str(beat.scene), {})
	if scene.is_empty(): return {}
	current_beat = beat
	current_scene = scene
	data.state.cursor = {"beat_id":beat_id, "scene_id":str(beat.scene)}
	return scene

## Applies a StoryResult exactly once. Returns the visible changes for the caller.
func finish(result: Dictionary) -> Dictionary:
	error = ""
	var changes := {"beat_id":"", "affinity":{}, "flags":[], "label":""}
	if current_beat.is_empty(): return changes
	var beat_id := str(current_beat.id)
	if data.state.applied_beats.has(beat_id):
		current_beat = {}; current_scene = {}
		return changes
	# Choices were displayed using the affinity at scene entry, before any of
	# this result's rewards. Forged results must obey that same eligibility.
	var eligible_affinity := affinity()
	for entry in result.get("choices", []):
		if not entry is Dictionary: continue
		var choice := _choice(_node(str(entry.get("node_id", ""))), str(entry.get("choice_id", "")))
		if not choice.is_empty() and not Schedule.meets(choice, eligible_affinity):
			error = "该剧情选项的好感度条件未满足"
			return changes
	for entry in result.get("choices", []):
		if not entry is Dictionary: continue
		var node: Dictionary = _node(str(entry.get("node_id", "")))
		var choice: Dictionary = _choice(node, str(entry.get("choice_id", "")))
		if choice.is_empty() or not Schedule.meets(choice, eligible_affinity): continue
		data.state.choices.append({"beat_id":beat_id, "node_id":str(entry.node_id), "choice_id":str(entry.choice_id)})
		for char_id in choice.get("affinity", {}):
			var id := str(char_id)
			if content.character(id).is_empty(): continue
			var before := int(data.state.affinity.get(id, 0))
			var after := clampi(before + int(choice.affinity[char_id]), AFFINITY_MIN, AFFINITY_MAX)
			data.state.affinity[id] = after
			if after != before: changes.affinity[id] = int(changes.affinity.get(id, 0)) + (after - before)
		for flag in choice.get("set_flags", []):
			var flag_id := str(flag)
			if flag_id == "" or data.state.flags.has(flag_id): continue
			data.state.flags[flag_id] = true
			changes.flags.append(flag_id)
	data.state.applied_beats.append(beat_id)
	for sibling in content.beats:
		if int(sibling.get("after_voyage", 0)) != int(current_beat.get("after_voyage", 0)): continue
		var sibling_id := str(sibling.get("id", ""))
		if sibling_id != beat_id and not data.state.skipped_beats.has(sibling_id):
			data.state.skipped_beats.append(sibling_id)
	if not data.state.seen_scenes.has(str(current_beat.scene)): data.state.seen_scenes.append(str(current_beat.scene))
	data.state.cursor = {"beat_id":"", "scene_id":""}
	data.updated_at = int(Time.get_unix_time_from_system())
	changes.beat_id = beat_id
	changes.label = str(content.beat(beat_id).get("scene", ""))
	current_beat = {}
	current_scene = {}
	return changes

func affinity() -> Dictionary:
	return data.get("state", {}).get("affinity", {}).duplicate(true)

func flags() -> Dictionary:
	return data.get("state", {}).get("flags", {}).duplicate(true)

func applied_beats() -> Array:
	return data.get("state", {}).get("applied_beats", []).duplicate()

func applied_count() -> int:
	return content.applied_count(applied_beats())

func label() -> String:
	return str(data.get("label", ""))

func summary() -> Array:
	var rows: Array = []
	for id in content.characters:
		var value := int(affinity().get(id, 0))
		rows.append({"id":id, "name":content.character(id).name, "value":value,
			"level":content.affinity_level(id, value)})
	return rows

func _node(id: String) -> Dictionary:
	for node in current_scene.get("nodes", []):
		if str(node.get("id", "")) == id: return node
	return {}

func _choice(node: Dictionary, id: String) -> Dictionary:
	for choice in node.get("choices", []):
		if str(choice.get("id", "")) == id: return choice
	return {}

func _fail(message: String) -> bool:
	error = message
	return false
