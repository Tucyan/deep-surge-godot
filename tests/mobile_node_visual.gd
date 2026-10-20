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
		check(column.get_global_rect().end.y>=app.size.y-40.0,"column reaches the bottom edge: "+name+" "+id)
		rects.append(column.get_global_rect())
	check(rects[0].size.y>400.0,"event columns use the freed card space: "+name+" "+str(rects[0].size.y))
	# The illustration stays on phones and since 2026-10-20 owns the larger share:
	# the prose column no longer absorbs every pixel the options leave behind.
	check(rects[0].size.x>=200.0,"illustration keeps a usable width: "+name+" "+str(rects[0].size.x))
	check(rects[1].size.x>=340.0,"prose keeps a usable width: "+name+" "+str(rects[1].size.x))
	check(rects[0].size.x>=body.size.x*0.32,"illustration takes the larger share: "+name+" %d/%d" % [rects[0].size.x,body.size.x])
	check(rects[1].size.x<=body.size.x*0.38,"prose column stays within its share: "+name+" %d/%d" % [rects[1].size.x,body.size.x])
	var illustration=app.find_child("NodeEventIllustration",true,false)
	check(illustration!=null and illustration.texture!=null and illustration.size.x>=180.0,"illustration renders art: "+name)
	check(not rects[0].intersects(rects[1]) and not rects[1].intersects(rects[2]),"event columns do not overlap: "+name)
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
