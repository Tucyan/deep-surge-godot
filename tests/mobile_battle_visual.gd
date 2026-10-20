extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func settle():
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func run():
	root.size=Vector2i(1680,720)
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.display_settings.mobile=true; app.display_settings.ui_scale=1.25; app.display_settings.free_aspect=true
	app.apply_display_settings(false)
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":42})
	var s=app.session
	s.state.node=app.catalog.entry("nodes","battle"); s.state.node.visit_id="mobile-battle-visual"
	s.state.phase="story"; s.state.story_step="choice"
	check(s.dispatch("fight"),"enter battle")
	s.state.hand.clear()
	for id in ["wood","wood","iron","rope","cloth","water","spear"]: s.give(id,1,false,"mobile-visual")
	for resolution in [Vector2i(1680,720),Vector2i(1260,540),Vector2i(2520,1080),Vector2i(1280,720)]:
		root.size=resolution; app.render(); await settle()
		app.find_child("BattleHUDView",true,false).clear_selection()
		await settle()
		var before: Dictionary=s.snapshot()
		for state in ["initial","selected"]:
			if state=="selected":
				var bview=app.find_child("BattleHUDView",true,false)
				bview.on_card_clicked(s.view().hand.filter(func(c):return c.id=="wood")[0])
				await settle(); bview=app.find_child("BattleHUDView",true,false)
				bview.on_card_clicked({"uid":"virtual_action_attack","action_id":"attack"})
			await settle()
			var fan=app.find_child("hand_fan",true,false); fan._process(1.0)
			check(fan.mobile and is_equal_approx(fan.hold_seconds,.05),"mobile gesture enabled")
			if state=="selected":
				var badge=app.find_child("HandCapacityBadge",true,false)
				for i in range(fan.cards.size()):
					if fan.selected_uids.has(fan.cards[i].uid): check(fan.tiles[i].global_position.y>=badge.get_global_rect().end.y,"selected card clears hand information")
			var battle_view=app.find_child("BattleHUDView",true,false)
			check(not app.find_child("ResetRaftView",true,false).is_visible_in_tree() and not app.find_child("ToggleRaftView",true,false).is_visible_in_tree(),"battle hides both camera utilities")
			check(not app.find_child("CollectiblesEntry",true,false).is_visible_in_tree(),"battle hides the treasure entry")
			check(battle_view.panel_layout.position.x<=32,"battle reclaims the left camera utility gutter")
			check(battle_view.size.x>0 and battle_view.panel_layout.size.x>=battle_view.size.x*.75,"mobile information uses available width")
			var intent_label=app.find_child("BattleIntentTarget",true,false)
			var text_scale: float=intent_label.get_global_transform().get_scale().y
			check(intent_label.get_theme_font_size("font_size")*text_scale>=18,"intent stays readable without shrinking text")
			for button_name in ["BattleSkipTurn","BattleRetreat","CancelBattleSelection"]:
				var button=app.find_child(button_name,true,false)
				check(button.get_global_rect().size.y>=44,"mobile battle touch target: "+button_name)
			var hand_top: float=app.find_child("VoyageHandTopBar",true,false).global_position.y
			for name in ["MonsterPanel","ActionPreviewPanel","CombatLogPanel","ConfirmBattleAction"]:
				var control=app.find_child(name,true,false)
				check(control!=null and app.get_global_rect().grow(2).encloses(control.get_global_rect()),"panel within viewport: "+name)
				if name!="ConfirmBattleAction": check(control.get_global_rect().end.y<=hand_top-8,"battle panels clear hand header")
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://evidence/mobile-battle-%dx%d-%s.png" %[resolution.x,resolution.y,state])==OK,"save screenshot")
			check(s.snapshot()==before,"preview does not mutate gameplay")
	root.size=Vector2i(1680,720)
	s.state.cells[0].equipment={"id":"generator","level":1,"fuel":2,"progress":0,"boost_cards":[{"uid":"mobile-boost","id":"barrier"}],"production_bonus":0}
	app.render(); await settle()
	var boost=app.find_child("BattleBoostSelect",true,false)
	check(boost!=null and boost.get_global_rect().size.y>=44,"mobile boost selector has touch target")
	boost.select(0); boost.item_selected.emit(0); await settle()
	var view=app.find_child("BattleHUDView",true,false)
	view.on_card_clicked(s.view().hand.filter(func(c):return c.id=="wood")[0]); await settle()
	view=app.find_child("BattleHUDView",true,false)
	view.on_card_clicked({"uid":"virtual_action_block","action_id":"block"}); await settle()
	var scroll=app.find_child("MobilePreviewScroll",true,false)
	scroll.scroll_vertical=99999; await settle()
	view=app.find_child("BattleHUDView",true,false)
	check(scroll.get_global_rect().grow(2).encloses(view.preview_detail_label.get_global_rect()),"boost preview remains reachable by scrolling")
	check(not app.find_child("ConfirmBattleAction",true,false).disabled,"boost combination stays valid")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/mobile-battle-1680x720-boost.png")
	view.context.mode="tutorial"; view.layout_panels(); await settle()
	var log_panel=app.find_child("CombatLogPanel",true,false)
	for id in ["BattleSkipTurn","BattleRetreat"]:
		check(log_panel.get_global_rect().encloses(app.find_child(id,true,false).get_global_rect()),"tutorial compact log contains "+id)
	s.state.phase="aftermath"; s.panel=""; app.render(); await settle()
	check(app.find_child("ResetRaftView",true,false).is_visible_in_tree() and app.find_child("ToggleRaftView",true,false).is_visible_in_tree(),"camera utilities return after battle")
	check(app.find_child("CollectiblesEntry",true,false).is_visible_in_tree(),"treasure entry returns after battle")
	app.queue_free(); await settle()
	print("MOBILE BATTLE VISUAL: "+("PASS" if failures==0 else "FAIL")); quit(failures)
