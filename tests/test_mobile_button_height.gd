extends SceneTree
var app
var failures:=0
var audited:=0
var capture:=false
var prefix:="mobile-buttons"
func _init():
	for arg in OS.get_cmdline_user_args():
		if arg=="--capture": capture=true
		if arg.begins_with("--prefix="): prefix=arg.trim_prefix("--prefix=")
	call_deferred("run")
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle():
	for i in range(5): await process_frame
func audit(id: String):
	await settle()
	var buttons: Array=[]
	for button in app.find_children("*","Button",true,false):
		if not button.is_visible_in_tree(): continue
		var art=button.get_node_or_null("SurgeTextButtonArt")
		if art==null or art.is_queued_for_deletion(): continue
		if button.get_theme_stylebox("normal")!=art.content_style: continue
		audited+=1; buttons.append(button)
		check(button.get_global_rect().size.y>=56,"touch text button >=56: "+id+" / "+button.text+" height="+str(button.size.y))
		check(app.get_global_rect().grow(2).encloses(button.get_global_rect()),"button in viewport: "+id+" / "+button.text+" "+str(button.get_global_rect())+" viewport="+str(app.get_global_rect()))
		check(art.content_style.content_margin_top>=14 and art.content_style.content_margin_bottom>=14,"mobile padding: "+id+" / "+button.text)
	for i in range(buttons.size()):
		for j in range(i+1,buttons.size()):
			check(not buttons[i].get_global_rect().grow(-1).intersects(buttons[j].get_global_rect()),"text buttons do not overlap: "+id)
	if capture and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/"+prefix+"-"+id+".png")
func tap(button: Button):
	var point: Vector2=root.get_final_transform()*button.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events();await process_frame
	await RenderingServer.frame_post_draw
func check_button(id: String):
	var button=app.find_child(id,true,false)
	check(button!=null and button.get_global_rect().size.y>=56,"dedicated mobile control >=56: "+id)
func run():
	app=load("res://scenes/main.tscn").instantiate();app.persistence=false;root.add_child(app);await settle()
	for config in [Vector3(1260,540,1.25),Vector3(1680,720,1.25),Vector3(1280,720,1.25),Vector3(1260,540,1)]:
		root.size=Vector2i(config.x,config.y)
		app.display_settings.mobile=true;app.display_settings.ui_scale=config.z;app.display_settings.free_aspect=true
		app.apply_display_settings(false)
		app.session=preload("res://core/game_session.gd").new(app.catalog)
		app.local_panel="";app.ui_state.nav_select=""
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22});await settle()
		var suffix:="%dx%d-%d" % [config.x,config.y,roundi(config.z*100)]
		var op_scroll=app.find_child("MobileOperationScroll",true,false)
		check(op_scroll!=null,"mobile operation has scrolling fallback")
		for button in app.find_children("NavigationOption","Button",true,false):
			check(button.size.y>=56,"navigation button >=56")
			if op_scroll!=null: check(op_scroll.get_global_rect().grow(1).encloses(button.get_global_rect()),"all initial routes visible without scrolling")
		var frame=app.find_child("VoyageOperationFrame",true,false)
		check(app.get_global_rect().encloses(frame.get_global_rect()),"operation frame fits")
		await audit(suffix+"-navigation")
		var option=app.find_children("NavigationOption","Button",true,false)[0]
		var before: Dictionary=app.session.snapshot()
		var picked_id: String=str(option.get_meta("visit_id"))
		var old_layout: int=app.layout.get_instance_id()
		if DisplayServer.get_name()!="headless": await tap(option)
		else: option.pressed.emit()
		await settle();check_button("NavigationDepart")
		check(app.ui_state.get("nav_select","")==picked_id,"route tap selects the intended destination")
		check(app.layout.get_instance_id()==old_layout,"touch selection retains HUD")
		check(app.session.snapshot()==before,"route selection preserves rules")
		await audit(suffix+"-selected")
		app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id});await settle()
		await audit(suffix+"-preparation")
		if config==Vector3(1260,540,1.25):
			app.session.give("lamp",1,false,"mobile-button-fixture")
			app.session.give("filter",1,false,"mobile-button-fixture")
			app.render();await settle()
			var interaction=app.find_child("RaftInteraction",true,false)
			var targets: Array=interaction.policy.targets().filter(func(t):return t.kind=="cell" and t.equipment.is_empty())
			targets.sort_custom(func(a,b):return interaction.surface.screen_point(a).y<interaction.surface.screen_point(b).y)
			var unchanged: Dictionary=app.session.snapshot()
			interaction.select_target(targets[0]);await settle()
			var picker=interaction.popup.find_children("*","OptionButton",true,false)
			check(picker.size()>0,"dynamic popup offers multiple installation options")
			if not picker.is_empty(): check(picker[0].size.y>=56,"dynamic raft picker >=56")
			check(app.session.snapshot()==unchanged,"popup inspection preserves state")
			await audit(suffix+"-raft-popup")
			interaction.select_target({})
		app.handle_command("panel",{"id":"craft"});await audit(suffix+"-craft")
		app.handle_command("close");app.handle_ui("local_panel","settings");await settle()
		check_button("TabGame");check_button("FrameRateLimit")
		await audit(suffix+"-settings")
		app.local_panel="";app.session.panel=""
		app.session.state.node=app.catalog.entry("nodes","battle");app.session.state.node.visit_id="mobile-button-fixture"
		app.session.state.phase="story";app.session.state.story_step="choice";app.session.dispatch("fight")
		app.render();await settle()
		for id in ["BattleSkipTurn","BattleRetreat","CancelBattleSelection","SalvageEntry"]: check_button(id)
		var log=app.find_child("CombatLogPanel",true,false)
		for id in ["BattleSkipTurn","BattleRetreat"]: check(log.get_global_rect().encloses(app.find_child(id,true,false).get_global_rect()),"combat controls stay inside panel")
		var preview=app.find_child("MobilePreviewScroll",true,false)
		check(preview.size.y>=60,"preview keeps two readable lines after taller header button")
		await audit(suffix+"-battle")
		if DisplayServer.get_name()!="headless":
			var battle_before: Dictionary=app.session.snapshot()
			await tap(app.find_child("BattleRetreat",true,false))
			check(app.session.snapshot()==battle_before,"disabled retreat ignores touch")
			var skip=app.find_child("BattleSkipTurn",true,false)
			var presses: Array=[0]
			skip.pressed.connect(func():presses[0]+=1)
			await tap(skip);await settle()
			check(presses[0]==1 and int(app.session.state.battle.turn)==2,"end-turn touch dispatches exactly once")
	app.queue_free();await process_frame
	print("MOBILE BUTTON HEIGHT: %d audited / %d failures" % [audited,failures]);quit(1 if failures else 0)
