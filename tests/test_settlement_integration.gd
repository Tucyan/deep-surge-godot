extends SceneTree
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+text)
func _init() -> void: call_deferred("run")
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	var old: Dictionary=app.session.snapshot()
	check(not app.session.dispatch("panel",{"id":"logs"}) and app.session.snapshot()==old,"移除原日志命令入口")
	app.handle_command("abandon")
	await process_frame; await process_frame
	check(app.current_page.get("page_index")==0,"终局自动进入日志页")
	if app.current_page.get("page_index")==null: app.queue_free(); quit(1); return
	var before: Dictionary=app.session.snapshot()
	app.current_page.show_analysis(); app.current_page.show_logs()
	check(app.session.snapshot()==before,"两页往返不改规则与随机")
	app.handle_ui("settlement_exit","")
	await process_frame
	check(app.session.screen=="home","结算返回首页")
	app.handle_ui("local_panel","recall")
	await process_frame
	check(app.layout.find_child("StoryGallery",true,false)!=null,"首页回溯定位为剧情回廊")
	app.handle_ui("local_panel","")
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":23})
	await process_frame
	var active: Dictionary=app.session.snapshot()
	app.handle_ui("local_panel","recall"); await process_frame
	check(app.layout.find_child("StoryGallery",true,false)!=null,"有旧结算的活动新局仍展示剧情回廊")
	app.handle_ui("local_panel","")
	check(app.session.snapshot()==active,"浏览剧情回廊保留活动局与随机流")
	app.queue_free(); await process_frame
	print("SETTLEMENT INTEGRATION: "+("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
