extends SceneTree
var app
var failures:=0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func screenshot(name: String):
	if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/acquisition-"+name+".png")
func wait_for_overlay():
	var frames:=0
	while not is_instance_valid(app.acquisition_overlay) and frames<240:
		await process_frame; frames+=1
	check(is_instance_valid(app.acquisition_overlay),"acquisition overlay appears")
	await create_timer(.25).timeout
func dismiss():
	var overlay=app.acquisition_overlay
	if not is_instance_valid(overlay): return
	var saved: Dictionary=app.session.snapshot()
	var before: Vector2=overlay.tiles[0].global_position
	# Inspect the real card button; this must not trigger collect or use a card.
	var buttons=overlay.tiles[0].find_children("*","Button",true,false)
	buttons[0].pressed.emit(); await process_frame
	check(overlay.inspection.visible and not overlay.description.text.is_empty() and not overlay.collecting,"card click reveals description without dismissing")
	await screenshot("inspect")
	var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=Vector2(24,240)
	root.push_input(click,true); await process_frame
	check(overlay.collecting,"click outside begins collection")
	app.request_command("salvage")
	await create_timer(.2).timeout
	check(overlay.tiles[0].global_position.distance_to(before)>10,"cards travel toward hand instead of disappearing")
	await screenshot("flight")
	await create_timer(1.0).timeout
	check(app.session.snapshot()==saved,"inspect, repeat commands and collection do not alter rules/RNG")
	check(not is_instance_valid(overlay),"overlay removes itself after collecting")
func run():
	root.size=Vector2i(1280,720); Engine.max_fps=60
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.session.state.cells[0].equipment={"id":"fishingNet","level":2,"fuel":0,"progress":0,"boost_cards":[]}
	app.render()
	app.request_command("salvage"); await wait_for_overlay()
	if not is_instance_valid(app.acquisition_overlay): app.queue_free(); quit(1); return
	check(app.acquisition_overlay.batch.source=="打捞" and app.acquisition_overlay.batch.items.size()==3,"real salvage displays three actual cards")
	check(not app.world_view.camera_input_enabled,"camera disabled during acquisition")
	await screenshot("salvage"); await dismiss()
	app.session.state.cells[0].equipment={"id":"filter","level":2,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
	app.session.state.hand=[]; app.session.state.coins=0; app.session.state.phase="aftermath"; app.session.state.ap=1
	app.render(); app.request_command("end_voyage"); await wait_for_overlay()
	check(app.acquisition_overlay.batch.source=="设备生产" and app.acquisition_overlay.batch.items.size()==1,"production after voyage transition")
	var pending_uids: Array=app._pending_receipt.uids.duplicate()
	check(pending_uids.size()==3 and not app.hud_view().hand.any(func(card):return card.uid in pending_uids),"production and spring rewards remain hidden before confirmation")
	await screenshot("production"); await dismiss(); await wait_for_overlay()
	check(app.acquisition_overlay.batch.source=="涌泉" and app.acquisition_overlay.batch.items.size()==2,"spring after voyage transition")
	await screenshot("spring"); await dismiss()
	app.session.state.cells[0].equipment={}
	# Use the normal option dispatch for both fixed and random node effects.
	var old_options: Array=app.catalog._tables.nodes.camp.options.duplicate(true)
	app.catalog._tables.nodes.camp.options=[{"id":"take","name":"取走物资","cost":0,"effects":[{"type":"GiveCard","id":"wood","amount":2},{"type":"GiveRandomResource","amount":1}]}]
	app.session.state.node=app.catalog.entry("nodes","camp"); app.session.state.node.visit_id="acquisition-node"
	app.session.state.phase="story"; app.session.state.story_step="choice"; app.session.state.ap=3
	app.session.Encounter.arrived(app.session)
	app.render(); app.request_command("option",{"id":"take"}); await wait_for_overlay()
	check(app.acquisition_overlay.batch.source=="节点事件" and app.acquisition_overlay.batch.items.size()==3,"real event fixed/random rewards use acquisition overlay")
	pending_uids=app._pending_receipt.uids.duplicate()
	check(pending_uids.size()==3 and not app.hud_view().hand.any(func(card):return card.uid in pending_uids),"event cards remain hidden before confirmation")
	await screenshot("node-event"); await dismiss()
	check(app._pending_receipt.uids.is_empty(),"event confirmation clears pending receipt")
	app.catalog._tables.nodes.camp.options=old_options
	app.session.state.node=app.catalog.entry("nodes","battle"); app.session.state.node.visit_id="acquisition-battle"
	app.session.state.phase="story"; app.session.state.story_step="choice"; app.session.state.candidates=[]
	app.handle_command("fight"); app.session.state.battle.hp=1
	app.request_command("battle_action",{"action":"attack"}); await wait_for_overlay()
	check(app.acquisition_overlay.batch.source=="战斗","victory presents real battle drops")
	check(app.acquisition_overlay.batch.items.any(func(item):return item.id=="coin" and item.stack_count>0),"battle currency uses one quantity card for the actual gain")
	await screenshot("battle"); await dismiss()
	# A final salvage can auto-settle and grant spring cards in the same dispatch.
	app.session.state.phase="aftermath"; app.session.state.ap=1; app.session.state.hand=[]; app.session.state.coins=0
	app.render(); app.request_command("salvage"); await wait_for_overlay()
	check(app.acquisition_overlay.batch.source=="打捞","first receipt retains salvage source across automatic settlement")
	await dismiss(); await wait_for_overlay()
	check(app.acquisition_overlay.batch.source=="涌泉","second receipt queues spring independently")
	await dismiss()
	# Real formal-shop purchase, no presentation-only grant command.
	app.session.state.node=app.catalog.entry("nodes","trader"); app.session.state.node.visit_id="acquisition-shop"
	app.session.state.phase="story"; app.session.state.story_step="choice"; app.session.state.coins=100
	app.handle_command("shop_enter")
	var offer: Dictionary=app.session.view().shop.relic_stock[0]
	app.request_command("buy_collectible",{"id":offer.id,"payment":"coin"}); await wait_for_overlay()
	check(app.acquisition_overlay.batch.kind=="collectible","new relic uses acquisition overlay")
	var art=app.acquisition_overlay.find_child("CollectiblePlaceholder",true,false)
	check(art is TextureRect and is_equal_approx(art.size.x,art.size.y),"relic uses 1:1 supplied image")
	check(art.texture==app.assets.texture("relic."+offer.id),"relic uses its own cached artwork")
	check(art.texture.get_image().detect_alpha()!=Image.ALPHA_NONE,"relic artwork has real alpha")
	await screenshot("relic"); await dismiss()
	app.handle_command("shop_leave"); app.handle_command("advance")
	app.request_command("panel",{"id":"collectibles"}); await process_frame; await process_frame
	var grid=app.find_child("CollectiblesGrid",true,false)
	check(grid!=null and grid.columns==5,"warehouse keeps five columns")
	check(app.find_child("CollectiblesScroll",true,false)!=null,"warehouse scrolls instead of paging")
	var warehouse=app.find_child("CollectiblesWarehouse",true,false)
	check(warehouse!=null and grid.get_child_count()==warehouse.items.size(),"warehouse lists every owned relic")
	var region=app.find_child("CollectibleDetailImageRegion",true,false)
	var detail=app.find_child("CollectibleDetail",true,false)
	check(region!=null and region.size.y<=detail.size.y*.35,"detail art uses at most one third of the panel")
	await screenshot("warehouse")
	app.handle_command("close"); await process_frame; await process_frame
	var entry: Control=app.find_child("CollectiblesEntry",true,false)
	check(is_equal_approx(entry.size.x,entry.size.y) and entry.find_child("TreasureIcon",true,false)!=null,"round treasure icon entry")
	var labels=app.world_view.raft.find_children("*","Label3D",true,false)
	check(labels.any(func(label):return label.text=="潮汐遗物"),"second root cell displays collection label")
	var interaction=app.layout.get_node_or_null("RaftInteraction")
	if interaction!=null:
		var target: Dictionary=app.world_view.raft_models.root_cells(app.world_view._raft_layout)[1].duplicate(true)
		var point: Vector2=interaction.surface.screen_point(target)
		var picked: Dictionary=interaction._pick_click(point)
		check(picked.get("kind","")=="collectibles","second root cell is picked as collection")
		interaction.select_target(picked); await process_frame; await process_frame
		check(app.session.panel=="collectibles","second root cell opens same warehouse")
	app.queue_free(); await process_frame
	print("ACQUISITION UI: "+("PASS" if failures==0 else "FAIL")); quit(failures)
