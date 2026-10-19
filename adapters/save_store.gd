extends RefCounted
var path := "user://godot-flow-v02.json"
var error := ""
func read() -> Dictionary:
	error = ""
	if not FileAccess.file_exists(path): return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		error = "存档文件损坏，已保留原文件；可以明确开始新局。"
		return {}
	return json.data
func write(data: Dictionary) -> bool:
	error = ""
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: error = "无法写入存档"; return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: error = "无法写入存档"; return false
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
	if result != OK: error = "无法替换存档文件"; return false
	return true
