extends SceneTree
var app: Control
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+text)
func find(node: Node, type: String) -> Array:
	var result: Array = []
	if node.is_class(type): result.append(node)
	for child in node.get_children(): result.append_array(find(child,type))
	return result
func buttons(node: Node, text: String) -> Array:
	return find(node,"Button").filter(func(b): return b.text == text)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,900)
	app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false; root.add_child(app)
	await process_frame
	app.handle_ui("setup","challenge")
	await process_frame
	check(buttons(app,"图鉴").is_empty() and buttons(app,"退出游戏").is_empty() and buttons(app,"挑战模式").is_empty(),"新局准备必须替换首页")
	check(find(app,"ScrollContainer").is_empty(),"新局准备不能出现滚动容器")
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	await process_frame
	check(find(app,"SubViewport").size() == 1 and find(app,"Node3D").size() > 0,"航行必须是真实3D场景")
	check(find(app,"ScrollContainer").is_empty(),"游戏主界面无滚动容器")
	check(app.world_view.cells.get_child_count() == 4,"场景按四个逻辑筏格映射")
	check(app.world_view.raft.get_node_or_null("CampDecoration") == null,"空木筏无固定帆/箱/盆栽装饰")
	var before: Dictionary = app.session.snapshot()
	app.handle_ui("hand_page","1")
	await process_frame
	check(app.session.snapshot() == before,"手牌翻页不能修改规则或随机")
	for resolution in [Vector2i(1600,900),Vector2i(1280,720)]:
		root.size = resolution
		await process_frame
		await process_frame
		check_bounds()
	var fixture: Dictionary = app.session.snapshot()
	for i in range(8): app.session.I.give(fixture.state,"wood",1,false,"ui-test-fixture")
	fixture.state.phase = "discard"
	check(app.session.restore(fixture),"超限界面测试夹具")
	app.handle_command("resume")
	await process_frame
	await process_frame
	check_bounds()
	check(find(app,"ScrollContainer").is_empty(),"超限手牌分组不滚动")
	# Return to the original real navigation state for other panel checks.
	check(app.session.restore(before),"恢复真实航行状态")
	app.handle_command("resume")
	app.handle_command("panel",{"id":"raft"})
	await process_frame
	check(find(app,"ScrollContainer").is_empty(),"木筏详情无滚动容器")
	check_bounds()
	app.handle_command("close")
	var node: Dictionary = app.session.state.candidates[0]
	app.handle_command("voyage",{"id":node.visit_id})
	check(buttons(app,"航行日志").is_empty(),"航海日志迁入结算页")
	for id in ["craft","raft"]:
		app.handle_command("panel",{"id":id})
		await process_frame
		await process_frame
		check_bounds()
		check(find(app,"ScrollContainer").is_empty(),id+"面板无滚动容器")
		app.handle_command("close")
	app.handle_command("home")
	for id in ["encyclopedia","meta_shop"]:
		app.handle_command("panel",{"id":id})
		await process_frame
		await process_frame
		check_bounds()
		check(find(app,"ScrollContainer").is_empty(),id+"面板无滚动容器")
		var snapshot: Dictionary = app.session.snapshot()
		app.handle_ui("list_page","1")
		check(app.session.snapshot() == snapshot,"目录翻页不重抽或修改状态")
		app.handle_command("close")
	app.queue_free(); await process_frame
	print("CLEAN HUD: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func check_bounds() -> void:
	var bounds: Rect2 = app.get_global_rect().grow(2)
	for button in find(app,"Button"):
		if not button.is_visible_in_tree(): continue
		var rect: Rect2 = button.get_global_rect()
		check(bounds.encloses(rect),"按钮不能超出视口："+button.text)
