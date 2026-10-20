extends SceneTree
var failures:=0
var app
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle():
	for i in range(5): await process_frame
func notice(): return app.get_node_or_null("DepartureNotice")
func run():
	root.size=Vector2i(1680,720); Engine.max_fps=60
	app=load("res://flow_app.gd").new(); app.persistence=false
	app.display_settings.mobile=true
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
	app.handle_ui("nav_select",str(app.session.state.candidates[0].visit_id)); await settle()
	check(not is_instance_valid(notice()),"selection does not show settlement")
	app.handle_command("voyage",{"id":"missing"}); await settle()
	check(not is_instance_valid(notice()),"failed departure does not show settlement")
	app.message=""
	root.size=Vector2i(1680,720); root.content_scale_size=Vector2i(1680,720)
	await settle()
	for scenario in ["normal","dead_click","dead_auto","mad_touch"]:
		var fatal: bool=scenario!="normal"
		if fatal:
			app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
			app.session.state.player.hp=1; app.session.state.player.hunger=5; app.session.state.player.hydration=0
			if scenario=="mad_touch":
				app.session.state.player.hp=10; app.session.state.player.hunger=80; app.session.state.player.hydration=80; app.session.state.player.sanity=1
		var before: Dictionary=app.session.state.player.duplicate(true)
		var retained_page=app.current_page
		var id: String=app.session.state.candidates[0].visit_id
		app.handle_command("voyage",{"id":id}); await settle()
		var overlay=notice()
		check(is_instance_valid(overlay),"successful departure shows settlement including fatal departure")
		if not is_instance_valid(overlay): continue
		var after: Dictionary=app.session.state.player
		var label=overlay.find_child("DepartureNoticeText",true,false)
		if fatal:
			check(app.session.phase()=="finished","failure is committed before notice")
			check(label.text.contains("游戏失败"),"notice explicitly announces failure")
			check(label.text.contains("精神归零" if scenario=="mad_touch" else "生命归零"),"notice explains failure reason")
			check(app.current_page==retained_page,"settlement page is deferred until notice ends")
			app.render(); await settle()
			check(app.current_page==retained_page,"extra render cannot expose settlement early")
			var checkpoint: Dictionary=app.session.snapshot()
			app.handle_command("home"); app.handle_ui("local_panel","settings")
			check(app.session.snapshot()==checkpoint and app.local_panel=="","failure notice blocks underlying commands")
		else: check(not label.text.contains("游戏失败"),"ordinary notice has no failure message")
		for stat in ["hunger","hydration","hp"]:
			check(label.text.contains("−%d（剩余 %d）" % [maxi(0,int(before[stat])-int(after[stat])),int(after[stat])]),"actual loss and balance: "+stat)
		check(label.get_theme_font_size("font_size")>=30,"mobile readable font")
		check(overlay.find_children("*","Button",true,false).is_empty(),"no close button")
		var panel=overlay.find_child("DepartureNoticePanel",true,false)
		check(root.get_visible_rect().encloses(panel.get_global_rect()),"notice fits mobile viewport")
		check(panel.get_global_rect().get_center().distance_to(root.get_visible_rect().get_center())<2,"notice centered on mobile")
		if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/departure-notice-%s.png" % ("fatal" if fatal else "normal"))
		var style=panel.get_theme_stylebox("panel")
		check(style.bg_color.a>0 and style.bg_color.a<1 and style.border_width_left==0,"translucent solid borderless panel")
		var saved: Dictionary=app.session.snapshot()
		var escape:=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true; root.push_input(escape,true)
		await settle(); check(is_instance_valid(overlay),"Escape does not dismiss notice")
		if scenario=="dead_auto":
			await create_timer(3.0).timeout
		elif scenario=="mad_touch":
			var touch:=InputEventScreenTouch.new(); touch.pressed=true; touch.position=Vector2(20,20)
			root.push_input(touch,true); await settle()
		else:
			var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=Vector2(5,5)
			root.push_input(click,true); await settle()
		check(not is_instance_valid(notice()),"notice ends by timeout/click/touch: "+scenario)
		await settle()
		if fatal:
			check(app.current_page.get_script().resource_path=="res://pages/settlement_page.gd","formal settlement opens only after notice: "+scenario)
		else:
			app._show_departure_notice(before,after); await settle()
			await create_timer(3.0).timeout
			check(not is_instance_valid(notice()),"ordinary notice automatically disappears")
		check(app.session.snapshot()==saved,"notice does not alter state or RNG")
	for death_source in ["node","battle"]:
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
		if death_source=="node":
			app.session.state.node=app.catalog.entry("nodes","crabBattle")
			app.session.state.node.visit_id="notice-node-death"
			app.session.state.phase="story"; app.session.state.story_step="choice"
			app.session.state.player.hp=4
			app.handle_command("leave_encounter")
		else:
			app.session.state.node=app.catalog.entry("nodes","battle")
			app.session.state.node.visit_id="notice-battle-death"
			app.session.state.phase="battle"; app.session.state.player.hp=1
			app.session.state.battle={"id":app.session.state.node.monster,"hp":10,"turn":1,"ap":0,"entry_hp":40,"poison_until":0,"fear_until":0}
			app.handle_command("resume")
		await settle()
		var death_notice=notice()
		check(is_instance_valid(death_notice),"%s death shows notice before settlement" % death_source)
		if is_instance_valid(death_notice):
			var death_text=death_notice.find_child("DepartureNoticeText",true,false).text
			check(death_text.contains("游戏失败") and death_text.contains("生命归零"),"%s death notice explains failure" % death_source)
			check(app.current_page.get_script().resource_path!="res://pages/settlement_page.gd","%s settlement waits for notice" % death_source)
			var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=Vector2(5,5)
			root.push_input(click,true); await settle()
			check(app.current_page.get_script().resource_path=="res://pages/settlement_page.gd","%s settlement opens after notice" % death_source)
	app.queue_free(); app=null
	await settle()
	print("DEPARTURE NOTICE: "+("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
