extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + message)
static func fixture() -> Dictionary:
	var logs: Array = []
	for i in range(70): logs.append("第 %02d 航次 · 穿过薄雾，收集漂浮物。木筏向潮线深处航行。" % (i + 1))
	return {"scope":"run","mode":"challenge","origin":"strong","seed":314,"outcome":"survived","completed":12,"length":12,"complete":true,"score":{"total":947,"grade":"S","components":{"voyage":500,"crisis":250,"survival":122,"exploration":75},"inputs":{"p":1.0,"h":0.8}},"points":{"granted":12,"pending":0,"bonus":0},"logs":logs,"stats":{"commands":{"craft":2},"minimum":{"hp":8,"san":14},"restored":{"hp":10},"lost":{"hp":12},"visits":[{"type":"battle","name":"沉船水道"}],"battles":{"b1":{"outcome":"victory"}},"crises":{"c1":{"success":true}},"crafts":["filter"],"initial_cells":[0,1,2,3],"detached":[2],"tags":["实际制造"],"counters":{"damage":12}},"cards":[{"id":"wood","name":"木头","kind":"resource","obtained":8,"used":0,"use_consumed":0,"cost_consumed":5,"deployed":0,"discarded":0,"lost":0,"cleared":0,"remaining":3,"sources":{"spring":8},"reasons":{"craft":5}}],"analysis":["完成12个日间节点。","木头投入制造5份。","沉船水道战斗获胜。"]}
func run() -> void:
	if not ResourceLoader.exists("res://pages/settlement_page.gd"):
		check(false,"settlement page must exist")
		quit(1); return
	var script = load("res://pages/settlement_page.gd")
	if script == null or not script.can_instantiate():
		check(false,"settlement page compiles"); quit(1); return
	var page = script.new()
	root.size = Vector2i(1600,900)
	root.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var report := fixture()
	var before := report.duplicate(true)
	page.setup({"settlement":report},RefCounted.new(),RefCounted.new())
	await process_frame; await process_frame
	page.set_process(false)
	check(page.page_index == 0 and not page.paused,"initial log playback")
	page.report.outcome_name="回声归航"
	check(page._outcome()=="回声归航","report localized outcome is authoritative")
	page.report.erase("outcome_name")
	if not page.has_method("_origin"):
		check(false,"origin localization must exist")
		page.queue_free(); await process_frame; quit(1); return
	check(page._origin()=="强壮之人","origin shown as Chinese name")
	check(page._label("resource")=="资源" and page._label("hp")=="生命","kind and stat labels localized")
	check(page._value({"count":15.0},"count")=="15" and page._display(15.0)=="15","JSON integer floats display without decimal suffix")
	check(page._value({"ratio":0.75},"ratio")=="0.75" and page._display(0.75)=="0.75","fractional values remain fractional")
	page._tab=0
	var readable: String = "\n".join(page._detail_lines())
	check(not readable.contains("inputs") and not readable.contains("granted") and readable.contains("推进"),"score detail readable without internal keys")
	page.report.stats.visits=[{"voyage":2,"id":"secret-node","visit_id":"private-candidate-id","name":"沉船水道","kind":"combat"}]
	page._tab=4; readable="\n".join(page._detail_lines())
	check(not readable.contains("private-candidate-id") and not readable.contains("secret-node") and readable.contains("第2航次"),"visits hide identifiers and retain voyage")
	page.report.stats.visits=before.stats.visits.duplicate(true)
	page.report.cards[0].remaining_permanent=3; page.report.cards[0].remaining_temporary=0
	page._tab=1; readable="\n".join(page._detail_lines())
	check(readable.contains("永久留存 3") and readable.contains("临时留存 0"),"card retained lifecycles separately displayed")
	page.report.stats.devices={"internal-device-key":{"id":"filter","cell":"cell-private-id","uses":2,"produced":4,"outputs":{"water":4}}}
	page.report.stats.attribute_sources={"hp":{"night":{"restored":8,"lost":0,"overflow":3}}}
	page._tab=3; readable="\n".join(page._detail_lines())
	check(readable.contains("实际生效 2") and readable.contains("溢出 3") and not readable.contains("cell-private-id"),"device and restoration facts without ids")
	page.report.campaign_summary={"route":"scholar","clues":["潮眼的流向"],"quests":[{"name":"修缮拖缆","status":"completed"}],"resolution":{"outcome":"A","plan":"seal","costs":{"wood":2},"losses":[],"relationship":"信任增加","people":"确认人员已撤离"}}
	page.report.prior_chapters=[{"outcome":"B","score":{"grade":"A","total":810}}]
	page._tab=4; readable="\n".join(page._detail_lines())
	check(readable.contains("潮眼的流向") and readable.contains("修缮拖缆") and readable.contains("810") and not readable.contains("scholar") and not readable.contains("seal"),"known campaign and prior chapter facts shown")
	for i in range(60): page._process(1.0/60.0)
	check(page.scroll_position >= 23,"fractional frames retain slow scroll progress")
	page._process(1.0)
	check(page.scroll_position > 0,"slow auto scroll advances")
	page.begin_hold(); page._process(0.34)
	check(not page.accelerating,"hold requires threshold")
	page._process(0.02)
	check(page.accelerating,"hold activates 6x speed")
	page.end_hold(); check(not page.accelerating,"release clears hold")
	for index in [0,1]:
		var touch := InputEventScreenTouch.new(); touch.position=Vector2(600,340); touch.index=index; touch.pressed=true
		page._input(touch)
	page._process(0.4); check(page.accelerating,"two touch holds can accelerate")
	var released := InputEventScreenTouch.new(); released.position=Vector2(600,340); released.index=0; released.pressed=false
	page._input(released); page._process(0.4)
	check(not page.accelerating,"any touch release safely clears overlapping holds")
	page.begin_hold()
	var overlap := InputEventKey.new(); overlap.keycode=KEY_SPACE; overlap.pressed=true; page._input(overlap)
	page._process(0.4); check(page.accelerating,"pointer plus space hold")
	overlap=InputEventKey.new(); overlap.keycode=KEY_SPACE; overlap.pressed=false; page._input(overlap); page._process(0.4)
	check(not page.accelerating,"space release safely clears overlapping pointer hold")
	page.begin_hold(); page._process(0.4)
	page._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not page.accelerating,"focus loss clears hold")
	page.show_analysis()
	check(page.page_index == 1 and not page.accelerating,"analysis clears input")
	var review_button: Button
	for item in page.find_children("*","Button",true,false):
		if item.text=="回看航海日志": review_button=item
	await process_frame; review_button.grab_focus()
	for pressed in [true,false]:
		var key := InputEventKey.new(); key.keycode=KEY_SPACE; key.pressed=pressed
		root.push_input(key,true); await process_frame
	check(page.page_index==0,"focused analysis button responds to space")
	page.show_analysis()
	check(page.find_children("*","ScrollContainer",true,false).filter(func(n): return n.is_visible_in_tree()).is_empty(),"analysis contains no visible scroll")
	page.page_index=0; page._review=false; page.paused=false; page._draw_page()
	await process_frame; await process_frame
	page.scroll_position=page.max_scroll(); page._process(1.0)
	check(page.page_index==0,"initial playback waits two seconds at end")
	page._process(1.1); check(page.page_index==1,"initial playback automatically opens analysis")
	page.show_logs(); await process_frame
	check(page.page_index == 0 and page.paused and page.scroll_position == 0,"review paused at beginning")
	page._process(50.0); check(page.page_index == 0,"review never auto advances")
	page.toggle_pause(); page.scroll_position = page.max_scroll(); page._process(3.0)
	check(page.page_index == 0,"continued review remains manual")
	check(report == before,"view navigation never mutates report")
	report.logs[0] = "changed externally"
	check(page.report.logs[0] != report.logs[0],"report deep copy")
	page.queue_free(); await process_frame
	var legacy = script.new(); root.add_child(legacy)
	legacy.setup({"settlement":{"logs":["原航海日志"],"complete":false,"stats":{"coverage_start":6.0}}},RefCounted.new(),RefCounted.new())
	legacy.show_analysis()
	check(legacy.incomplete,"legacy unknowns marked incomplete")
	var coverage_shown := false
	for label in legacy.find_children("*","Label",true,false):
		if label.text.contains("第6航次起") and label.text.contains("最低值"): coverage_shown=true
	check(coverage_shown,"legacy stats explicitly scoped to coverage start")
	legacy.queue_free(); await process_frame
	print("SETTLEMENT PAGE: " + ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
