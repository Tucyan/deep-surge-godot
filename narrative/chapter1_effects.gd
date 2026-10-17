extends RefCounted
## Pure narrative adapter. Validates a complete chosen path before committing
## any trust, clues, quest items, rest count or ending. Never touches GameSession.

static func available(condition: Dictionary, state: Dictionary) -> bool:
	if condition.has("clue_unlocked") and not state.get("clues", []).has(str(condition.clue_unlocked)): return false
	if condition.has("has_item") and not state.get("items", []).has(str(condition.has_item)): return false
	return true

static func prepare(scene: Dictionary, state: Dictionary) -> Dictionary:
	var result := scene.duplicate(true)
	for node in result.nodes:
		if node.has("rest_redirect") and int(state.get("rest_count", 0)) >= 2:
			node.next = node.rest_redirect
		for choice in node.get("choices", []):
			choice.disabled = not available(choice.get("condition", {}), state)
			choice.disabled_reason = "缺少前置线索或剧情道具；可以返回休息。" if choice.disabled else ""
	return result

static func resolve(scene: Dictionary, result: Dictionary) -> Dictionary:
	var index := {}
	for node in scene.nodes: index[node.id] = node
	var cursor: String = scene.entry
	var choices: Array = result.get("choices", [])
	var used := 0
	var effects: Array = []
	var visited := {}
	while cursor != "":
		if visited.has(cursor) or not index.has(cursor): return {"error":"剧情路径无效"}
		visited[cursor] = true
		var node: Dictionary = index[cursor]
		effects.append_array(node.get("narrative_effects", []))
		var options: Array = node.get("choices", [])
		if options.is_empty():
			cursor = str(node.get("next", ""))
			continue
		if used >= choices.size() or not choices[used] is Dictionary: return {"error":"剧情选项未完成"}
		var picked := {}
		for option in options:
			if str(choices[used].get("node_id", "")) == cursor and str(choices[used].get("choice_id", "")) == str(option.id): picked = option
		if picked.is_empty() or picked.get("disabled", false): return {"error":"剧情选项或前置条件无效"}
		effects.append_array(picked.get("narrative_effects", []))
		cursor = str(picked.next)
		used += 1
	if used != choices.size(): return {"error":"剧情结果包含未经过的分支"}
	return {"effects":effects}

static func apply_effects(state: Dictionary, effects: Array, changes: Dictionary) -> void:
	for effect in effects:
		var key := str(effect.key)
		match str(effect.action):
			"affinity":
				var before := int(state.affinity.get(key, 0))
				state.affinity[key] = clampi(before + int(effect.value), 0, 100)
				changes.affinity[key] = int(changes.affinity.get(key, 0)) + int(state.affinity[key]) - before
			"flag": state.flags[key] = true
			"clue":
				if not state.clues.has(key): state.clues.append(key)
			"item":
				if not state.items.has(key): state.items.append(key)
			"rest": state.rest_count += 1
			"ending":
				state.ending = key
				changes.ending = key
