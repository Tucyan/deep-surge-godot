extends SceneTree
var failures := 0
var app
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func run():
	root.size=Vector2i(1600,900)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	for id in ["wood","wood","wood","wood","plastic","plastic","plastic","cloth","cloth","iron","iron","rope"]: app.session.give(id,1,false,"grid-fixture")
	app.render()
	await process_frame; await process_frame
	var frame=app.find_child("VoyageOperationFrame",true,false)
	check(frame.size.y>=390,"right operation panel fills reference height")
	var craft=app.find_child("CraftEntry",true,false)
	var badge=app.find_child("HandCapacityBadge",true,false)
	check(badge.get_child(0).text=="%d/%d" % [app.session.view().capacity,app.session.state.player.limit],"badge shows only capacity")
	check(absf(badge.get_global_rect().get_center().x-app.find_child("VoyageHandTray",true,false).get_global_rect().get_center().x)<1,"capacity badge horizontally centered on tray")
	check(craft!=null,"fixed craft entry in hand area")
	if craft!=null: check(craft.get_global_rect().get_center().x>1300 and craft.get_global_rect().get_center().y>700,"craft entry at lower right")
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("res://evidence/navigation-actions-1600.png")
	var err: Error = root.get_texture().get_image().save_png(path)
	if err != OK: printerr("Failed to save image: ", err)
	app.handle_command("panel",{"id":"craft"})
	await process_frame; await process_frame
	var grid=app.find_child("RecipeGrid",true,false)
	check(grid!=null,"recipe grid exists")
	if grid!=null:
		check(grid.columns==4 and grid.get_child_count()==8,"eight recipes in four columns")
		check(grid.get_child(5).find_child("CraftRecipeButton",true,false).disabled,"locked technology recipe disabled")
		for resolution in [Vector2i(1600,900),Vector2i(1280,720)]:
			root.size=resolution; await process_frame; await process_frame
			check(app.get_global_rect().encloses(grid.get_global_rect()),"grid within viewport")
			if "--capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://evidence/craft-grid-%d.png" % resolution.x)
		var button=grid.get_child(0).find_child("CraftRecipeButton",true,false)
		var ap: int=app.session.state.ap
		var pos: Vector2=root.get_final_transform()*button.get_global_rect().get_center()
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new(); event.position=pos; event.global_position=pos; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
			Input.parse_input_event(event); await process_frame
		check(app.session.state.ap==ap-1 and app.session.I.count(app.session.state,"lamp")==1,"actual recipe button crafts and spends AP")
	# Exercise a real second page without adding production recipes.
	app.catalog._tables.recipes.extra=app.catalog.entry("recipes","lamp")
	var before: Dictionary=app.session.snapshot()
	app.handle_ui("list_page","1")
	await process_frame; await process_frame
	grid=app.find_child("RecipeGrid",true,false)
	check(grid!=null and grid.get_child_count()==5 and grid.get_child(4).get_meta("recipe_id")=="extra","extra recipe is on second page")
	check(app.session.snapshot()==before,"pagination changes no state or RNG")
	app.handle_ui("list_page","0")
	await process_frame; await process_frame
	check(app.find_child("RecipeGrid",true,false).get_child_count()==8,"return to first eight recipes")
	app.queue_free(); await process_frame
	print("CRAFT GRID: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
