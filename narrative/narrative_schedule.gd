extends RefCounted
## Pure trigger rule: narrative beats open only at stable game boundaries and
## may be gated by affection alone. No game state is read here.
##
## A checkpoint is every beat sharing the same `after_voyage`. At each due
## checkpoint the highest-priority beat whose affinity requirement is met wins;
## the rest are reported as skipped so they never resurface later.

static func completed_voyages(voyage: int, phase: String, length: int) -> int:
	if phase == "chapterComplete": return length
	if phase == "navigation" and voyage > 1: return voyage - 1
	return -1

## Returns {} (nothing due), {"beat": beat} or {"skip": [ids]}.
static func evaluate(content, applied: Array, skipped: Array, affinity: Dictionary, voyage: int, phase: String) -> Dictionary:
	var done := completed_voyages(voyage, phase, content.length)
	if done < 0: return {}
	var groups := {}
	var order: Array = []
	for beat in content.beats:
		var after := int(beat.get("after_voyage", 0))
		if after > done: continue
		if not groups.has(after):
			groups[after] = []
			order.append(after)
		groups[after].append(beat)
	order.sort()
	for after in order:
		var pending: Array = []
		for beat in groups[after]:
			var id := str(beat.get("id", ""))
			if applied.has(id) or skipped.has(id): continue
			pending.append(beat)
		if pending.is_empty(): continue
		pending.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))
		for beat in pending:
			if meets(beat, affinity): return {"beat": beat}
		var ids: Array = []
		for beat in pending: ids.append(str(beat.get("id", "")))
		return {"skip": ids}
	return {}

## Conditions are affection-only by design. An absent block always passes.
static func meets(entry: Dictionary, affinity: Dictionary) -> bool:
	for char_id in entry.get("requires_affinity", {}):
		if int(affinity.get(str(char_id), 0)) < int(entry.requires_affinity[char_id]):
			return false
	return true
