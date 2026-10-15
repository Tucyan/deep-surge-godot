extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures += 1; printerr("FAIL: "+why)
func fan(app):
	return get_nodes_in_group("hand_fans").filter(func(n): return app.layout.is_ancestor_of(n) and n.get_meta("presentation_role","")=="voyage")[0]
func run():
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	check(not app.session.view().hand.any(func(c):return c.id=="coin"),"Zero balance has no coin card")
	app.session.I.give(app.session.state,"coin",7,false,"coin-test")
	var before=app.session.snapshot()
	var view=app.session.view()
	var coins=view.hand.filter(func(c):return c.id=="coin")
	check(coins.size()==1,"Positive balance appears as one hand card")
	if coins.size()!=1: app.queue_free(); await process_frame; quit(failures); return
	check(coins[0].uid=="coins" and coins[0].quantity==7 and coins[0].definition.kind=="currency","Stable currency card identity and quantity")
	check(view.capacity==app.session.state.hand.size()+1,"Coins occupy exactly one capacity")
	for stacked in [true,false]:
		app.hand_layout.stack_resources=stacked
		var grouped=app.hand_layout.build(view.hand).filter(func(c):return c.id=="coin")
		check(grouped.size()==1 and grouped[0].stack_count==7,"Currency quantity survives either stacking preference")
	check(app.session.snapshot()==before,"Reading coin card leaves save and RNG untouched")
	coins[0].quantity=999
	check(app.session.view().hand.filter(func(c):return c.id=="coin")[0].quantity==7,"View is independent of balance")
	app.render(); await process_frame; await process_frame
	var tray=fan(app)
	var coin=tray.cards.filter(func(c):return c.id=="coin")[0]
	check(tray.usage(coin).contains("商店") and not tray.usage(coin).contains("制作材料"),"Coin tooltip explains payment")
	tray.activated.emit(coin); await process_frame
	check(app.ui_state.card=="coins" and app.session.state.coins==7,"Coin click opens details without spending")
	if "--capture" in OS.get_cmdline_user_args():
		root.size=Vector2i(1280,720); await process_frame; await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/coin-card-1280.png")
	check(app.session.I.consume(app.session.state,"coin",2,"shop"),"Pay currency")
	check(app.session.view().hand.filter(func(c):return c.id=="coin")[0].quantity==5,"Payment updates card quantity")
	var restored=load("res://core/game_session.gd").new(app.catalog)
	check(restored.restore(app.session.snapshot()),"Currency save restores")
	check(restored.view().hand.filter(func(c):return c.id=="coin")[0].quantity==5,"Restore projects the same coin card")
	app.session.I.consume(app.session.state,"coin",5,"shop")
	check(not app.session.view().hand.any(func(c):return c.id=="coin"),"Paying last coin removes card")
	app.session.I.give(app.session.state,"coin",3,false,"coin-test")
	app.session.state.phase="discard"; app.session.state.player.limit=app.session.I.capacity(app.session.state)-1
	app.render(); await process_frame; await process_frame
	tray=fan(app); coin=tray.cards.filter(func(c):return c.id=="coin")[0]
	check(tray.action_name(coin).begins_with("弃置全部"),"Discard warns that entire balance is discarded")
	tray.activated.emit(coin); await process_frame
	check(app.session.state.coins==0 and app.session.phase()=="navigation","Click coin card discards balance and resolves capacity")
	check(not app.session.view().hand.any(func(c):return c.id=="coin"),"Discard removes coin card")
	app.queue_free(); await process_frame
	print("COIN CARD: PASS" if failures==0 else "COIN CARD: FAIL"); quit(failures)
