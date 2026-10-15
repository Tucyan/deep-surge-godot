extends SceneTree
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+text)
func same(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not same(a[i],b[i]): return false
		return true
	return a == b
func _init() -> void:
	var catalog = load("res://content/catalog.gd").new()
	catalog.load_catalog()
	var s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	var saved: Dictionary = s.snapshot()
	var loaded = load("res://core/game_session.gd").new(catalog)
	check(loaded.restore(JSON.parse_string(JSON.stringify(saved))),"JSON完整往返")
	check(same(loaded.snapshot(),saved),"随机/资源/阶段一致")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.state.player.hp=40; legacy.state.player.hp_max=40; legacy.state.stats.minimum.hp=40
	legacy.content_version = "godot-flow-v02-2"; legacy.fingerprint = catalog.legacy_fingerprint()
	check(not loaded.restore(JSON.parse_string(JSON.stringify(legacy))),"Demo开发期拒绝旧版挑战存档")
	check(loaded.snapshot().content_version == s.VERSION,"写回新格式，状态与随机不重建")
	var bad: Dictionary = saved.duplicate(true)
	bad.profile.points = -100
	check(not loaded.restore(bad),"拒绝负积分坏档")
	check(same(loaded.snapshot(),saved),"坏档不覆盖当前会话")
	bad = saved.duplicate(true); bad.state.length = "oops"
	check(not loaded.restore(bad),"拒绝字段类型错误")
	bad = saved.duplicate(true); bad.state.candidates[0].description = "tampered"
	check(not loaded.restore(bad),"拒绝候选定义篡改")
	var id: String = saved.state.candidates[0].visit_id
	check(s.dispatch("voyage",{"id":id}) and loaded.dispatch("voyage",{"id":id}),"原会话/文件恢复后同命令")
	check(same(s.snapshot(),loaded.snapshot()),"同保存点后结果与随机一致")
	var store = load("res://adapters/save_store.gd").new()
	if store.get("path") == null:
		check(false,"存档适配器需支持隔离测试路径")
		quit(1)
		return
	store.path = "user://flow-save-test-only.json"
	check(store.write(saved),"原子写入")
	check(store.write(saved),"可替换已有文件")
	check(loaded.restore(store.read()),"文件恢复")
	var file := FileAccess.open(store.path,FileAccess.WRITE)
	file.store_string("{bad-json"); file.close()
	check(store.read().is_empty() and not store.error.is_empty(),"坏JSON不装载")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
	print("SAVE / RECOVERY: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
