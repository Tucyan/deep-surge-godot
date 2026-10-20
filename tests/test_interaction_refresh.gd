extends SceneTree
var app
var failures:=0
func _init(): call_deferred("run")
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle(): await process_frame; await process_frame
func identity() -> Array:
	return [app.layout.get_instance_id(),app.find_child("hand_fan",true,false).get_instance_id(),app.world_view.cells.get_child(0).get_instance_id()]
func close_modal():
	var overlay=app.find_child("CloseOverlay",true,false)
	check(overlay!=null,"modal close overlay exists")
	if overlay!=null: overlay.find_child("CloseX",true,false).pressed.emit()
	await settle()
func run():
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
	var before:=identity(); var rules: Dictionary=app.session.snapshot()
	var reset: Button=app.find_child("ResetRaftView",true,false); reset.disabled=true
	app.handle_ui("camera_toggle"); await settle()
	check(identity()==before,"camera toggle preserves HUD/hand/cells")
	check(app.find_child("ViewModeIcon",true,false).texture==app.assets.texture("icon.camera.oblique"),"camera destination icon updates")
	check(app.session.snapshot()==rules,"camera leaves rules unchanged")
	for panel in ["settings","help","craft","build","raft"]:
		before=identity()
		if panel in ["settings","help"]: app.handle_ui("local_panel",panel)
		else: app.handle_command("panel",{"id":panel})
		await settle()
		check(identity()==before,panel+" opens without replacing base HUD/hand/cells")
		var fan=app.find_child("hand_fan",true,false)
		check(not fan.can_process(),panel+" blocks background hand processing/input")
		check(not app.world_view.camera_input_enabled,panel+" blocks background camera")
		await close_modal()
		check(identity()==before,panel+" closes without replacing base HUD/hand/cells")
		check(app.find_child("ResetRaftView",true,false).disabled,"previously disabled controls stay disabled")
		check(not app.find_child("CraftEntry",true,false).disabled,"normal buttons restore enabled state")
		check(app.find_child("hand_fan",true,false).can_process(),"hand processing resumes")
		check(app.current_page.context.revision==app.session.revision,"base commands use current revision after close")
		check(app.world_view.camera_input_enabled,"camera input restored")
	# A real rule change while a modal is open must refresh stale background HUD.
	app.handle_command("panel",{"id":"craft"}); await settle()
	before=identity(); app.session.give("wood",1,false,"refresh-fixture"); app.render(); await settle()
	check(identity()!=before,"rule change uses full refresh fallback")
	await close_modal()
	var interaction=app.find_child("RaftInteraction",true,false)
	check(interaction!=null and interaction.can_process() and interaction.surface.visible,"raft interaction restores after full rebuild beneath modal")
	app.message="fixture_old_notice"; app.render(); await settle()
	before=identity(); app.handle_command("panel",{"id":"craft"}); await settle(); await close_modal()
	check(identity()==before,"notice cleanup does not rebuild HUD")
	check(app.find_children("*","Label",true,false).all(func(n):return n.text!="fixture_old_notice"),"cleared errors do not remain in retained HUD")
	app.handle_ui("local_panel","settings"); await settle()
	app.message="fixture_modal_notice"; app.render(); await settle(); await close_modal()
	check(app.find_children("*","Label",true,false).any(func(n):return n.text=="fixture_modal_notice"),"current modal notice remains visible after close")
	app.message=""; app.render(); await settle()
	# Normal departure after panel revisions is still accepted.
	var option: Button=app.find_children("NavigationOption","Button",true,false)[0]
	option.pressed.emit(); await settle()
	app.find_child("NavigationDepart",true,false).pressed.emit(); await settle()
	check(app.session.phase()=="preparation","departure after modal close is not stale")
	# Combat fixture: preview, raised cards and confirm button change locally.
	var state: Dictionary=app.session.state
	state.node=app.catalog.entry("nodes","battle"); state.node.visit_id="refresh-combat"; state.phase="battle"
	state.battle={"id":"biter","hp":6,"turn":1,"ap":3,"entry_hp":40,"poison_until":0,"fear_until":0,"shields":[],"raft_target_cell":state.cells[0].id,"intent":{"type":"biter_bite","target_cell":state.cells[0].id,"cell_damage":1}}
	app.render(); await settle()
	before=identity(); rules=app.session.snapshot()
	var bview=app.find_child("BattleHUDView",true,false)
	var bview_id: int=bview.get_instance_id()
	var fan=app.find_child("hand_fan",true,false)
	var resource: Dictionary=fan.cards.filter(func(c):return c.definition.kind=="resource")[0]
	bview.on_card_clicked(resource); await settle()
	check(identity()==before,"battle resource selection keeps HUD and hand")
	check(app.find_child("BattleHUDView",true,false).get_instance_id()==bview_id,"battle preview instance preserved")
	bview=app.find_child("BattleHUDView",true,false)
	var attack: Dictionary=app.find_child("hand_fan",true,false).cards.filter(func(c):return c.uid=="virtual_action_attack")[0]
	bview.on_card_clicked(attack); await settle()
	check(identity()==before,"battle action selection keeps HUD and hand")
	check(app.find_child("hand_fan",true,false).selected_uids.has("virtual_action_attack"),"selected action visibly raised")
	check(not app.find_child("ConfirmBattleAction",true,false).disabled,"confirmation enables after valid selection")
	check(app.session.snapshot()==rules,"combat selection never dispatches rules or RNG")
	# A resolved battle action changes live combat state, but the battle HUD, hand,
	# and world cell geometry are still the same structures and should be retained.
	before=identity()
	var battle_view_id: int=app.find_child("BattleHUDView",true,false).get_instance_id()
	app.handle_command("battle_action",{"action":"attack"}); await settle()
	check(identity()==before,"battle action retains voyage layout, hand and cells")
	check(app.find_child("BattleHUDView",true,false).get_instance_id()==battle_view_id,"battle action retains BattleHUDView")
	check(int(app.session.state.battle.hp)==5 and int(app.session.state.battle.ap)==2,"battle action refreshes enemy HP and AP from dispatched rules")
	check(app.find_child("SurgeActionPointHUD",true,false).current_ap==int(app.session.state.battle.ap),"battle action point display matches dispatched AP")
	check(app.find_child("BattlePreviewSummary",true,false).text.contains("从下方手牌选择"),"resolved action clears stale selection preview")
	check(app.find_child("BattleHUDView",true,false).log_box.get_child_count()>0,"resolved action refreshes combat log in place")
	var changed_phase: Dictionary=app.hud_view(); changed_phase.phase="aftermath"
	check(not app.current_page.refresh_after_battle(changed_phase),"battle refresh rejects phase transitions for full-render fallback")
	var changed_hand: Dictionary=app.hud_view(); changed_hand.hand.append({"uid":"structure-change"})
	check(not app.current_page.refresh_after_battle(changed_hand),"battle refresh rejects hand structure changes for full-render fallback")
	app.handle_ui("local_panel","settings"); await settle(); await close_modal()
	check(identity()==before,"combat modal preserves selected hand")
	check(app.current_page.context.ui_state.battle_selection==app.ui_state.battle_selection,"base context retains selection after modal close")
	app.queue_free(); await process_frame
	print("INTERACTION REFRESH: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
