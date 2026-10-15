extends SceneTree
var failures := 0
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init(): call_deferred("run")
func run():
	var catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	for mode in ["challenge","story"]:
		for chosen in [["wood"],["wood","wood","iron","plastic","rope"],[]]:
			var s=load("res://core/game_session.gd").new(catalog)
			check(s.dispatch("new",{"mode":mode,"origin":"strong","seed":22,"starting_resources":chosen}),"valid starting choice")
			check(s.state.hand.size()==(7 if chosen.is_empty() else chosen.size()),"chosen count or seven random")
			if not chosen.is_empty(): check(s.state.hand.map(func(c):return c.id)==chosen,"exact chosen resources, no fill")
			var copy=load("res://core/game_session.gd").new(catalog)
			copy.dispatch("new",{"mode":mode,"origin":"strong","seed":22,"starting_resources":chosen})
			check(s.state.hand==copy.state.hand and s.state.rng==copy.state.rng,"seed deterministic")
	for invalid in [["wood","wood","wood"],["wood","wood","iron","iron","rope","cloth"],["water"],"wood",null]:
		var s=load("res://core/game_session.gd").new(catalog); var before: Dictionary=s.snapshot()
		check(not s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22,"starting_resources":invalid}),"reject invalid choice")
		check(s.snapshot()==before,"invalid selection rolls back")
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.size=Vector2i(1600,900); root.add_child(app); await process_frame
	app.handle_ui("setup","challenge"); await process_frame
	var before: Dictionary=app.session.snapshot()
	button(app,"开始航程").pressed.emit(); await process_frame; await process_frame
	check(button(app,"随心所欲")!=null and app.session.snapshot()==before,"start enters picker without starting run")
	var page=app.current_page
	page.change_resource("wood",1); page.change_resource("wood",1); page.change_resource("wood",1)
	check(page.resource_counts.get("wood",0)==2,"UI caps each type at two")
	page.change_resource("iron",1); page.change_resource("iron",1); page.change_resource("cloth",1); page.change_resource("rope",1)
	check(page.selected_resources().size()==5,"UI caps total at five")
	await process_frame; await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://evidence/starting-resources-1600.png")
	root.size=Vector2i(1280,720); await process_frame; await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://evidence/starting-resources-1280.png")
	button(app,"正式开始").pressed.emit(); await process_frame
	check(app.session.phase()=="navigation" and app.session.state.hand.size()==5,"confirm chosen hand starts navigation")
	app.handle_command("abandon"); app.handle_command("home"); app.handle_ui("setup","challenge"); await process_frame
	button(app,"开始航程").pressed.emit(); await process_frame
	button(app,"随心所欲").pressed.emit(); await process_frame
	check(app.session.phase()=="navigation" and app.session.state.hand.size()==7,"zero-choice UI starts with seven random resources")
	app.queue_free(); await process_frame
	print("STARTING RESOURCES: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
func button(node: Node, text: String):
	if node is Button and node.text==text: return node
	for child in node.get_children():
		var found=button(child,text)
		if found!=null: return found
	return null
