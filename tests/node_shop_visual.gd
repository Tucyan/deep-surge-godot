extends SceneTree
## Isolated visual fixtures; does not read or write the player's save.
var app
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func capture(name: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/economy-v11-"+name+".png")
func find_text(node: Node, text: String) -> Button:
	if node is Button and node.text==text: return node
	for child in node.get_children():
		var found=find_text(child,text)
		if found!=null: return found
	return null
func click(button: Button) -> void:
	check(button!=null,"存在可点击按钮")
	if button==null: return
	var point: Vector2=root.get_final_transform()*button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point; event.global_position=point
		Input.parse_input_event(event); await process_frame
	await settle()
func event_fixture(id: String, variant: String = "") -> void:
	var s=app.session
	s.state.node=app.catalog.entry("nodes",id)
	if variant!="":
		for v in s.state.node.variants:
			if v.id==variant: s.state.node.merge(v,true); s.state.node.id=id; s.state.node.variant_id=variant; break
	s.state.node.erase("variants"); s.state.node.visit_id="visual-fixture-"+id
	s.state.phase="story"; s.state.story_step="choice"; s.state.voyage=7
	s.state.candidates=[]; s.Encounter.arrived(s)
	s.screen="game"; s.panel="story"; app.render()
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.world_view.motion=false
	event_fixture("trader"); app.session.give("coin",12); app.session.give("wood",4); app.session.give("corpse",2); app.session.give("medkit")
	app.handle_command("shop_enter"); await settle()
	check(app.current_page.get_script()==load("res://pages/shop_page.gd"),"正式商店页接入")
	await capture("shop-1280")
	var before=app.session.snapshot()
	await click(find_text(app.current_page,"1 贝币 / 1 尸体"))
	check(app.current_page.confirmation.visible,"真实商品点击打开确认框")
	check(app.current_page.confirmation.size.y<root.size.y,"确认框不超出屏幕高度")
	check(app.current_page.confirmation.get_ok_button().get_global_rect().end.y<app.current_page.confirmation.size.y,"确认按钮在对话框内可见")
	check(app.session.snapshot()==before,"打开确认不扣币不随机")
	await capture("buy-confirm")
	app.current_page.cancel_selection()
	await click(find_text(app.current_page,"出售手牌 · 尸体2贝币"))
	check(app.current_page.selling,"真实点击切换出售")
	await capture("sell-1280")
	var sale: Dictionary=app.current_page.context.shop.sellable.filter(func(item):return item.id=="corpse")[0]
	var sale_coins: int=app.session.state.coins
	app.current_page.select_sell(sale)
	check(app.current_page.details.text.contains("获得2贝币"),"尸体确认框显示真实二币报价")
	check(app.session.state.coins==sale_coins,"打开出售确认不交易")
	await capture("corpse-confirm")
	app.current_page.confirm_selection(); await settle()
	check(app.session.state.coins==sale_coins+2,"尸体确认后实际获得二币")
	app.current_page.switch_mode(false)
	var row: Dictionary=app.current_page.context.shop.stock[0]
	app.current_page.select_buy(row); app.current_page.confirm_selection(); await settle()
	check(app.session.state.shop.purchased[row.id]==1,"确认购买实际扣费与更新库存")
	check(app.current_page.context.shop.stock.filter(func(item):return item.kind=="resource").all(func(item):return item.price==2),"购买一次后全部资源显示二币")
	row=app.current_page.context.shop.stock[0]
	app.current_page.select_buy(row); app.current_page.confirm_selection(); await settle()
	check(app.session.state.shop.purchased[row.id]==2,"第二张购买后售罄")
	check(app.current_page.context.shop.stock.filter(func(item):return item.kind=="resource" and item.id!=row.id).all(func(item):return item.price==4),"另一种资源显示共享四币价")
	await capture("sold-out")
	root.size=Vector2i(1600,900); await settle(); app.render(); await capture("shop-1600")
	event_fixture("storm","hold"); app.handle_command("option",{"id":"take"}); await capture("cargo-stage")
	event_fixture("storm","surface"); await capture("target-preview")
	check(is_instance_valid(app.event_target_surface),"选择目标时高亮实际筏格")
	check(app.current_page.context.event_options.size()>=3,"格损选项与目标公开")
	app.queue_free(); await process_frame
	print("NODE SHOP GPU: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
