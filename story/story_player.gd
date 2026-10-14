extends RefCounted
## Standalone narrative state; no GameSession, scene or gameplay mutations.
signal completed(result: Dictionary)
var _story: Dictionary = {}
var _nodes: Dictionary = {}
var _current := ""
var _status := "idle"
var _history: Array = []
var _choices: Array = []

func _error(message: String) -> Dictionary:
	return {"ok":false, "error":message}

func load_story(data: Variant) -> Dictionary:
	if not data is Dictionary or data.get("schema_version") != 1:
		return _error("Unsupported story schema")
	if not data.get("id") is String or data.id.is_empty() or not data.get("title") is String:
		return _error("Story id/title required")
	if data.title.length() > 40: return _error("Title exceeds 40 characters")
	if "\n" in data.title or "\r" in data.title: return _error("Title must be a single paragraph")
	if not data.get("nodes") is Array or data.nodes.is_empty():
		return _error("Story nodes required")
	var index: Dictionary = {}
	for node in data.nodes:
		if not node is Dictionary or not node.get("id") is String or node.id.is_empty() or index.has(node.id):
			return _error("Invalid or duplicate node id")
		if not node.get("text") is String or node.text.is_empty() or node.text.length() > 160:
			return _error("Node text must contain 1..160 characters")
		for field in ["speaker", "description", "next"]:
			if node.has(field) and not node[field] is String:
				return _error("Node field must be a string: " + field)
		if node.get("speaker", "").length() > 24 or node.get("description", "").length() > 80:
			return _error("Speaker/description exceeds layout limits")
		for field in ["text", "speaker", "description"]:
			if "\n" in node.get(field, "") or "\r" in node.get(field, ""):
				return _error("Split paragraphs into separate story nodes")
		if not node.get("choices", []) is Array or node.get("choices", []).size() > 3:
			return _error("At most three choices per node")
		if not node.get("choices", []).is_empty() and not node.get("next", "").is_empty():
			return _error("Choices and next are exclusive")
		var ids: Array = []
		for choice in node.get("choices", []):
			if not choice is Dictionary:
				return _error("Choice must be an object")
			for field in ["id", "text", "next"]:
				if not choice.get(field) is String or choice[field].is_empty():
					return _error("Choice id/text/next required")
			if ids.has(choice.id) or choice.text.length() > 20:
				return _error("Duplicate choice or choice text too long")
			if "\n" in choice.text or "\r" in choice.text: return _error("Choice text must be a single paragraph")
			ids.append(choice.id)
		index[node.id] = node.duplicate(true)
	if not data.get("entry") is String or not index.has(data.entry):
		return _error("Entry does not exist")
	for node in index.values():
		if not node.get("next", "").is_empty() and not index.has(node.next):
			return _error("Next does not exist")
		for choice in node.get("choices", []):
			if not index.has(choice.next):
				return _error("Choice target does not exist")
	# All nodes must form a finite DAG, including unreachable authoring leftovers.
	var marks: Dictionary = {}
	for id in index:
		if _has_cycle(id, index, marks):
			return _error("Story cycles are not supported")
	_story = data.duplicate(true)
	_nodes = index
	_history = []
	_choices = []
	_status = "playing"
	_enter(data.entry)
	return {"ok":true}

func _has_cycle(id: String, index: Dictionary, marks: Dictionary) -> bool:
	if marks.get(id, 0) == 1: return true
	if marks.get(id, 0) == 2: return false
	marks[id] = 1
	var node: Dictionary = index[id]
	var targets: Array = []
	if not node.get("next", "").is_empty(): targets.append(node.next)
	for choice in node.get("choices", []): targets.append(choice.next)
	for target in targets:
		if _has_cycle(target, index, marks): return true
	marks[id] = 2
	return false

func _enter(id: String) -> void:
	_current = id
	var node: Dictionary = _nodes[id]
	_history.append({"node_id":id, "speaker":node.get("speaker", "旁白"), "text":node.text,
		"description":node.get("description", ""), "choice_id":"", "choice_text":""})

func get_view() -> Dictionary:
	return {"story_id":_story.get("id", ""), "title":_story.get("title", ""), "status":_status,
		"node":_nodes.get(_current, {}).duplicate(true), "log_count":_history.size()}

func get_log() -> Array:
	return _history.duplicate(true)

func advance() -> Dictionary:
	if _status != "playing": return _error("Story is not playing")
	var node: Dictionary = _nodes[_current]
	if not node.get("choices", []).is_empty(): return _error("Choice required")
	if node.get("next", "").is_empty(): _finish("finished")
	else: _enter(node.next)
	return {"ok":true}

func choose(choice_id: String) -> Dictionary:
	if _status != "playing": return _error("Story is not playing")
	for choice in _nodes[_current].get("choices", []):
		if choice.id == choice_id:
			_history[-1].choice_id = choice.id
			_history[-1].choice_text = choice.text
			_choices.append({"node_id":_current, "choice_id":choice.id})
			_enter(choice.next)
			return {"ok":true}
	return _error("Unknown choice")

func skip() -> Dictionary:
	if _status != "playing": return _error("Story is not playing")
	while _nodes[_current].get("choices", []).is_empty():
		var target: String = _nodes[_current].get("next", "")
		if target.is_empty():
			_finish("skipped")
			break
		_enter(target)
	return {"ok":true}

func _finish(reason: String) -> void:
	_status = "completed"
	completed.emit({"story_id":_story.id, "reason":reason, "choices":_choices.duplicate(true)})
