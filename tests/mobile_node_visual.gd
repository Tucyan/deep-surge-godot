extends SceneTree
var app
var failures := 0
var checks := 0
var cases := 0
func _init(): call_deferred("run"); call_deferred("watchdog")
func watchdog():
	await create_timer(45).timeout
	printerr("MOBILE NODE AUDIT: timed out"); quit(2)
func check(ok: bool, why: String):
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle():
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String):
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://evidence/mobile-node-"+name+".png")==OK,"save "+name)
func event_fixture(node: Dictionary, step: String):
	app.session.state.node=node.duplicate(true); app.session.state.node.visit_id="mobile-node-audit"
	app.session.Encounter.arrived(app.session)
	app.session.state.phase="story"; app.session.state.story_step=step; app.session.panel="story"
	app.session.state.result_text="已获得节点奖励。可以结束节点，继续使用本轮剩余行动点。"
	app.render(); await settle()
func inspect_event(name: String):
	cases+=1
	var body=app.find_child("NodeEventBodyHost",true,false)
	var header=app.find_child("VoyageHandTopBar",true,false)
	check(body!=null and body.size.y>0,"event host has space: "+name)
	# The event page now stretches to the bottom edge and the hand strip hides.
	check(not header.is_visible_in_tree(),"hand header steps aside: "+name)
	var rects: Array=[]
	for id in ["NodeEventArt","NodeEventProse","NodeEventOptions"]:
		var column=app.find_child(id,true,false)
		check(column.is_visible_in_tree(),"column visible: "+name+" "+id)
		check(app.get_global_rect().grow(2).encloses(column.get_global_rect()),"column in viewport: "+name+" "+id)
		check(body.get_global_rect().grow(2).encloses(column.get_global_rect()),"column inside event host: "+name+" "+id)
		rects.append(column.get_global_rect())
	# Phone layout since 2026-10-20: the illustration is the panel backdrop and
	# the prose is a small plate inside it, so only the options stay a column.
	check(rects[0].size.y>400.0,"image panel uses the freed card space: "+name+" "+str(rects[0].size.y))
	check(rects[0].end.y>=app.size.y-40.0,"image panel reaches the bottom edge: "+name+" "+str(rects[0].end.y))
	check(rects[0].size.x>=body.size.x*0.60,"image panel owns most of the row: "+name+" %d/%d" % [rects[0].size.x,body.size.x])
	check(rects[2].size.x>=400.0,"options column keeps its width: "+name+" "+str(rects[2].size.x))
	check(not rects[0].intersects(rects[2]),"image panel and options do not overlap: "+name)
	# The prose plate lives inside the image panel, bottom-left, and stays small.
	check(rects[0].grow(-2.0).encloses(rects[1]),"text plate sits inside the image panel: "+name)
	check(rects[1].size.x<=rects[0].size.x*0.70,"text plate keeps the picture visible: "+name+" %d/%d" % [rects[1].size.x,rects[0].size.x])
	check(rects[1].size.y<=rects[0].size.y*0.56,"text plate stays short: "+name+" %d/%d" % [rects[1].size.y,rects[0].size.y])
	check(rects[0].end.y-rects[1].end.y<=60.0,"text plate hugs the panel bottom: "+name+" "+str(rects[0].end.y-rects[1].end.y))
	var illustration=app.find_child("NodeEventIllustration",true,false)
	check(illustration!=null and illustration.texture!=null,"illustration renders art: "+name)
	check(illustration.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"illustration fills the panel as a backdrop: "+name)
	check(illustration.get_global_rect().grow(2).encloses(app.find_child("NodeEventArt",true,false).get_global_rect()),"illustration covers the panel: "+name)
	var headline=app.find_child("NodeEventHeadline",true,false)
	check(headline!=null and headline.is_visible_in_tree(),"event text stays readable on the plate: "+name)
	check(rects[1].grow(2.0).encloses(headline.get_global_rect()),"event text sits on the plate: "+name)
	var page=app.find_child("NodeEventBody",true,false)
	for entry in page.entries:
		check(entry.button.size.y>=44,"option touch height: "+name)
		if entry.selection!=null: check(entry.selection.size.y>=44,"alternative touch height: "+name)
	var prose_scroll=app.find_child("NodeEventProseScroll",true,false)
	var choices_scroll=app.find_child("NodeEventChoicesScroll",true,false)
	check(prose_scroll.size.y>40 and choices_scroll.size.y>40,"scroll regions remain usable: "+name)
	choices_scroll.scroll_vertical=99999
	await settle()
	var buttons: Array=page.options_panel.find_children("*","Button",true,false)
	if not buttons.is_empty(): check(choices_scroll.get_global_rect().grow(2).encloses(buttons.back().get_global_rect()),"last choice reachable by scrolling: "+name)
	choices_scroll.scroll_vertical=0
func run():
	root.size=Vector2i(1680,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.display_settings.mobile=true; app.display_settings.ui_scale=1.25; app.display_settings.free_aspect=true
	app.apply_display_settings(false)
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
	var baseline: Dictionary=app.session.snapshot()
	var nodes: Array=app.session.Encounter.definitions(app.session)
	for resolution in [Vector2i(1680,720),Vector2i(1260,540),Vector2i(2520,1080)]:
		root.size=resolution
		app.session.restore(baseline); app.handle_command("resume"); await settle()
		var suffix="%dx%d" %[resolution.x,resolution.y]
		var frame=app.find_child("VoyageOperationFrame",true,false)
		check(app.get_global_rect().encloses(frame.get_global_rect()),"navigation fits: "+suffix)
		await capture(suffix+"-navigation")
		app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id}); await settle()
		frame=app.find_child("VoyageOperationFrame",true,false)
		check(app.get_global_rect().encloses(frame.get_global_rect()),"preparation fits: "+suffix)
		await capture(suffix+"-preparation")
		var node: Dictionary=app.catalog.entry("nodes","drift")
		for step in ["intro","choice","result"]:
			await event_fixture(node,step); await inspect_event(suffix+" "+step)
			await capture(suffix+"-"+step)
			if step=="choice":
				var page=app.find_child("NodeEventBody",true,false)
				var options: Array=page.entries.filter(func(e):return not e.button.disabled)
				check(not options.is_empty(),"choice fixture has usable option")
				if not options.is_empty():
					var before: Dictionary=app.session.snapshot()
					page.press(options[0]); await settle()
					# Phones drop the header row: 取消选择 lives inside the preselected option.
					check(app.find_child("NodeEventOptionsHeader",true,false)==null,"no header row on phones: "+suffix)
					var cancel=options[0].get("cancel")
					check(cancel!=null and cancel.is_visible_in_tree(),"inline cancel appears on the selected option: "+suffix)
					if cancel!=null:
						check(cancel.size.y>=44,"cancel touch height: "+suffix)
						var button_rect: Rect2=options[0].button.get_global_rect()
						check(button_rect.encloses(cancel.get_global_rect()),"cancel sits inside its option: "+suffix)
						check(cancel.get_global_rect().end.x>button_rect.get_center().x,"cancel hugs the option's right edge: "+suffix)
						check(cancel.get_global_rect().end.x<=button_rect.end.x-24.0,"cancel clears the option frame: "+suffix)
					check(app.session.snapshot()==before,"preselect preserves rules: "+suffix)
					await capture(suffix+"-preselect")
					if cancel!=null: cancel.pressed.emit(); await settle()
					check(page.preselect_key=="","inline cancel clears preselect: "+suffix)
					check(app.session.snapshot()==before,"cancel preserves rules: "+suffix)
		if resolution==Vector2i(1680,720):
			for definition in nodes:
				await event_fixture(definition,"choice"); await inspect_event(str(definition.id)+"/"+str(definition.get("variant_id","")))
				if definition.id in ["trader","battle","camp"]: await capture(suffix+"-"+str(definition.id))
	app.queue_free(); await settle()
	print("MOBILE NODE AUDIT: %d cases / %d checks / %d failures" %[cases,checks,failures]); quit(failures)
