extends SceneTree
var failures := 0
var app
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)
func settle() -> void:
	for i in range(5): await process_frame
func click(control: Control) -> void:
	var position := root.get_final_transform() * control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = position; Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position = position
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; Input.parse_input_event(event)
		await process_frame
	await settle()
func shot(id: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/meta-shop-"+id+".png")
func buy_button() -> Button: return app.current_page.find_child("MetaShopPurchase",true,false)
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate(); app.persistence = false
	root.add_child(app); await settle()
	check(not app.assets.show_label("icon.meta.inheritance") and not app.assets.show_label("icon.meta.coupon"),"Coin and coupon previews resolve to real artwork")
	# In-memory test balance only; all purchases still use the real dispatch path.
	app.session.profile.points = 40
	app.handle_command("panel",{"id":"meta_shop"}); await settle()
	var grid = app.current_page.find_child("MetaShopGrid",true,false)
	check(grid != null,"Shop has preview grid")
	if grid == null:
		app.queue_free(); await settle(); quit(1); return
	var before: Dictionary = app.session.snapshot()
	for config in [Vector3(1600,900,1),Vector3(1280,720,1),Vector3(1280,720,1.25),Vector3(1920,820,1.25)]:
		root.size = Vector2i(config.x,config.y); app.display_settings.free_aspect = true
		app.display_settings.ui_scale = config.z; app.apply_display_settings(false); app.render(); await settle()
		grid = app.current_page.find_child("MetaShopGrid",true,false)
		var detail = app.current_page.find_child("MetaShopDetail",true,false)
		var surface = app.layout.find_child("ModalSurface",true,false)
		check(surface.global_position.distance_to(app.global_position)<1 and surface.size.distance_to(app.size)<1,"Shop fills screen")
		check(grid.columns==3 and grid.get_child_count()==6,"Six slots in three columns")
		check(grid.size.x>detail.get_parent().size.x,"Left side is larger")
		for card in grid.get_children():
			var title = card.find_child("EntryTitle",true,false); var cover = card.find_child("Cover",true,false)
			check(title.global_position.y>=cover.get_global_rect().end.y,"Title below preview")
			check(card.get_global_rect().encloses(card.find_child("ProductPrice",true,false).get_global_rect()),"Price fits card")
		for control in app.current_page.find_children("*","Control",true,false):
			if control is Button or control is Label: check(app.get_global_rect().grow(1).encloses(control.get_global_rect()),"Content fits viewport: "+control.name)
		await shot("%dx%d-%d" % [config.x,config.y,roundi(config.z*100)])
		app.handle_ui("category","tech"); await settle()
		var tree = app.current_page.find_child("TechTree",true,false)
		check(tree!=null,"Technology uses a two-tier node tree")
		if tree==null:
			app.queue_free(); await settle(); quit(1); return
		check(tree.find_children("TechNode_*","Button",true,false).size()==6,"Six round technology nodes")
		for control in tree.find_children("*","Control",true,false):
			if control is Button or control is Label: check(app.get_global_rect().grow(1).encloses(control.get_global_rect()),"Tech content fits viewport")
		await shot("tech-%dx%d-%d" % [config.x,config.y,roundi(config.z*100)])
		app.handle_ui("category","meta_shop"); await settle()
		grid=app.current_page.find_child("MetaShopGrid",true,false)
	await click(grid.get_child(1).find_child("Cover",true,false))
	check(app.ui_state.selected_id=="body","Image selects product")
	grid = app.current_page.find_child("MetaShopGrid",true,false)
	await click(grid.get_child(0).find_child("EntryTitle",true,false))
	check(app.ui_state.selected_id=="raft","Title selects product")
	app.handle_ui("list_page","1"); await settle()
	check(app.current_page.find_child("MetaShopGrid",true,false).get_child(0).get_meta("entry_id")=="bigBox","Next page shows remaining products")
	check(app.current_page.find_children("*blessing*","",true,false).is_empty(),"Unopened blessing is excluded")
	app.handle_ui("category","tech"); app.handle_ui("selected_id","spear"); await settle()
	check(buy_button().disabled and buy_button().tooltip_text.contains("2"),"Tier-two gate visibly blocks purchase")
	check(app.session.snapshot()==before,"Browsing preserves full session and RNG")
	app.handle_ui("selected_id","knowledge"); await settle()
	check(not buy_button().disabled,"Affordable starting tech is purchasable")
	await click(buy_button())
	check("knowledge" in app.session.profile.tech and app.session.profile.points==37,"Real tech command spends exact price")
	check(buy_button().disabled,"Unlocked tech cannot be bought again")
	await click(app.current_page.find_child("TechNode_endurance",true,false))
	await click(buy_button())
	check(app.session.profile.points==33,"Second first-tier node has its own price")
	await shot("tech-tier-two-unlocked")
	await click(app.current_page.find_child("TechNode_spear",true,false))
	check(not buy_button().disabled,"Tier-two node unlocks after two first-tier purchases")
	await click(buy_button())
	check("spear" in app.session.profile.tech and app.session.profile.points==24,"Second-tier exact price")
	await shot("tech-lit")
	app.handle_ui("category","meta_shop"); app.handle_ui("selected_id","raft"); await settle()
	await click(buy_button())
	check(app.session.profile.purchases.get("raft",0)==1 and app.session.profile.points==16,"Real purchase command spends exact price")
	check(buy_button().disabled,"Purchase limit disables repeat purchase")
	app.handle_ui("selected_id","body"); await settle(); await click(buy_button())
	check(app.session.profile.purchases.get("body",0)==1 and not buy_button().disabled,"Multi-purchase growth remains available")
	await shot("purchased")
	app.handle_command("close"); app.session.profile.points=0
	app.handle_command("panel",{"id":"meta_shop"}); app.handle_ui("selected_id","body"); await settle()
	check(buy_button().disabled and buy_button().tooltip_text.contains("不足"),"Insufficient points blocks purchase")
	app.handle_command("close"); app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("home"); app.handle_command("panel",{"id":"meta_shop"}); await settle()
	app.handle_ui("selected_id","body"); await settle()
	check(buy_button().disabled and buy_button().tooltip_text.contains("航程"),"Active run blocks purchases")
	await shot("active-run")
	await click(app.layout.find_child("CloseX",true,false)); check(app.session.panel=="","X closes shop")
	app.queue_free(); await settle()
	print("meta_shop GPU: %d failures" % failures); quit(1 if failures else 0)
