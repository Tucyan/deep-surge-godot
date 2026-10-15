extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _init() -> void:
	if not ResourceLoader.exists("res://core/game_session.gd"):
		check(false, "缺少独立游戏状态机")
		quit(1)
		return
	var catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(), "装载内容")
	var s = load("res://core/game_session.gd").new(catalog)
	check(s.dispatch("new", {"mode":"challenge", "origin":"strong", "seed":17}), "挑战新局")
	check(s.view().phase == "navigation", "首次导航")
	check(s.view().hand.size() == 7 and s.view().ap == s.view().player.base_ap, "随心所欲七张资源/首次无涌泉，导航可用AP")
	check(s.view().player.hp == 40, "出身上限实际生效")
	check(s.dispatch("panel", {"id":"craft"}), "导航允许合成")
	s.dispatch("close")
	var before: Dictionary = s.snapshot()
	check(not s.dispatch("voyage", {"id":"invalid"}), "拒绝非候选")
	check(s.snapshot() == before, "拒绝不消耗随机或资源")
	var candidate: Dictionary = s.view().candidates[0]
	check(s.dispatch("voyage", {"id":candidate.visit_id}), "提交候选")
	check(s.view().phase == "preparation" and s.view().ap == 3, "抵达后准备")
	check(s.dispatch("panel", {"id":"craft"}), "准备允许合成面板")
	check(s.dispatch("close"), "关闭合成")
	check(s.view().phase == "preparation", "关闭不推进阶段")
	check(not s.dispatch("panel", {"id":"shop"}), "不能直接开商店")
	check(s.dispatch("enter"), "进入节点")
	check(s.view().phase == "story", "节点先进入剧情")
	check(s.dispatch("close"), "暂时隐藏剧情")
	check(s.view().phase == "story", "隐藏不完成事件")
	check(not s.dispatch("voyage", {"id":candidate.visit_id}), "未完成事件不能换节点")
	check(not s.dispatch("end_voyage"), "未完成不能结算")
	check(s.dispatch("event"), "恢复当前剧情")
	var saved: Dictionary = s.snapshot()
	var restored = load("res://core/game_session.gd").new(catalog)
	check(restored.restore(saved), "恢复完整状态")
	check(restored.snapshot() == saved, "恢复随机与剧情游标")
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.content_version = "old"
	check(not restored.restore(corrupt), "拒绝不同内容版本")
	print("FLOW SESSION: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
