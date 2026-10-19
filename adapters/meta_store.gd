extends RefCounted
## Cross-run meta progress: tutorial completion, difficulty unlocks and the last
## difficulty the player picked. Deliberately separate from the single-run save so a
## run rollback or an old save cannot rewrite unlock progress.
const VERSION := 1
const CHALLENGE_IDS := ["standard","hard","nightmare"]
const ALL_IDS := ["tutorial","standard","hard","nightmare"]
var path := "user://deep-surge-meta.json"
var error := ""
var data := {}

func _init() -> void:
	reset()

func reset() -> void:
	error = ""
	data = {"version":VERSION,"tutorial_done":false,"tutorial_prompt_handled":false,"cleared":{},"last_difficulty":""}

func exists() -> bool:
	return FileAccess.file_exists(path)

func read_meta() -> void:
	reset()
	if not FileAccess.file_exists(path): return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		error = "进度文件损坏；已保留原文件，教程与难度解锁暂按未解锁处理。"
		return
	var raw: Dictionary = json.data
	if raw.get("version") != VERSION: return
	data.tutorial_done = raw.get("tutorial_done",false) == true
	data.tutorial_prompt_handled = raw.get("tutorial_prompt_handled",false) == true
	var cleared := {}
	if raw.get("cleared") is Dictionary:
		for id in CHALLENGE_IDS:
			if raw.cleared.get(id,false) == true: cleared[id] = true
	data.cleared = cleared
	var last: Variant = raw.get("last_difficulty","")
	data.last_difficulty = last if last is String and last in ALL_IDS else ""

func write_meta() -> bool:
	error = ""
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		error = "无法写入进度文件"
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path)) != OK:
		error = "无法替换进度文件"
		return false
	return true

func tutorial_done() -> bool:
	return data.get("tutorial_done",false) == true

func cleared(id: String) -> bool:
	return data.get("cleared",{}).get(id,false) == true

## Initial unlocks are the tutorial and standard. Hard needs a standard clear,
## nightmare needs a hard clear. The tutorial itself never gates another tier.
func unlocked(id: String) -> bool:
	if id in ["tutorial","standard"]: return true
	if id == "hard": return cleared("standard")
	if id == "nightmare": return cleared("hard")
	return false

func unlock_requirement(id: String) -> String:
	if id == "hard": return "通关简单难度后解锁"
	if id == "nightmare": return "通关困难难度后解锁"
	return ""

func last_difficulty() -> String:
	var last: String = str(data.get("last_difficulty",""))
	if last != "" and unlocked(last): return last
	if not tutorial_done() and not data.get("tutorial_prompt_handled",false) and unlocked("tutorial"): return "tutorial"
	return "standard"

## Returns the tiers that this clear newly opened, so the UI can name them once.
func record_clear(difficulty: String) -> Array:
	var opened: Array = []
	if difficulty == "tutorial":
		if not tutorial_done(): data.tutorial_done = true
		return opened
	if difficulty not in CHALLENGE_IDS: return opened
	var before_hard: bool = unlocked("hard")
	var before_nightmare: bool = unlocked("nightmare")
	if not cleared(difficulty):
		data.cleared[difficulty] = true
	if not before_hard and unlocked("hard"): opened.append("hard")
	if not before_nightmare and unlocked("nightmare"): opened.append("nightmare")
	return opened

func set_last_difficulty(id: String) -> void:
	if id in ALL_IDS: data.last_difficulty = id

func snapshot() -> Dictionary:
	var unlocked_ids: Array = []
	for id in ALL_IDS:
		if unlocked(id): unlocked_ids.append(id)
	return {"tutorial_done":tutorial_done(),"tutorial_prompt_handled":data.get("tutorial_prompt_handled",false),"cleared":data.get("cleared",{}).duplicate(true),"last_difficulty":last_difficulty(),"unlocked":unlocked_ids,"error":error}
