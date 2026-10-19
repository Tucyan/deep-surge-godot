extends RefCounted
## Multi-slot storage for narrative saves, independent from the gameplay save.
## File layout: user://narrative/<id>.json and user://narrative/active.json
const DIR := "user://narrative"
const ACTIVE_PATH := "user://narrative/active.json"
const ID_PREFIX := "nar-"

var error := ""
var dir := DIR
var active_path := ACTIVE_PATH
var _active := ""
var _saves: Array = []
var _saves_valid := false
var _has_saves := false

func _init(base_dir: String = "") -> void:
	if base_dir != "":
		dir = base_dir
		active_path = base_dir + "/active.json"
	_ensure_dir()
	_active = _read_active()
	_refresh_presence()

func active_id() -> String:
	return _active

## Attaches a save to the current session. Empty string detaches.
func set_active(id: String) -> bool:
	error = ""
	if id != "" and read(id).is_empty():
		error = "剧情存档不存在"
		return false
	if not _write_json(active_path, {"id": id}):
		return false
	_active = id
	_saves_valid = false
	return true

func create_id() -> String:
	return ID_PREFIX + Crypto.new().generate_random_bytes(5).hex_encode()

func has_saves() -> bool:
	return _has_saves

func _refresh_presence() -> void:
	_has_saves = false
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".json") and file != "active.json" and _valid_id(file.trim_suffix(".json")):
			_has_saves = true
			return

## Refresh explicitly on menu entry to notice external file changes. Normal HUD
## reads only has_saves(); metadata is parsed once between committed mutations.
func list_saves(refresh: bool = false) -> Array:
	if _saves_valid and not refresh: return _saves.duplicate(true)
	var result: Array = []
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".json") or file == "active.json" or file.ends_with(".tmp"): continue
		var id := file.trim_suffix(".json")
		if not _valid_id(id): continue
		var data = _read_json(path_of(id))
		if not data is Dictionary or data.get("schema") != 1 or not data.get("state") is Dictionary:
			result.append({"id":id, "label":id + "（损坏，原文件已保留）", "updated_at":0, "beats":0, "affinity":{}, "active":false, "paired":false})
			continue
		var state: Dictionary = data.get("state", {})
		var affinity: Dictionary = state.get("affinity", {}) if state.get("affinity", {}) is Dictionary else {}
		var game: Dictionary = data.get("gameplay", {}) if data.get("gameplay", {}) is Dictionary else {}
		var game_state: Dictionary = game.get("state", {}) if game.get("state", {}) is Dictionary else {}
		var beats: Array = state.get("applied_beats", []) if state.get("applied_beats", []) is Array else []
		result.append({
			"id": id,
			"label": str(data.get("label", id)),
			"updated_at": int(data.updated_at) if data.get("updated_at") is float or data.get("updated_at") is int else 0,
			"beats": beats.size(),
			"affinity": affinity.duplicate(true),
			"active": id == _active,
			"paired": data.get("chapter", "") == "chapter1" and data.get("version", "") == "chapter1-local-v1" and game_state.get("mode", "") == "story"
		})
	result.sort_custom(func(a, b): return int(a.updated_at) > int(b.updated_at))
	_saves = result
	_saves_valid = true
	_has_saves = not result.is_empty()
	return result.duplicate(true)

func read(id: String) -> Dictionary:
	if not _valid_id(id): return {}
	var data = _read_json(path_of(id))
	return data.duplicate(true) if data is Dictionary else {}

func write(id: String, data: Dictionary) -> bool:
	error = ""
	if not _valid_id(id):
		error = "剧情存档 ID 非法"
		return false
	if not _ensure_dir(): return false
	var previous := read(id)
	var existed := FileAccess.file_exists(path_of(id))
	if not _write_json(path_of(id), data): return false
	if id != _active and not _write_json(active_path, {"id": id}):
		var cause := error
		# Slot data and the binding are one operation. Restore the former when
		# the pointer cannot be committed; never attach memory to a failed write.
		if existed:
			if not _write_json(path_of(id), previous):
				error = cause + "；旧剧情档恢复失败：" + error
				return false
		else:
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(path_of(id))) != OK:
				error = cause + "；未挂载的新剧情档清理失败"
				return false
		error = cause
		return false
	_active = id
	_saves_valid = false
	_has_saves = true
	return true

func path_of(id: String) -> String:
	return dir + "/" + id + ".json"

func _valid_id(id: String) -> bool:
	return id.begins_with(ID_PREFIX) and id.is_valid_filename() and not id.contains("..") and not id.contains("/") and not id.contains("\\")

func _ensure_dir() -> bool:
	var absolute := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(absolute): return true
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		error = "无法创建剧情存档目录"
		return false
	return true

func _read_active() -> String:
	var data = _read_json(active_path)
	if not data is Dictionary: return ""
	var id := str(data.get("id", ""))
	return id if _valid_id(id) else ""

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return json.data

## Writes through a temporary file so a failed write never replaces a good save.
func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "剧情存档写入失败：" + path
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		error = "剧情存档写入失败：" + path
		return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		error = "剧情存档替换失败：" + path
		return false
	return true
