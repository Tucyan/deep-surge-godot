extends SceneTree
## Node event three-column layout and the select -> confirm option flow.
## Pure UI checks; rules commands stay the same, so no fixture data is written.
var app
var failures := 0

func _init() -> void: call_deferred("run")

func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+why)

func settle() -> void:
	await process_frame; await process_frame

func shot(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/node-event-ui-"+id+".png")

func page() -> Control: return app.layout.find_child("NodeEventBody", true, false)

func node_of(name: String) -> Control:
	var found: Node = app.layout.find_child(name, true, false)
	return found as Control

func rect_of(name: String) -> Rect2:
	var node := node_of(name)
	return node.get_global_rect() if node != null else Rect2()

func click(button: Button) -> void:
	var point: Vector2 = root.get_final_transform() * button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = point
		Input.parse_input_event(event)
		await process_frame
	await settle()

func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://scenes/main.tscn").instantiate(); app.persistence = false
	root.add_child(app); await settle()
	app.handle_command("new", {"mode":"challenge","origin":"strong","seed":22}); await settle()
	app.handle_command("voyage", {"id":app.session.state.candidates[0].visit_id}); await settle()
	app.handle_command("enter"); await settle()
	check(app.session.phase() == "story", "进入节点后为事件阶段")

	var body := page()
	check(body != null, "事件页存在 NodeEventBody")
	check(node_of("NodeEventArt") != null, "立绘栏存在")
	check(node_of("NodeEventText") != null, "说明栏存在")
	check(node_of("NodeEventChoices") != null, "选项栏存在")
	var art := rect_of("NodeEventArt"); var text := rect_of("NodeEventProse"); var choices := rect_of("NodeEventOptions")
	check(art.end.x <= text.position.x, "立绘栏在说明栏左侧")
	check(text.end.x <= choices.position.x, "说明栏在选项栏左侧")
	check(is_equal_approx(art.size.y, text.size.y) and is_equal_approx(text.size.y, choices.size.y), "三栏等高")
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	check(viewport.grow(1).encloses(art) and viewport.grow(1).encloses(text) and viewport.grow(1).encloses(choices), "三栏都在视口内")
	# Node art is shown whole: contain instead of cover, so a landscape still is
	# scaled down inside the column rather than cropped at both sides.
	var illustration := node_of("NodeEventIllustration") as TextureRect
	check(illustration != null and illustration.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "立绘完整显示不裁切")
	for i in range(4): await process_frame
	if illustration != null and illustration.texture != null:
		var source: Vector2 = illustration.texture.get_size()
		var inside: Vector2 = illustration.size
		var fit: float = minf(inside.x/source.x, inside.y/source.y)
		var drawn := source * fit
		check(inside.x > 0.0 and inside.y > 0.0, "立绘栏有可用尺寸 "+str(inside))
		check(drawn.x <= inside.x+1.0 and drawn.y <= inside.y+1.0, "立绘整张缩进栏内 "+str(drawn)+" / "+str(inside))
		check(drawn.x > inside.x-1.0 or drawn.y > inside.y-1.0, "立绘至少一边贴满栏位，等比缩放不拉伸 "+str(drawn))
	# Node events own the screen: the left-edge utilities step aside instead of
	# showing through the plate. Salvage stays (covered) because it belongs to
	# the world actions that remain drawn under the event surface.
	var surface := node_of("NodeEventSurface")
	var reset_node := node_of("ResetRaftView")
	var toggle_node := node_of("ToggleRaftView")
	var treasure_node := node_of("CollectiblesEntry")
	var salvage_node := node_of("SalvageEntry")
	check(surface != null, "事件底板存在")
	check(reset_node != null and not reset_node.is_visible_in_tree(), "事件阶段隐藏视角复位")
	check(toggle_node != null and not toggle_node.is_visible_in_tree(), "事件阶段隐藏视角切换")
	check(treasure_node != null and not treasure_node.is_visible_in_tree(), "事件阶段隐藏遗物仓库入口")
	check(salvage_node != null and salvage_node.visible, "打捞按钮仍在，只是被底板覆盖")
	check(salvage_node.focus_mode == Control.FOCUS_NONE, "被覆盖的打捞按钮不可用键盘触发")
	check(node_of("VoyageNavigationBar").z_index > surface.z_index, "顶栏在事件底板之上")
	# Desktop keeps the hand strip visible; the event page stops above the AP bar.
	check(node_of("VoyageHandTopBar").z_index > surface.z_index, "手牌顶栏在事件底板之上")
	check(node_of("VoyageHandTopBar").is_visible_in_tree() and node_of("VoyageHandTray").is_visible_in_tree(), "桌面事件页不遮挡手牌区")
	var hand_top: float = node_of("VoyageHandTopBar").get_global_rect().position.y
	check(node_of("NodeEventOptions").get_global_rect().end.y <= hand_top - 8.0, "桌面事件栏止于手牌顶栏之上")
	await shot("intro")

	# intro: advance stays one-step.
	var body_page := page()
	var headline := node_of("NodeEventHeadline") as Label
	check(headline != null and headline.text == str(app.session.state.node.name), "说明栏显示事件标题")
	var advance: Button = null
	for entry in body_page.entries: pass
	for button in body_page.options_panel.find_children("*","Button",true,false):
		if button.text == "继续": advance = button
	check(advance != null, "存在继续按钮")
	if advance != null: await click(advance)
	check(app.session.state.story_step == "choice", "继续直接进入选择，不需要预选")
	check(page().preselect_key == "", "继续不留下预选状态")
	await shot("choice")

	# choice: first click selects, second confirms.
	var chosen: Dictionary = {}
	for entry in page().entries:
		if not entry.button.disabled: chosen = entry; break
	check(not chosen.is_empty(), "存在可用事件选项")
	if chosen.is_empty(): quit(1); return
	var before: Dictionary = app.session.snapshot()
	var option_name: String = str(chosen.name)
	var idle_rects: Array = []
	for entry in page().entries: idle_rects.append(entry.button.get_global_rect())
	await click(chosen.button)
	check(app.session.snapshot() == before, "首次点击只进入预选，不提交选项")
	check(page().preselect_key == str(chosen.key), "预选状态记录当前选项")
	check(chosen.button.text == "确认", "右侧对应选项变为确认")
	check(node_of("CancelPreselect").visible, "预选状态显示取消按钮")
	var preselect_headline := node_of("NodeEventHeadline") as Label
	check(preselect_headline.text == option_name, "说明栏显示选项标题")
	var paragraphs: Array = node_of("NodeEventText").find_children("NodeEventParagraph","Label",true,false)
	var shows_description := false
	for paragraph in paragraphs:
		if str(paragraph.text) == str(chosen.description): shows_description = true
	check(shows_description, "说明栏显示选项说明")
	var cancel_box := node_of("CancelPreselect").get_global_rect()
	check(cancel_box.end.x >= choices.end.x - 48 and cancel_box.position.y < choices.position.y + 96, "取消按钮位于最右框右上角")
	var prompt := node_of("NodeEventOptionsHint") as Label
	check(prompt != null and prompt.visible and prompt.text == "请做出选择", "选项栏同一行左侧保留请做出选择")
	if prompt != null:
		check(prompt.get_global_rect().end.x < cancel_box.position.x and absf(prompt.get_global_rect().position.y - cancel_box.position.y) < 20.0, "提示文字与取消按钮同一行且在其左侧")
	var shift := 0.0
	for i in range(page().entries.size()):
		shift = maxf(shift, (page().entries[i].button.get_global_rect().position - idle_rects[i].position).length())
	check(shift < 0.5, "取消选择不改变其他选项的位置 "+str(shift))
	await shot("preselect")

	await click(node_of("CancelPreselect"))
	check(page().preselect_key == "", "取消后退出预选")
	check(chosen.button.text == option_name, "取消后选项恢复原名")
	check(not node_of("CancelPreselect").visible, "非预选状态隐藏取消按钮")
	check((node_of("NodeEventHeadline") as Label).text == str(app.session.state.node.name), "取消后恢复事件标题")
	var restored := 0.0
	for i in range(page().entries.size()):
		restored = maxf(restored, (page().entries[i].button.get_global_rect().position - idle_rects[i].position).length())
	check(restored < 0.5, "取消后选项位置回到原处 "+str(restored))
	await shot("cancelled")

	await click(chosen.button)
	check(app.session.snapshot() == before, "再次进入预选仍不提交")
	await click(chosen.button)
	check(app.session.snapshot() != before, "确认后提交真实选项")

	# Options use the whole column height instead of piling up at the top.
	await settle()
	if app.session.phase() == "story" and page() != null:
		var buttons: Array = page().options_panel.find_children("*","Button",true,false)
		if buttons.size() >= 2:
			var first: Rect2 = buttons[0].get_global_rect(); var last: Rect2 = buttons[buttons.size()-1].get_global_rect()
			var bottom_gap: float = choices.end.y - last.end.y; var top_gap: float = first.position.y - choices.position.y
			check(absf(bottom_gap - top_gap) < 48.0, "选项上下留白接近，底部不再堆积空白")

	# The window uses canvas_items stretch, so the logical canvas stays 1600x900;
	# the columns only have to stay inside the event host at that base size.
	var host := node_of("NodeEventBodyHost")
	if host != null:
		for name in ["NodeEventArt","NodeEventProse","NodeEventOptions"]:
			check(host.get_global_rect().grow(2).encloses(rect_of(name)), "三栏在事件容器内 "+name)

	# Leaving the event restores the view utilities.
	if app.session.phase() == "story": app.handle_command("skip")
	while app.session.phase() == "story" and app.session.state.story_step != "result":
		app.handle_command("advance"); await process_frame
		if app.session.phase() != "story": break
	if app.session.phase() == "story": app.handle_command("advance")
	await settle()
	if app.session.phase() != "story":
		var reset: Node = app.layout.find_child("ResetRaftView", true, false)
		check(reset == null or (reset.visible and reset.focus_mode != Control.FOCUS_NONE), "离开事件后视角按钮恢复可操作")
		var salvage_after: Node = app.layout.find_child("SalvageEntry", true, false)
		check(salvage_after == null or salvage_after.focus_mode != Control.FOCUS_NONE, "离开事件后打捞恢复可操作")
		var treasure_after: Node = app.layout.find_child("CollectiblesEntry", true, false)
		check(treasure_after == null or treasure_after.is_visible_in_tree(), "离开事件后遗物仓库入口恢复")

	root.size = Vector2i(1600,900)
	app.queue_free(); await process_frame
	print("NODE EVENT UI: %s" % ("PASS" if failures == 0 else "FAIL"))
