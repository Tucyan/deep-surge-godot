extends SceneTree
var failures := 0
var app
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func settle():
	await process_frame; await process_frame; await process_frame
func _init(): call_deferred("run")
func battle(origin: String):
	app.setup_mode=""
	app.session=load("res://core/game_session.gd").new(app.catalog)
	var s=app.session
	s.dispatch("new",{"mode":"challenge","origin":origin,"seed":22})
	s.state.node=app.catalog.entry("nodes","battle"); s.state.node.visit_id="origin-ui"
	s.state.phase="story"; s.state.story_step="choice"; s.state.hand=[]
	s.dispatch("fight"); s.state.battle.ap=0
	app.render(); await settle()
	return s
func capture(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/origins-v1-"+name+".png")
func run():
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_ui("setup","challenge"); await settle()
	var setup=app.current_page; setup.chosen_difficulty="standard"; setup.rebuild(); await settle()
	var choices=app.find_child("OriginChoice",true,false)
	check(choices!=null and choices.item_count==9,"all nine origins listed")
	check(choices.is_item_disabled(8),"scavenger disabled in real selector")
	check(app.find_child("OriginDescription",true,false)!=null,"separate readable origin description")
	await capture("setup")
	var s=await battle("zealot")
	var before=s.snapshot()
	var view=app.find_child("BattleHUDView",true,false)
	view.on_card_clicked({"uid":"virtual_action_attack","id":"action_attack","action_id":"attack"})
	check(not view.confirm_button.disabled,"special AP enables confirm at zero ordinary AP")
	check(not app.find_child("BattleAttack",true,false).disabled,"real hand attack button remains enabled with special AP")
	check(view.preview_summary_label.text.contains("战意"),"preview explains special AP cost")
	var hud=app.find_child("SurgeActionPointHUD",true,false)
	check(hud.label_text.contains("战意") and hud.current_ap==0,"ordinary AP separate from displayed special AP")
	check(app.find_child("SalvageEntry",true,false).disabled,"cannot salvage with only special AP")
	check(before==s.snapshot(),"UI preview preserves rules and RNG")
	await capture("zealot")
	view.on_action_double_clicked({"uid":"virtual_action_attack","id":"action_attack","action_id":"attack"})
	check(s.state.battle.turn==2,"real double click spends special AP and auto advances")
	s=await battle("skeptic"); s.give("pollution",2,true,"battle"); app.render(); await settle()
	view=app.find_child("BattleHUDView",true,false)
	var card: Dictionary=s.view().hand[0]
	view.selected_buff_uid="previous-attack-boost"
	for fan in get_nodes_in_group("hand_fans"):
		if fan.context.get("phase","")!="battle": continue
		for i in range(fan.cards.size()):
			if fan.cards[i].uid==card.uid: check(not fan.buttons[i].disabled,"real pollution hand button is enabled for free clear")
	view.on_card_clicked(card)
	check(not view.confirm_button.disabled,"free pollution selectable at zero AP")
	check(view.selected_buff_uid=="","pollution selection clears unrelated attack boost")
	check(view.preview_detail_label.text.contains("清除1张污染"),"pollution preview describes actual removal")
	await capture("skeptic")
	view.on_action_double_clicked(card)
	check(s.state.battle.turn==2,"real double click uses free clear")
	app.queue_free(); await settle()
	print("ORIGINS UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
