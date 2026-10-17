extends SceneTree
var app
var failures := 0
func _init():
	call_deferred("run"); call_deferred("watchdog")
func watchdog():
	await create_timer(40).timeout
	printerr("NAUTICAL HUD: timed out"); quit(2)
func check(ok: bool, why: String):
	if not ok: failures += 1; printerr("FAIL: "+why)
func settle():
	for i in range(4): await process_frame
func click_control(button: Button):
	var point=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new(); event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		root.push_input(event,true); await process_frame
	await settle()
func run():
	root.size=Vector2i(1600,900)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
	var before=app.session.snapshot()
	check(app.find_child("VoyageNavigationBar",true,false)!=null,"unified navigation frame exists")
	check(app.find_child("VoyageCompass",true,false)!=null,"independent compass asset exists")
	var ap_widget=app.find_child("SurgeActionPointHUD",true,false)
	check(ap_widget.DESIGN_SIZE==Vector2(1814,454),"AP uses supplied artwork crop aspect")
	check(is_equal_approx(ap_widget.position.x,0.0),"AP art starts at far left of hand header")
	check(app.find_child("hand_fan",true,false).border.get("paper_opacity")==0.7,"paper fill is 70 percent opaque")
	var initial_stat=app.find_child("SurgeStatusHUD",true,false)
	check(initial_stat.has_method("stat_layout"),"status layout supports fixed bars and compact numbers")
	if initial_stat.has_method("stat_layout"):
		var normal_size=initial_stat.size
		for width in [600.0,800.0,1100.0]:
			initial_stat.size=Vector2(width,56)
			var cells=initial_stat.stat_layout()
			for cell in cells:
				check(cell.track.size.x==(0.0 if width==600 else 72.0),"fixed bar width or hidden in compact mode")
				check(cell.number.end.x<=width,"numbers remain inside status area")
		initial_stat.size=normal_size
	check(ap_widget.art_catalog.texture("texture.hud.nautical.action-points").get_size()==Vector2(1814,454),"AP atlas strips transparent margins without deforming badge")
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(1920,820)]:
		root.size=resolution; await settle()
		for scale_value in [1.0,1.25]:
			app.display_settings.free_aspect=resolution==Vector2i(1920,820)
			app.display_settings.ui_scale=scale_value; app.apply_display_settings(false); await settle()
			var stat=app.find_child("SurgeStatusHUD",true,false)
			check(stat.health==app.session.state.player.hp and stat.water==app.session.state.player.hydration,"real survival values bound")
			var heading=app.find_child("VoyageHeading",true,false)
			check(not heading.get_global_rect().intersects(stat.get_global_rect()),"voyage title and survival values do not overlap")
			var operation=app.find_child("VoyageOperationFrame",true,false)
			check(operation.get_global_rect().end.y<app.find_child("VoyageHandTopBar",true,false).global_position.y,"operation frame clears hand top bar")
			for key in ["SurgeStatusHUD","VoyageHandTopBar","VoyageHandTray","SalvageEntry","CraftEntry"]:
				var control=app.find_child(key,true,false)
				check(app.get_global_rect().grow(2).encloses(control.get_global_rect()),"viewport contains "+key)
			await RenderingServer.frame_post_draw
			var rendered=root.get_texture().get_image()
			var pixel=root.get_final_transform()*(stat.global_position+Vector2(25,28))
			var icon_pixel=rendered.get_pixelv(Vector2i(pixel))
			check(not (icon_pixel.r>.98 and icon_pixel.g>.98 and icon_pixel.b>.98),"medallion texture survives until GPU draw")
			var fan=app.find_child("hand_fan",true,false)
			check(absf(fan.card_height/fan.border.size.y-.97)<.001,"card height occupies 97 percent of body excluding header")
			for tile in fan.tiles:
				check(tile.find_child("CardGroundShadow",true,false)!=null,"cards have a contact shadow")
				var quantity=tile.find_child("StackQuantity",true,false)
				if quantity!=null:
					check(not quantity.has_theme_stylebox_override("normal"),"quantity has no badge box")
					check(quantity.get_theme_constant("outline_size")>0,"quantity uses outlined text")
			for tile in fan.tiles: check(tile.z_index>fan.border.z_index,"cards render above opaque parchment")
			rendered.save_png("res://evidence/nautical-hud-%dx%d-%d.png" % [resolution.x,resolution.y,roundi(scale_value*100)])
	check(app.session.snapshot()==before,"resizing and drawing preserve rules and random state")
	var header_heights=[]
	for ui_scale in [1.0,1.25]:
		var reference_height=0.0
		for width in [1280,1600,1920]:
			root.size=Vector2i(width,720); app.display_settings.free_aspect=true
			app.display_settings.ui_scale=ui_scale; app.apply_display_settings(false); await settle()
			var header=app.find_child("VoyageHandTopBar",true,false)
			var physical_rect=root.get_final_transform()*header.get_global_rect()
			if reference_height==0.0: reference_height=physical_rect.size.y
			check(absf(physical_rect.size.y-reference_height)<.1,"same window height preserves hand header thickness at width %d" % width)
			header_heights.append(physical_rect.size.y)
		check(reference_height>0,"hand header has a positive fixed height")
	check(absf(header_heights[3]/header_heights[0]-1.25)<.01,"hand header grows vertically only with overall UI scale")
	print("HAND HEADER HEIGHTS (720px window; widths 1280/1600/1920): "+str(header_heights))
	root.size=Vector2i(1600,900); app.display_settings.ui_scale=1.0; app.apply_display_settings(false); await settle()
	var night_preview=app.find_child("SurgeActionPointHUD",true,false)
	night_preview.label_text="今晚机会"; night_preview.set_ap(2,5); await settle()
	check(night_preview.current_ap==2 and night_preview.max_ap==5,"night label supports variable budget tokens")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/nautical-ap-night-preview.png")
	check(app.session.snapshot()==before,"night display fixture leaves rules untouched")
	night_preview.label_text="行动点"; night_preview.set_ap(app.session.state.ap,app.session.state.player.base_ap)
	var settings=app.find_child("VoyageMenu",true,false).get_child(1)
	await click_control(settings)
	check(app.local_panel=="settings","settings icon accepts native mouse input")
	app.handle_ui("local_panel",""); await settle()
	await click_control(app.find_child("CraftEntry",true,false))
	check(app.session.panel=="craft","round decoration preserves craft button input")
	app.handle_command("close"); await settle()
	var ap_before=int(app.session.state.ap)
	for i in range(ap_before): await click_control(app.find_child("SalvageEntry",true,false))
	check(app.session.state.ap==0,"long button dispatches real paid salvage actions")
	var exhausted=app.session.snapshot()
	var salvage=app.find_child("SalvageEntry",true,false)
	check(salvage.disabled,"exhausted salvage keeps native disabled state")
	await click_control(salvage)
	check(app.session.snapshot()==exhausted,"disabled art does not bypass dispatch legality")
	app.queue_free(); await process_frame
	print("NAUTICAL HUD: "+("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
