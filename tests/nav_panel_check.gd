extends SceneTree
## Verifies the right-hand operation frame keeps one fixed size while the
## navigation panel switches between "pick a destination" and "departed" states.
var app
var failures := 0

func _init(): call_deferred("run")
func settle():
	await process_frame; await process_frame
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+text)
	else: print("ok: "+text)
func frame_of() -> Control:
	return app.find_child("VoyageOperationFrame", true, false)
func actions() -> Node:
	return app.find_child("VoyageOperationActions", true, false)
func texts(node: Node) -> Array:
	var result: Array = []
	if node is Button: result.append(node.text)
	for child in node.get_children(): result.append_array(texts(child))
	return result
func capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/"+id+".png")

func run() -> void:
	for viewport in [Vector2i(1600,900), Vector2i(1280,720)]:
		root.size = viewport
		if is_instance_valid(app): app.queue_free(); await process_frame
		app = load("res://scenes/main.tscn").instantiate()
		app.persistence = false
		root.add_child(app)
		await settle()
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
		await settle()
		var rect_before: Rect2 = frame_of().get_global_rect()
		var min_before: Vector2 = frame_of().get_child(0).get_combined_minimum_size()
		print("measure %dx%d nav-unselected frame=%s content_min=%s" % [viewport.x,viewport.y,str(rect_before.size),str(min_before)])
		var option_buttons: Array = []
		for button in actions().find_children("*","Button",true,false):
			if button.name == "NavigationOption": option_buttons.append(button)
		check(option_buttons.size() == app.session.state.candidates.size(),"%dx%d 每个候选一个选择按钮" % [viewport.x,viewport.y])
		check(not texts(actions()).any(func(t): return str(t).begins_with("出发")),"%dx%d 未选择时没有出发按钮" % [viewport.x,viewport.y])
		var first: Dictionary = app.session.view().candidates[0]
		check(option_buttons.is_empty() or option_buttons[0].text == str(first.name),"%dx%d 候选按钮只显示名称" % [viewport.x,viewport.y])
		await capture("nav-step1-%d" % viewport.x)
		var picked: Button = null
		for button in option_buttons:
			if str(button.get_meta("visit_id","")) == str(first.visit_id): picked = button
		check(picked != null,"%dx%d 可选中首个目的地" % [viewport.x,viewport.y])
		if picked != null: picked.pressed.emit()
		await settle()
		var rect_after: Rect2 = frame_of().get_global_rect()
		print("measure %dx%d nav-selected frame=%s content_min=%s" % [viewport.x,viewport.y,str(rect_after.size),str(frame_of().get_child(0).get_combined_minimum_size())])
		check(rect_before.size.is_equal_approx(rect_after.size),"%dx%d 面板尺寸不随内容变化" % [viewport.x,viewport.y])
		var title = app.find_child("NavigationDestinationTitle", true, false)
		var detail = app.find_child("NavigationDestinationDetail", true, false)
		check(title != null and title.text == str(first.name),"%dx%d 顶部显示目的地标题" % [viewport.x,viewport.y])
		check(detail != null and detail.text == str(first.get("description","")),"%dx%d 顶部显示详细说明" % [viewport.x,viewport.y])
		check(texts(actions()).count("出发") == 1,"%dx%d 只有一个出发按钮" % [viewport.x,viewport.y])
		await capture("nav-step2-%d" % viewport.x)
		# Confirming in the same row really departs.
		app.handle_command("voyage",{"id":first.visit_id})
		await settle()
		check(app.session.phase() == "preparation","%dx%d 点击出发后进入准备阶段" % [viewport.x,viewport.y])
		var rect_next: Rect2 = frame_of().get_global_rect()
		print("measure %dx%d preparation frame=%s content_min=%s" % [viewport.x,viewport.y,str(rect_next.size),str(frame_of().get_child(0).get_combined_minimum_size())])
		check(rect_next.size.is_equal_approx(rect_before.size),"%dx%d 换阶段后面板尺寸不变" % [viewport.x,viewport.y])
		check(str(app.ui_state.get("nav_select","")) == "","%dx%d 出发后清除选择" % [viewport.x,viewport.y])
	print("NAV PANEL: %s" % ("PASS" if failures == 0 else "FAIL"))
	app.queue_free()
	quit(0 if failures == 0 else 1)
