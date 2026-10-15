extends SceneTree
var app
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void: call_deferred("run")
func button(text: String) -> Button:
	for item in app.current_page.find_children("*","Button",true,false):
		if item.text==text: return item
	return null
func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
	root.push_input(event,true); await process_frame
func click(text: String) -> void:
	var control := button(text); check(control!=null,"可见按钮 "+text)
	if control==null: return
	var point: Vector2=control.get_global_rect().get_center()
	await mouse(point,true); await mouse(point,false); await process_frame
func shot(id: String) -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://evidence/settlement-actual-"+id+".png")==OK,"保存截图")
func load_run(path: String) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: check(false,"实际航程夹具不存在 "+path); return false
	check(app.session.restore(data),"实际航程保存恢复")
	app.handle_command("resume")
	await process_frame; await process_frame
	check(app.current_page.get("page_index")==0,"实际终局自动进入日志")
	return true
func run() -> void:
	root.size=Vector2i(1600,900)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	if not await load_run("res://evidence/settlement-route-22.json"): quit(1); return
	var before: Dictionary=app.session.snapshot()
	await shot("success-logs-1600")
	var pos: float=app.current_page.scroll_position
	await create_timer(0.5).timeout
	check(app.current_page.scroll_position>pos,"主程序自动滚动")
	var key:=InputEventKey.new(); key.keycode=KEY_SPACE; key.pressed=true; root.push_input(key,true)
	await create_timer(0.4).timeout
	check(app.current_page.accelerating,"主程序空格长按加速")
	key=InputEventKey.new(); key.keycode=KEY_SPACE; key.pressed=false; root.push_input(key,true); await process_frame
	check(not app.current_page.accelerating,"主程序松开恢复")
	await click("跳过，查看结算"); await shot("success-analysis-1600")
	await click("卡牌收支"); await shot("success-cards-1600")
	await click("战斗与危机"); await shot("success-battle-1600")
	await click("生存与木筏"); await shot("success-survival-1600")
	await click("回看航海日志")
	check(app.current_page.page_index==0 and app.current_page.paused,"主程序第二页返回第一页")
	check(app.session.snapshot()==before,"主程序播放和所有标签不改变规则")
	for resolution in [Vector2i(1600,900),Vector2i(1280,720)]:
		root.size=resolution; await process_frame; await process_frame
		await click("跳过，查看结算"); await shot("success-analysis-%d" % resolution.x)
		for item in app.current_page.find_children("*","Button",true,false):
			check(app.current_page.get_global_rect().grow(2).encloses(item.get_global_rect()),"按钮在窗口内 "+item.text)
		await click("回看航海日志")
	await click("跳过，查看结算"); await click("X")
	check(app.session.screen=="home","实际返回首页")
	app.handle_ui("local_panel","recall"); await process_frame
	check(app.current_page.get("page_index")==0,"首页回看实际报告")
	app.handle_ui("settlement_exit","")
	if await load_run("res://evidence/settlement-route-0.json"):
		await click("跳过，查看结算"); await shot("failure-analysis-1280")
	if await load_run("res://evidence/settlement-chapter-A.json"):
		check(app.session.profile.points==0 and app.session.state.settlement.points.pending==15,"章节只展示不发点")
		await click("跳过，查看结算"); await click("航行与剧情"); await shot("chapter-A-analysis-1280")
	app.queue_free(); await process_frame
	print("SETTLEMENT ACTUAL GPU: "+("PASS" if failures==0 else "FAIL")+" failures="+str(failures)); quit(0 if failures==0 else 1)
