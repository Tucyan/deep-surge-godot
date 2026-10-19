extends RefCounted
var path := "user://godot-flow-v02.json"
var error := ""
## Explicit replacement of rejected data retains its original bytes for inspection.
func preserve_rejected() -> bool:
	if not FileAccess.file_exists(path): return true
	var source := FileAccess.open(path,FileAccess.READ)
	if source == null: error = "无法读取待保留的原存档"; return false
	var bytes := source.get_buffer(source.get_length())
	var read_error := source.get_error()
	source.close()
	if read_error != OK: error = "无法读取待保留的原存档"; return false
	var target := FileAccess.open(path+".rejected-"+str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec())+".json",FileAccess.WRITE)
	if target == null: error = "无法保留原存档，已取消替换"; return false
	target.store_buffer(bytes); target.flush()
	var write_error := target.get_error()
	target.close()
	if write_error != OK: error = "无法保留原存档，已取消替换"; return false
	return true
func read() -> Dictionary:
	error = ""
	if not FileAccess.file_exists(path): return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary or json.data.is_empty():
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
