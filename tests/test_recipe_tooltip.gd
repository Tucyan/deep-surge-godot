extends SceneTree
var app
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)
func settle() -> void:
	for i in range(5): await process_frame
func click(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	point = root.get_final_transform() * point
	var move := InputEventMouseMotion.new(); move.position = point; move.global_position = point
	Input.parse_input_event(move)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point; event.global_position = point
		event.button_index = button; event.pressed = down
		Input.parse_input_event(event); await process_frame
	await settle()
func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://flow_app.gd").new(); app.persistence = false
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(app); await settle()
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":22})
	app.world_view.motion = false
	app.session.give("wood", 6, false, "recipe-tooltip-fixture")
	app.handle_command("panel", {"id":"craft"}); await settle()
	var before: Dictionary = app.session.snapshot()
	for config in [Vector3(1600,900,1), Vector3(1280,720,1.25)]:
		root.size = Vector2i(config.x, config.y)
		app.display_settings.free_aspect = true; app.display_settings.ui_scale = config.z
		app.apply_display_settings(false); await settle()
		var grid = app.find_child("RecipeGrid", true, false)
		for tile in grid.get_children():
			if not tile.has_meta("recipe_id"): continue
			var icon = tile.find_child("RecipeIcon", true, false)
			check(icon != null, "recipe displays clickable output icon")
			if icon == null: continue
			check(icon.get_child(0).texture != null, "recipe icon has registered texture")
			check(not app.assets.show_label("card." + app.catalog.entry("recipes",tile.get_meta("recipe_id")).output), "recipe uses real art instead of placeholder")
			var recipe: Dictionary = app.catalog.entry("recipes", tile.get_meta("recipe_id"))
			var description: String = app.catalog.entry("cards", recipe.output).description
			for label in tile.find_children("*", "Label", true, false):
				check(label.text != description, "description is hidden on recipe tile")
			var point: Vector2 = icon.get_global_rect().get_center()
			await click(point)
			var tooltip = app.find_child("RecipeTooltip", true, false)
			check(tooltip != null and tooltip.visible, "click opens description even for unavailable recipes")
			if tooltip == null: continue
			check(tooltip.find_child("RecipeDescription",true,false).text == description, "tooltip shows correct description")
			check(root.get_visible_rect().encloses(tooltip.get_global_rect()), "tooltip stays within viewport")
			if config.x == 1600 and tile == grid.get_child(0):
				check(tooltip.position.x > point.x and tooltip.position.y > point.y, "prefers lower right of click")
				check(tooltip.position.distance_to(point + Vector2(12,12)) < 1, "popup anchored to actual click")
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://evidence/recipe-tooltip-open.png")
			# Clicking a craft button while the tooltip is open only dismisses it.
			await click(tile.find_child("CraftRecipeButton",true,false).get_global_rect().get_center())
			check(not is_instance_valid(tooltip) or not tooltip.visible, "next click dismisses tooltip")
			check(app.session.snapshot() == before, "tooltip click does not craft or change RNG")
		var first = grid.get_child(0).find_child("RecipeIcon",true,false)
		if first != null:
			var second = grid.get_child(1).find_child("RecipeIcon",true,false)
			await click(first.get_global_rect().get_center())
			await click(second.get_global_rect().get_center())
			var switched = app.find_child("RecipeTooltip",true,false)
			check(switched != null, "clicking another icon switches tooltip without another click")
			if switched != null:
				check(switched.find_child("RecipeDescription",true,false).text == app.catalog.entry("cards","filter").description, "switched tooltip describes newly clicked equipment")
				check(root.get_visible_rect().encloses(switched.get_global_rect()), "switched tooltip stays within viewport")
			await click(second.get_global_rect().get_center())
			check(app.find_child("RecipeTooltip",true,false) == null, "left click on same icon closes tooltip")
			check(app.session.snapshot() == before, "switching descriptions does not mutate session")
			await click(first.get_global_rect().get_center())
			await click(first.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
			check(app.find_child("RecipeTooltip",true,false) == null, "right click on same icon dismisses")
			var page = grid.get_parent()
			var bounds := Rect2(0, 0, 800, 600)
			for sample in [Vector2(100,100),Vector2(790,100),Vector2(100,590),Vector2(790,590)]:
				var placed: Vector2 = page.recipe_tooltip_position(sample, Vector2(240,120), bounds)
				check(bounds.encloses(Rect2(placed, Vector2(240,120))), "all corner fallbacks stay on screen")
			check(page.recipe_tooltip_position(Vector2(790,590), Vector2(240,120), bounds).x < 790, "bottom-right click falls back left")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/recipe-icons-%d.png" % int(config.x))
	app.handle_ui("list_page", "1"); await settle()
	var second_grid = app.find_child("RecipeGrid",true,false)
	for tile in second_grid.get_children():
		if not tile.has_meta("recipe_id"): continue
		var icon = tile.find_child("RecipeIcon",true,false)
		check(icon != null, "second page displays output icon")
		if icon == null: continue
		var output: String = app.catalog.entry("recipes",tile.get_meta("recipe_id")).output
		check(not app.assets.show_label("card." + output), "second page uses real icons")
		await click(icon.get_global_rect().get_center())
		check(app.find_child("RecipeTooltip",true,false) != null, "second page tooltip opens")
		await click(Vector2(8,8))
		check(app.find_child("RecipeTooltip",true,false) == null, "clicking empty area dismisses")
	check(app.session.snapshot() == before, "both recipe pages preserve session and random stream")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/recipe-icons-page-2.png")
	app.queue_free(); await process_frame
	print("RECIPE TOOLTIP: " + ("PASS" if failures == 0 else "FAIL")); quit(failures)
