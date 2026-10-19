extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures += 1; printerr("FAIL: "+why)
func run():
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame; await process_frame
	for mobile in [true,false]:
		for mode in ["spread","raise"]:
			var fan=load("res://presentation/hand_fan.gd").new(); root.add_child(fan)
			fan.size=Vector2(500,238)
			var entries := []
			for i in range(6): entries.append({"uid":str(i),"id":"water","definition":app.session.catalog.entry("cards","water"),"temporary":false})
			var layout=load("res://presentation/hand_layout.gd").new(); layout.hover_mode=mode
			fan.create(app.assets,entries,{"mobile":mobile,"phase":"preparation","can_base":true,"hand":entries,"hand_layout":layout})
			fan.arrange(); fan.set_process(false)
			var rest: Array=fan.target_positions.duplicate()
			var motion := InputEventMouseMotion.new(); motion.position=fan.tiles[0].position+Vector2(10,80)
			fan._gui_input(motion); fan._process(.4)
			check(fan.tip.visible==not mobile,"hover tooltip follows platform "+str(mobile)+mode)
			if mobile:
				check(fan.hovered==-1 and fan.target_positions==rest,"mobile mouse motion leaves cards at rest "+mode)
				fan._begin_press(0,motion.position); fan.cancel_gesture(); fan._process(.4)
				check(fan.target_positions==rest and not fan.tip.visible,"touch release leaves no hover expansion or delayed tooltip "+mode)
				var saved: Dictionary=fan.capture_visual(); saved.hover_uid=fan.cards[0].uid; saved.tip_visible=true; saved.dwell=.4
				fan.restore_visual(saved)
				check(fan.hovered==-1 and not fan.tip.visible,"mobile ignores restored desktop hover "+mode)
				fan.move_card_group(0,1); fan._process(.4)
				check(fan.hovered==-1 and not fan.tip.visible,"mobile reorder does not leave hover focus "+mode)
				fan.set_selected_uids([fan.cards[0].uid])
				check(fan.tiles[0].modulate!=Color.WHITE,"mobile selection highlight remains")
			else:
				check(fan.hovered==0 and fan.target_positions[0].y<rest[0].y,"desktop keeps hover lift "+mode)
			fan.free()
		var menu=load("res://presentation/title_menu.gd").new(); root.add_child(menu)
		menu.create({"mobile":mobile,"active":false},false)
		menu.buttons[2].mouse_entered.emit(); await process_frame
		check((menu.selected==0) if mobile else (menu.selected==2),"title hover selection follows platform "+str(mobile))
		menu.free()
		app.display_settings.mobile=mobile; app.settings_tab="game"; app.handle_ui("local_panel","settings")
		await process_frame; await process_frame
		check((app.find_child("HandHoverMode",true,false)==null)==mobile,"hover preference only appears on desktop")
		var clicks := []
		var button=preload("res://presentation/widgets.gd").button(app,"动态按钮",func(): clicks.append(true),false,"悬停说明")
		await process_frame; await process_frame
		check(button.tooltip_text.is_empty()==mobile,"dynamic controls suppress tooltips only on mobile")
		check((button.get_theme_stylebox("hover")==button.get_theme_stylebox("normal")) if mobile else not button.tooltip_text.is_empty(),"mobile native hover style matches normal")
		button.pressed.emit()
		check(clicks==[true],"mobile and desktop buttons remain clickable")
		button.free()
	app.free()
	print("MOBILE HOVER: "+("PASS" if failures==0 else "FAIL %d" % failures)); quit(1 if failures else 0)
