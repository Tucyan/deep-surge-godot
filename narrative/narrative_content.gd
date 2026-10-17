extends RefCounted
## Loads narrative definitions and characters at the composition boundary.
## Pure data: no scene tree, no GameSession, no gameplay mutation.
const StoryPlayer = preload("res://story/story_player.gd")

const CHARACTERS_PATH := "res://narrative/content/characters.json"
const CHAPTER_FILES := ["res://narrative/content/chapter_l1.json"]

var error := ""
var characters: Dictionary = {}
var scenes: Dictionary = {}
var beats: Array = []
var chapter := ""
var version := ""
var length := 0

func load_content() -> bool:
	error = ""
	characters.clear(); scenes.clear(); beats.clear()
	if not _load_characters(): return false
	for path in CHAPTER_FILES:
		if not _load_chapter(path): return false
	beats.sort_custom(func(a, b): return int(a.after_voyage) < int(b.after_voyage))
	for beat in beats:
		if not scenes.has(str(beat.get("scene", ""))):
			return _fail("节拍场景不存在：" + str(beat.get("id", "")))
	return true

func character(id: String) -> Dictionary:
	return characters.get(id, {})

func beat(id: String) -> Dictionary:
	for entry in beats:
		if str(entry.get("id", "")) == id: return entry
	return {}

func applied_count(applied: Array) -> int:
	var count := 0
	for entry in beats:
		if applied.has(str(entry.id)): count += 1
	return count

## Highest affection level whose threshold is reached; used only for display.
func affinity_level(id: String, value: int) -> String:
	var definition: Dictionary = character(id)
	var label := ""
	for level in definition.get("levels", []):
		if value >= int(level.get("min", 0)): label = str(level.get("label", ""))
	return label

func _load_characters() -> bool:
	var data = _read_json(CHARACTERS_PATH)
	if not data is Dictionary or int(data.get("schema", 0)) != 1:
		return _fail("角色表格式错误")
	var list: Variant = data.get("characters")
	if not list is Array or list.is_empty(): return _fail("角色表为空")
	for entry in list:
		if not entry is Dictionary: return _fail("角色定义不是对象")
		var id := str(entry.get("id", ""))
		if id == "" or characters.has(id): return _fail("角色 ID 重复或为空")
		if not entry.get("name") is String or str(entry.name).is_empty(): return _fail("角色缺少名称：" + id)
		if not entry.get("levels") is Array or entry.levels.is_empty(): return _fail("角色缺少好感档位：" + id)
		characters[id] = entry.duplicate(true)
	return true

func _load_chapter(path: String) -> bool:
	var data = _read_json(path)
	if not data is Dictionary or int(data.get("schema", 0)) != 1:
		return _fail("章节格式错误：" + path)
	var id := str(data.get("id", ""))
	if id.is_empty(): return _fail("章节缺少 ID")
	# One chapter per run in this version; a second chapter file is an authoring error.
	if chapter != "" and chapter != id: return _fail("一次只能加载一个章节")
	chapter = id
	version = str(data.get("version", ""))
	if version.is_empty(): return _fail("章节缺少内容版本")
	length = int(data.get("length", 0))
	if length <= 0: return _fail("章节长度必须为正整数")
	var beat_list: Variant = data.get("beats")
	if not beat_list is Array or beat_list.is_empty(): return _fail("章节缺少节拍")
	var seen := {}
	for entry in beat_list:
		if not entry is Dictionary: return _fail("节拍不是对象")
		var beat_id := str(entry.get("id", ""))
		if beat_id == "" or seen.has(beat_id): return _fail("节拍 ID 重复或为空")
		if not _is_int(entry.get("after_voyage")): return _fail("节拍 after_voyage 必须是整数：" + beat_id)
		var after := int(entry.after_voyage)
		if after < 1 or after > length: return _fail("节拍超出章节长度：" + beat_id)
		if not entry.get("scene") is String or str(entry.scene).is_empty(): return _fail("节拍缺少场景：" + beat_id)
		if entry.has("at") and entry.at not in ["chapterComplete"]: return _fail("未知节拍时机：" + beat_id)
		if entry.has("priority") and not _is_int(entry.priority): return _fail("节拍优先级必须是整数：" + beat_id)
		if not _valid_requirements(entry): return _fail("节拍好感条件非法：" + beat_id)
		seen[beat_id] = true
		beats.append(entry.duplicate(true))
	var files: Variant = data.get("scene_files")
	if not files is Array: return _fail("章节缺少场景清单")
	for scene_path in files:
		if not scene_path is String or not scene_path.begins_with("res://narrative/content/"):
			return _fail("场景路径非法")
		var scene = _read_json(scene_path)
		if scene == null: return _fail("场景无法读取：" + scene_path)
		var response: Dictionary = StoryPlayer.new().load_story(scene)
		if not response.get("ok", false):
			return _fail("场景结构非法：" + scene_path + " · " + str(response.get("error", "")))
		if not _validate_choice_effects(scene):
			return _fail("场景选项效果非法：" + scene_path)
		var scene_id := str(scene.id)
		if scenes.has(scene_id): return _fail("场景 ID 重复：" + scene_id)
		scenes[scene_id] = scene.duplicate(true)
	return true

func _validate_choice_effects(scene: Dictionary) -> bool:
	for node in scene.get("nodes", []):
		if node.get("choices", []).is_empty(): continue
		# A filtered scene must never dead-end: keep one option always available.
		var unconditional := false
		for choice in node.choices:
			for char_id in choice.get("affinity", {}):
				if not characters.has(char_id): return false
				if not _is_int(choice.affinity[char_id]): return false
			if not _valid_requirements(choice): return false
			if choice.get("requires_affinity", {}).is_empty(): unconditional = true
			if choice.has("set_flags") and not choice.set_flags is Array: return false
		if not unconditional: return false
	return true

func _valid_requirements(entry: Dictionary) -> bool:
	if not entry.has("requires_affinity"): return true
	if not entry.requires_affinity is Dictionary: return false
	for char_id in entry.requires_affinity:
		if not characters.has(str(char_id)): return false
		if not _is_int(entry.requires_affinity[char_id]): return false
	return true

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return json.data

func _is_int(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

func _fail(message: String) -> bool:
	error = message
	return false
