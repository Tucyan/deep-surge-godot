extends RefCounted
## Keeps copies of encountered prose, independent from gameplay saves and rewards.
var path := "user://story-gallery-v1.json"
var error := ""
var blocked := false
var records: Dictionary = {}

func entries() -> Array:
	var result: Array = [{"id":"opening", "title":"潮水之后", "subtitle":"特殊剧情 · 开局序章", "special":true, "art":"opening.image.05", "lines":[], "results":[]}]
	for record in records.values(): result.append(record.duplicate(true))
	return result

func entry(id: String) -> Dictionary:
	for record in entries():
		if record.id == id: return record
	return {}

func capture(snapshot: Dictionary, catalog: RefCounted) -> bool:
	var changed := false
	var state: Dictionary = snapshot.get("state", {})
	var campaign: Dictionary = state.get("campaign", {})
	var runtime: Dictionary = campaign.get("runtime", {})
	for id in campaign.get("ledger", {}):
		var status: String = campaign.ledger[id].get("status", "")
		if status not in ["entered", "completed"]: continue
		var definition: Dictionary = catalog.entry("story_nodes", id)
		if definition.is_empty(): continue
		var count: int = definition.lines.size() if status == "completed" else (int(runtime.get("index", -1)) + 1 if runtime.get("id") == id else 0)
		count = clampi(count, 0, definition.lines.size())
		if count == 0: continue
		var record: Dictionary = records.get(id, {"id":id,"title":definition.name,"subtitle":"航程剧情","special":false,"art":definition.art,"lines":[],"results":[],"source_version":snapshot.get("content_version","")}).duplicate(true)
		# Preserve only a known prefix; a replay cannot reveal the remaining story.
		if count > record.lines.size(): record.lines = definition.lines.slice(0, count)
		if runtime.get("id") == id and state.get("story_step") == "result":
			var result: String = state.get("result_text", "")
			if not result.is_empty() and result not in record.results: record.results.append(result)
		if records.get(id, {}) != record:
			records[id] = record
			changed = true
	return changed

func load_archive() -> void:
	if not FileAccess.file_exists(path): return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK: _reject(); return
	var data = json.data
	if not data is Dictionary or data.get("schema") != 1 or not data.get("records") is Dictionary:
		_reject(); return
	for id in data.records:
		var record = data.records[id]
		if not record is Dictionary or record.get("id") != id or id == "opening": _reject(); return
		for field in ["title", "subtitle", "art"]:
			if not record.get(field) is String: _reject(); return
		for field in ["lines", "results"]:
			if not record.get(field) is Array: _reject(); return
			for line in record[field]:
				if not line is String: _reject(); return
		record.special = false
	records = data.records.duplicate(true)

func _reject() -> void:
	error = "剧情回廊记录无法读取，已保留原文件。"
	blocked = true

func save_archive() -> Error:
	if blocked: return ERR_INVALID_DATA
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: error = "剧情回廊记录保存失败。"; return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"schema":1,"records":records}))
	file.close()
	var result := DirAccess.rename_absolute(path + ".tmp", path)
	if result != OK: error = "剧情回廊记录保存失败。"
	return result
