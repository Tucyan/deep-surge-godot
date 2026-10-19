extends SceneTree
const T = preload("res://core/tutorial_rules.gd")
var failures := 0
var app
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle():
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
func uid(id: String) -> String: return T.hand_uid(app.session.state,id)
func step(command: String, args: Dictionary = {}):
	check(app.session.dispatch(command,args),command+": "+app.session.error)
func discard_rest():
	for i in range(40):
		if app.session.phase()!="discard": return
		var found:=false
		for card in app.session.state.hand:
			if card.id not in ["coin","corpse","pollution","punch"]:
				step("discard",{"uid":card.uid}); found=true; break
		if not found: break
	check(app.session.phase()!="discard","discard clears")
func banner_text() -> String:
	return " ".join(app.find_child("TutorialBanner",true,false).find_children("*","Label",true,false).map(func(n):return n.text))
func screen_touch(down: bool, point: Vector2):
	var event:=InputEventScreenTouch.new(); event.index=0; event.pressed=down
	event.position=root.get_final_transform()*point
	Input.parse_input_event(event)
func play_card(id: String = "spear"):
	var fan=app.find_child("hand_fan",true,false); fan._process(1.0)
	var index: int=fan.cards.find(fan.cards.filter(func(c):return c.id==id)[0])
	var start: Vector2=fan.tiles[index].global_position+Vector2(40,65)
	screen_touch(true,start)
	await create_timer(.07).timeout
	check(fan.dragging,"native touch starts 0.05s gesture")
	var finish: Vector2=Vector2(fan.global_position.x+fan.size.x*.5,fan.global_position.y-40)
	var drag:=InputEventScreenDrag.new(); drag.index=0; drag.position=root.get_final_transform()*finish
	Input.parse_input_event(drag); await process_frame
	screen_touch(false,finish); await settle()
func select_resource(id: String):
	var fan=app.find_child("hand_fan",true,false); fan._process(1.0)
	var card: Dictionary=fan.cards.filter(func(c):return c.id==id)[0]
	var index: int=fan.cards.find(card)
	var point: Vector2=fan.tiles[index].global_position+Vector2(40,65)
	screen_touch(true,point); screen_touch(false,point); await settle()
	check(app.find_child("BattleHUDView",true,false).selected_resource_uid==card.uid,"native tap selects resource: "+id)
func capture(id: String):
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://evidence/tutorial-mobile-battle-"+id+".png")==OK,"capture "+id)
func run():
	root.size=Vector2i(1680,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.display_settings.mobile=true; app.display_settings.free_aspect=true; app.display_settings.ui_scale=1.25
	app.apply_display_settings(false); await settle()
	step("new",T.start_args())
	step("voyage",{"id":app.session.state.candidates[0].visit_id})
	step("salvage"); step("salvage"); step("craft",{"id":"filter"}); step("install",{"uid":uid("filter"),"auto":true})
	step("enter"); step("advance"); step("option",{"id":"wood"}); step("advance"); step("end_voyage"); discard_rest()
	step("play",{"uid":uid("water")}); step("play",{"uid":uid("food")})
	step("voyage",{"id":app.session.state.candidates[0].visit_id})
	step("enter"); step("advance"); step("fight")
	app.render(); await settle()
	check(T.current_step(app.session.state)=="attack2a","tutorial reached first attack")
	check(banner_text().contains("拖") and not banner_text().contains("双击"),"mobile lesson explains drag instead of double click")
	for resolution in [Vector2i(1680,720),Vector2i(1260,540),Vector2i(2520,1080)]:
		root.size=resolution; app.render(); await settle()
		var banner=app.find_child("TutorialBanner",true,false)
		check(banner.get_global_rect().end.y<=100,"battle lesson overlays the voyage heading instead of reserving a row")
		check(banner.get_global_rect().end.x<=(app.size.x-200)*.42+28,"lesson avoids health status")
		check(app.find_child("BattleHUDView",true,false).panel_layout.position.y<=120,"tutorial battle keeps full-height reading area")
		var hand=app.find_child("VoyageHandTopBar",true,false)
		for name in ["MonsterPanel","EnemyIntentPanel","ActionPreviewPanel","CombatLogPanel"]:
			var panel=app.find_child(name,true,false)
			check(not panel.get_global_rect().intersects(banner.get_global_rect()),"tutorial banner clears "+name)
			check(panel.get_global_rect().end.y<hand.global_position.y,"tutorial panel clears hand")
		for name in ["BattleSkipTurn","BattleRetreat","CancelBattleSelection"]:
			var button=app.find_child(name,true,false)
			check(app.get_global_rect().encloses(button.get_global_rect()) and button.size.y>=44,"tutorial touch target "+name)
		var battle_view=app.find_child("BattleHUDView",true,false)
		check(battle_view.preview_summary_label.text.contains("矛击"),"tutorial preview follows the prompted spear action")
		check(app.find_child("MobileIntentScroll",true,false).get_global_rect().grow(2).encloses(battle_view.intent_label.get_global_rect()),"tutorial intent is readable without clipped lines")
		check(app.find_child("MobilePreviewScroll",true,false).get_global_rect().grow(2).encloses(battle_view.preview_detail_label.get_global_rect()),"tutorial initial preview details are visible")
		await capture("%dx%d-initial" %[resolution.x,resolution.y])
	root.size=Vector2i(1680,720); app.render(); await settle()
	var before: Dictionary=app.session.snapshot()
	var spear_uid:=uid("spear")
	var hp_before: int=app.session.state.player.hp
	await play_card()
	check(T.current_step(app.session.state)=="enchant_attack2" and app.session.state.battle.hp==3,"first native drag advances to attack enchantment and deals 3")
	check(app.find_child("BattleHUDView",true,false).preview_summary_label.text.contains("攻击附魔"),"preview directs attack enchantment")
	check(app.session.state.battle.ap==2 and not app.session.state.hand.any(func(c):return c.uid==spear_uid),"first drag spends exactly one spear and AP")
	await capture("1680x720-first-attack")
	if T.current_step(app.session.state)!="enchant_attack2": app.queue_free(); quit(failures); return
	await select_resource("iron")
	await play_card("action_attack")
	check(T.current_step(app.session.state)=="enchant_block2" and app.session.state.battle.hp==1,"native iron enchantment deals two damage")
	await capture("1680x720-attack-enchantment")
	await select_resource("wood")
	await play_card("action_block")
	check(T.current_step(app.session.state)=="endturn2" and app.session.state.battle.ap==0,"native wood enchantment completes defense")
	await capture("1680x720-defense-enchantment")
	# A second attack at the wrong lesson must leave the rule snapshot untouched.
	before=app.session.snapshot(); await play_card()
	check(app.session.snapshot()==before,"wrong-step attack preserves inventory AP and RNG")
	var skip=app.find_child("BattleSkipTurn",true,false)
	var skip_point: Vector2=skip.get_global_rect().get_center()
	screen_touch(true,skip_point); await process_frame; screen_touch(false,skip_point); await settle()
	check(T.current_step(app.session.state)=="attack2b","native skip advances to second attack")
	check(app.session.state.player.hp==hp_before and T.damaged_cells(app.session.state).size()==1,"enchanted defense protects HP while enemy damages raft once")
	await capture("1680x720-second-turn")
	await play_card()
	check(app.session.phase()=="story" and T.current_step(app.session.state)=="finish2","second native drag wins tutorial fight")
	await capture("1680x720-victory")
	step("advance"); step("end_voyage"); discard_rest()
	step("play",{"uid":uid("water")}); step("play",{"uid":uid("food")})
	step("voyage",{"id":app.session.state.candidates[0].visit_id})
	check(T.current_step(app.session.state)=="repair3","battle continues to repair lesson")
	app.render(); await settle()
	check(app.find_child("ResetRaftView",true,false).is_visible_in_tree(),"camera utility restored after tutorial fight")
	app.queue_free(); await settle()
	print("TUTORIAL MOBILE BATTLE: "+("PASS" if failures==0 else "FAIL")); quit(failures)
