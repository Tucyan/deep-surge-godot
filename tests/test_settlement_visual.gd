extends SceneTree
const Fixture = preload("res://tests/test_settlement_page.gd")
var page
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func mouse(position: Vector2, pressed: bool) -> void:
	var move := InputEventMouseMotion.new(); move.position=position; root.push_input(move,true)
	var event := InputEventMouseButton.new(); event.position=position; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; root.push_input(event,true)
	await process_frame
func space(pressed: bool) -> void:
	var event := InputEventKey.new(); event.keycode=KEY_SPACE; event.pressed=pressed; root.push_input(event,true)
	await process_frame
func button(text: String) -> Button:
	for item in page.find_children("*","Button",true,false):
		if item.text==text: return item
	return null
func click(item: Control) -> void:
	var point := item.get_global_rect().get_center()
	await mouse(point,true); await mouse(point,false)
func capture(id: String) -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/settlement-page-"+id+".png")
func run() -> void:
	root.size=Vector2i(1600,900)
	page=load("res://pages/settlement_page.gd").new(); root.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var report := Fixture.fixture()
	report.score.inputs={"completed":12,"length":12,"goal":true,"hp":0.8,"sanity":0.7,"cells":1.0,"events_entered":2,"events_won":2,"battles_entered":1,"battles_won":1,"tags":3}
	report.cards[0].remaining_permanent=3; report.cards[0].remaining_temporary=0
	report.stats.devices={"filter/cell":{"id":"filter","cell":1,"uses":2,"produced":4,"outputs":{"water":4}}}
	report.stats.attribute_sources={"hp":{"night":{"restored":8,"lost":0,"overflow":3}}}
	report.campaign_summary={"route":"scholar","clues":["潮眼的流向"],"quests":[{"name":"修缮拖缆","status":"completed"}],"resolution":{"outcome":"A","plan":"seal","costs":{"wood":2},"losses":[],"relationship":"信任增加","people":"确认人员已撤离"}}
	var before := report.duplicate(true)
	var catalog = load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"visual fixture catalog loads")
	page.setup({"settlement":report},catalog,RefCounted.new())
	await process_frame; await process_frame
	var start: float = page.scroll_position
	await create_timer(0.6).timeout
	check(page.scroll_position>start,"actual automatic slow scroll")
	await mouse(Vector2(600,340),true)
	await create_timer(0.4).timeout
	check(page.accelerating,"actual mouse hold accelerates")
	await capture("logs-1600")
	await mouse(Vector2(600,340),false)
	check(not page.accelerating,"actual mouse release")
	button("暂停").grab_focus()
	await space(true); await create_timer(0.4).timeout
	check(page.accelerating and not page.paused,"space hold does not activate focused pause button")
	await space(false)
	check(not page.accelerating and not page.paused,"space release does not activate focused button")
	await mouse(button("暂停").get_global_rect().get_center(),true)
	await create_timer(0.4).timeout
	check(not page.accelerating,"button hold never accelerates")
	await mouse(button("暂停").get_global_rect().get_center(),false)
	check(page.paused,"actual pause button")
	var touch := InputEventScreenTouch.new(); touch.index=0; touch.position=Vector2(600,340); touch.pressed=true
	root.push_input(touch,true); await create_timer(0.4).timeout
	check(page.accelerating,"actual touch hold")
	touch=InputEventScreenTouch.new(); touch.index=0; touch.position=Vector2(600,340); touch.pressed=false
	root.push_input(touch,true); await process_frame
	check(not page.accelerating,"touch release clears")
	await click(button("跳过，查看结算")); check(page.page_index==1,"actual skip")
	await capture("analysis-1600")
	button("回看航海日志").grab_focus()
	await space(true); await space(false)
	check(page.page_index==0 and page.paused,"focused analysis button responds to space")
	await click(button("跳过，查看结算"))
	await click(button("下一页")); await capture("crisis-score-1600")
	await click(button("卡牌收支")); await capture("cards-1600")
	await click(button("生存与木筏")); await click(button("下一页")); await capture("survival-1600")
	await click(button("航行与剧情")); await capture("campaign-1600")
	await click(button("回看航海日志"))
	check(page.paused and page.scroll_position==0,"actual return starts paused at beginning")
	root.size=Vector2i(1280,720); await process_frame; await process_frame
	await capture("logs-1280")
	await click(button("跳过，查看结算")); await capture("analysis-1280")
	for item in page.find_children("*","Button",true,false):
		if item.is_visible_in_tree():
			var transform: Transform2D = root.get_final_transform() * item.get_global_transform()
			var bounds := Rect2(transform * Vector2.ZERO,item.size * transform.get_scale())
			check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(bounds),"buttons inside 1280 viewport: "+item.text)
	check(report==before,"all actual input leaves report unchanged")
	page.queue_free(); await process_frame
	print("SETTLEMENT GPU: "+("PASS" if failures==0 else "FAIL")+", failures="+str(failures))
	quit(0 if failures==0 else 1)
