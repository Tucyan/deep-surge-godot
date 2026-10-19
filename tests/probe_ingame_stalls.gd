extends SceneTree
## Diagnostic inventory, not a performance pass/fail threshold. Use graphical Godot.
class TimedAssets extends "res://presentation/asset_catalog.gd":
	var texture_us := 0
	func texture(id: String) -> Texture2D:
		var start := Time.get_ticks_usec()
		var result := super.texture(id)
		texture_us += Time.get_ticks_usec()-start
		return result
class TimedApp extends "res://flow_app.gd":
	var render_us := 0
	var save_us := 0
	var view_us := 0
	var pages_us: Dictionary = {}
	func hud_view() -> Dictionary:
		var start := Time.get_ticks_usec()
		var result := super.hud_view()
		view_us += Time.get_ticks_usec()-start
		return result
	func page(id: String, parent: Node, view: Dictionary) -> Control:
		var start := Time.get_ticks_usec()
		var result := super.page(id,parent,view)
		pages_us[id]=pages_us.get(id,0)+Time.get_ticks_usec()-start
		return result
	func render(staged: bool = false) -> void:
		var start := Time.get_ticks_usec()
		super.render(staged)
		render_us += Time.get_ticks_usec()-start
	func _persist_profile() -> bool:
		var start := Time.get_ticks_usec()
		var result := super._persist_profile()
		save_us += Time.get_ticks_usec()-start
		return result
var app
var rows: Array = []
var failures: Array = []
var output := "res://evidence/ingame-stalls-20261019.json"
func _init(): call_deferred("run")
func settle():
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
func check(ok: bool, label: String):
	if not ok: failures.append(label); printerr("FAIL: "+label)
func press(name: String):
	var button = app.find_child(name,true,false)
	check(button!=null and not button.disabled,"enabled button "+name)
	if button!=null and not button.disabled: button.pressed.emit()
func collect_receipt():
	if is_instance_valid(app.acquisition_overlay):
		app.acquisition_overlay.collect()
		await create_timer(1).timeout
	check(not is_instance_valid(app.acquisition_overlay),"receipt finished")
func measure(label: String, iteration: int, operation: Callable, changes_rules := false):
	await settle()
	var hud_id: int=app.layout.get_instance_id()
	var page_id: int=app.current_page.get_instance_id()
	var before: Dictionary={"state":app.session.state.duplicate(true),"profile":app.session.profile.duplicate(true)}
	app.render_us=0; app.save_us=0; app.view_us=0; app.pages_us.clear(); app.assets.texture_us=0
	var start := Time.get_ticks_usec()
	operation.call()
	var sync_ms: float=(Time.get_ticks_usec()-start)/1000.0
	await process_frame; await RenderingServer.frame_post_draw
	var draw_ms: float=(Time.get_ticks_usec()-start)/1000.0
	var max_frame := 0.0
	var last := Time.get_ticks_usec()
	for i in range(8):
		await process_frame
		var now := Time.get_ticks_usec()
		max_frame=maxf(max_frame,(now-last)/1000.0); last=now
	check(app.message.is_empty(),label+" error: "+app.message)
	var after: Dictionary={"state":app.session.state,"profile":app.session.profile}
	if not changes_rules: check(before==after,label+" keeps rules/RNG")
	else: check(before!=after,label+" changes rules")
	var row := {"action":label,"iteration":iteration,"sync_ms":sync_ms,"draw_ms":draw_ms,"following_max_frame_ms":max_frame,"render_ms":app.render_us/1000.0,"save_ms":app.save_us/1000.0,"rebuilt_hud":hud_id!=app.layout.get_instance_id(),"rebuilt_page":page_id!=app.current_page.get_instance_id(),"phase":app.session.phase(),"error":app.message}
	row.view_ms=app.view_us/1000.0; row.page_build_us=app.pages_us.duplicate(); row.texture_ms=app.assets.texture_us/1000.0
	rows.append(row)
	print("INGAME "+JSON.stringify(row))
func reset_fixture(snapshot: Dictionary):
	app.persistence=false
	check(app.session.restore(snapshot),"fixture restore")
	app.session.screen="game"; app.session.panel=""
	app.local_panel=""; app.ui_state.battle_selection=""; app.message=""
	app.render(); await settle()
func stats(values: Array) -> Dictionary:
	values.sort()
	var n := values.size()
	return {"median":values[n/2] if n%2 else (values[n/2-1]+values[n/2])/2.0,"max":values[-1]}
func run():
	if DisplayServer.get_name()=="headless": printerr("Requires graphical renderer"); quit(1); return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	root.size=Vector2i(1280,720)
	app=TimedApp.new(); app.persistence=false; app.assets=TimedAssets.new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(app)
	await settle()
	app.handle_command("new",{"mode":"challenge","difficulty":"standard","origin":"strong","seed":22})
	for id in ["wood","wood","wood","plastic","plastic","plastic","iron","cloth","rope"]: app.session.give(id,1,false,"stall-probe")
	app.session.state.player.limit=100
	app.render(); await create_timer(1).timeout
	var initial: Dictionary=app.session.snapshot()
	for i in range(6):
		await reset_fixture(initial)
		await measure("idle",i,func(): pass)
		await measure("camera_toggle",i,func(): app.handle_ui("camera_toggle"))
		for panel in ["settings","help","craft","raft","collectibles"]:
			await measure("open_"+panel,i,func():
				if panel in ["settings","help"]: app.handle_ui("local_panel",panel)
				else: app.handle_command("panel",{"id":panel}))
			if panel=="craft":
				await measure("craft_to_transmute",i,func(): press("TransmuteTabButton"))
				await measure("transmute_add_wood",i,func():
					var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
					app.find_child("MatItem_wood",true,false).gui_input.emit(event))
				await measure("transmute_target_plastic",i,func(): press("SelectTarget_plastic"))
				await measure("transmute_to_craft",i,func(): press("CraftTabButton"))
			await measure("close_"+panel,i,func():
				if panel in ["settings","help"]: app.handle_ui("local_panel","")
				else: app.handle_command("close"))
		# Rule-changing fixtures: use current public command pipeline and keep receipts.
		check(app.session.dispatch("voyage",{"id":app.session.view().candidates[0].visit_id}),"depart fixture")
		app.session.state.ap=8
		app.render(); await settle()
		var preparation: Dictionary=app.session.snapshot()
		await measure("salvage",i,func(): app.request_command("salvage"),true)
		await collect_receipt()
		await reset_fixture(preparation)
		app.handle_command("panel",{"id":"craft"}); await settle()
		await measure("craft_lamp",i,func():
			for button in app.find_children("CraftRecipeButton","Button",true,false):
				if button.get_meta("recipe_id")=="lamp": button.pressed.emit(); return
			check(false,"lamp recipe button"),true)
		await collect_receipt()
		await reset_fixture(preparation)
		await measure("raft_select_empty_cell",i,func():
			var target: Dictionary=app.session.state.cells[0].duplicate(true); target.kind="cell"
			app.find_child("RaftInteraction",true,false).select_target(target))
		await measure("raft_deselect_cell",i,func(): app.find_child("RaftInteraction",true,false).select_target({}))
		app.session.state.phase="discard"; app.session.state.player.limit=app.session.I.capacity(app.session.state)-2
		app.render(); await settle()
		await measure("discard_wood",i,func():
			var card: Dictionary=app.session.state.hand.filter(func(c): return c.id=="wood")[0]
			app.request_command("discard",{"uid":card.uid}),true)
		await reset_fixture(preparation)
		app.session.give("filter",1,false,"stall-probe"); app.render(); await settle()
		var target: Dictionary=app.session.state.cells[0].duplicate(true); target.kind="cell"
		app.find_child("RaftInteraction",true,false).select_target(target); await settle()
		await measure("install_filter",i,func(): press("RaftAction_install"),true)
		await reset_fixture(preparation)
		await measure("transmute_execute",i,func():
			var wood: Array=app.session.state.hand.filter(func(c): return c.id=="wood")
			app.request_command("transmute",{"target":"plastic","uids":[wood[0].uid,wood[1].uid,wood[2].uid]}),true)
		await collect_receipt()
		await reset_fixture(preparation)
		app.session.state.node=app.catalog.entry("nodes","trader"); app.session.state.node.visit_id="stall-shop"
		app.session.state.phase="story"; app.session.state.story_step="choice"; app.session.state.coins=100
		app.session.give("corpse",1,false,"stall-probe"); app.render(); await settle()
		await measure("shop_enter",i,func(): app.request_command("shop_enter"),true)
		await measure("shop_sell_tab",i,func(): press("ShopSellTab"))
		await measure("shop_buy_tab",i,func(): press("ShopBuyTab"))
		await measure("shop_buy_preview",i,func(): app.current_page.select_buy(app.session.view().shop.stock[0]))
		await measure("shop_buy_confirm",i,func(): app.current_page.confirmation.confirmed.emit(),true)
		await collect_receipt()
		await measure("shop_leave",i,func(): app.request_command("shop_leave"),true)
		await reset_fixture(preparation)
		var state: Dictionary=app.session.state
		state.node=app.catalog.entry("nodes","battle"); state.node.visit_id="stall-battle"; state.phase="battle"
		state.battle={"id":"biter","hp":60,"turn":1,"ap":3,"entry_hp":40,"poison_until":0,"fear_until":0,"shields":[],"raft_target_cell":state.cells[0].id,"intent":{"type":"biter_bite","target_cell":state.cells[0].id,"cell_damage":1}}
		app.render(); await settle()
		await measure("battle_select_attack",i,func():
			var fan=app.find_child("hand_fan",true,false)
			app.find_child("BattleHUDView",true,false).on_card_clicked(fan.cards.filter(func(c): return c.uid=="virtual_action_attack")[0]))
		await measure("battle_confirm_attack",i,func(): press("ConfirmBattleAction"),true)
	var summary := {}
	for row in rows:
		if summary.has(row.action): continue
		var group: Array=rows.filter(func(r): return r.action==row.action)
		var warm := group.slice(1)
		summary[row.action]={"first":group[0],"warm_sync_ms":stats(warm.map(func(r): return r.sync_ms)),"warm_draw_ms":stats(warm.map(func(r): return r.draw_ms)),"warm_render_ms":stats(warm.map(func(r): return r.render_ms))}
	var report := {"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"size":[1280,720],"version":app.session.VERSION,"persistence":false,"failures":failures,"summary":summary,"samples":rows}
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("INGAME_INVENTORY failures=%d rows=%d output=%s" % [failures.size(),rows.size(),output])
	app.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
