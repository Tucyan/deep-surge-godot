extends SceneTree
var failures:=0
var app
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func buttons(node: Node, text: String) -> Array:
	return node.find_children("*","Button",true,false).filter(func(b): return b.text==text and b.is_visible_in_tree())
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	for scale_value in [1.0,1.13,1.25]:
		app.display_settings.ui_scale=scale_value; app.apply_display_settings(false); await settle()
		check(not app.find_child("SurgeStatusHUD",true,false).two_columns,"Four survival stats stay in one row at %s" % scale_value)
		app.handle_ui("local_panel","settings"); await settle()
		var slider=app.find_child("UIScale",true,false)
		check(slider is HSlider,"UI scale is a slider")
		check(buttons(app.layout,"返回首页").filter(func(b):return not b.disabled).size()==1,"Only settings has an active home button")
		if slider is HSlider:
			slider.drag_started.emit(); slider.value=113
			await process_frame
			check(is_instance_valid(slider),"Dragging does not destroy the slider")
			slider.drag_ended.emit(true); await settle()
			check(is_equal_approx(app.display_settings.ui_scale,1.13),"Slider supports intermediate percentages")
		var close=app.find_child("CloseX",true,false)
		check(close!=null,"Settings has top-right X")
		app.handle_ui("local_panel","")
		app.display_settings.ui_scale=scale_value; app.apply_display_settings(false); await settle()
		var before: Dictionary=app.session.snapshot()
		for id in ["craft","raft","help"]:
			if id=="help": app.handle_ui("local_panel",id)
			else: app.handle_command("panel",{"id":id})
			await settle()
			var surface=app.find_child("ModalSurface",true,false)
			check(surface!=null,"Modal surface is identifiable")
			if surface==null: continue
			check(buttons(surface,"返回首页").is_empty() and buttons(surface,"关闭面板").is_empty(),"Modal has no home or old close button: "+id)
			close=surface.find_child("CloseX",true,false)
			check(close!=null and close.text=="X","Modal has X: "+id)
			if close!=null:
				check(close.get_global_rect().get_center().x>surface.get_global_rect().end.x-80 and close.get_global_rect().get_center().y<surface.global_position.y+80,"X sits at top-right: "+id)
			if id=="craft":
				check((surface.get_global_rect().size-app.size).abs().x<1.0 and (surface.get_global_rect().size-app.size).abs().y<1.0,"Craft occupies full screen: scale=%s surface=%s app=%s" % [scale_value,surface.get_global_rect(),app.size])
				var grid=app.find_child("RecipeGrid",true,false)
				check(grid.columns==4 and grid.get_child_count()==8,"Craft always has 8 recipes")
			for b in surface.find_children("*","Button",true,false):
				check(app.get_global_rect().grow(2).encloses(b.get_global_rect()),"Button within screen at %s: %s / %s" % [scale_value,id,b.text])
			if close!=null: close.pressed.emit(); await settle()
			else: app.local_panel=""; app.handle_command("close")
		check(app.session.state==before.state,"Opening/closing layout leaves game state and RNG unchanged")
	app.handle_command("abandon"); await settle()
	check(buttons(app.current_page,"返回首页").is_empty(),"Settlement has only X for exit")
	app.current_page.find_child("CloseX",true,false).pressed.emit(); await settle()
	check(app.session.screen=="home","Settlement X closes to home")
	app.handle_ui("setup","challenge"); await settle()
	check(buttons(app.current_page,"返回模式选择").is_empty(),"Setup has no text return button")
	# Current setup requires a difficulty before entering the resource picker.
	var difficulty=app.current_page.find_child("DifficultyChoice",true,false)
	difficulty.select(1); difficulty.item_selected.emit(1)
	buttons(app.current_page,"选择起手资源")[0].pressed.emit(); await settle()
	check(app.current_page.picking,"Starting-resource stage opens")
	app.current_page.find_child("CloseX",true,false).pressed.emit(); await settle()
	check(not app.current_page.picking,"Resource picker X returns to origin setup")
	app.current_page.find_child("CloseX",true,false).pressed.emit(); await settle()
	check(app.setup_mode=="","Setup X closes to menu")
	app.queue_free(); await process_frame
	print("UI LAYOUT CONTROLS: "+("PASS" if failures==0 else "FAIL")); quit(failures)
