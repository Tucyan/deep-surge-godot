extends SceneTree
var failures:=0
var app
func _init(): call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func settle():
	for i in range(6): await process_frame
func notice(): return app.get_node_or_null("BattleTurnNotice")
func run():
	root.size=Vector2i(1280,720)
	app=load("res://flow_app.gd").new(); app.persistence=false
	app.display_settings.mobile=true
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":17}); await settle()
	app.session.state.node=app.catalog.entry("nodes","battle"); app.session.state.node.visit_id="turn-notice"
	app.session.state.phase="battle"
	app.session.state.battle={"id":"biter","hp":30,"turn":1,"ap":0,"entry_hp":40,"poison_until":0,"fear_until":0,"shields":[]}
	app.render(); await settle()
	check(not is_instance_valid(notice()),"no notice before advancing the turn")
	var skip:=app.find_child("BattleSkipTurn",true,false) as Button
	check(is_instance_valid(skip),"battle screen exposes its skip-turn button")
	if is_instance_valid(skip): skip.pressed.emit()
	while app._ui_command_pending: await process_frame
	await settle()
	var overlay=notice()
	check(app.session.phase()=="battle" and int(app.session.state.battle.turn)==2,"battle advances to the next turn")
	check(is_instance_valid(overlay),"advancing to next battle turn shows a notice")
	if is_instance_valid(overlay):
		var label=overlay.find_child("BattleTurnNoticeText",true,false)
		check(label.text.contains("第 2 回合"),"notice names the new turn")
		var panel=overlay.find_child("BattleTurnNoticePanel",true,false)
		check(panel.is_visible_in_tree(),"notice panel is visible in the scene tree")
		check(root.get_visible_rect().encloses(panel.get_global_rect()),"notice panel is within the viewport")
		var style=panel.get_theme_stylebox("panel")
		check(style.bg_color.a>0 and style.bg_color.a<1 and style.border_width_left==0,"notice uses a translucent solid dark rectangle")
		var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=Vector2(5,5)
		root.push_input(click,true); await settle()
		check(not is_instance_valid(overlay),"click anywhere dismisses the notice")
	var failed=app.get_node_or_null("BattleTurnNotice")
	if is_instance_valid(failed): failed.queue_free(); await settle()
	app.session.state.battle.ap=3
	app.request_command("battle_action",{"action":"attack"})
	while app._ui_command_pending: await process_frame
	await settle()
	check(not is_instance_valid(notice()),"battle actions that do not advance the turn show no notice")
	app.session.state.battle.ap=0
	app.request_command("battle_end")
	while app._ui_command_pending: await process_frame
	await settle()
	var timed=notice()
	check(is_instance_valid(timed),"a later turn advance shows a fresh notice")
	await create_timer(2.1).timeout
	check(not is_instance_valid(timed),"notice automatically disappears after two seconds")
	app.queue_free(); await settle()
	print("BATTLE TURN NOTICE: "+("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
