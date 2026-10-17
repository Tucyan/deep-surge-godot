extends SceneTree
var app: Control
var failures := 0
var capture := false
func _init() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+text)
func find_button(node: Node, text: String) -> Button:
	var matches: Array = all_buttons(node,text)
	for button in matches:
		if not button.disabled and button.is_visible_in_tree(): return button
	return matches[0] if not matches.is_empty() else null
func all_buttons(node: Node, text: String) -> Array:
	var result: Array = []
	if node is Button and (node.text == text or (text == "合成" and node.text == "合成/转化") or (text == "使用 · 出拳" and node.name == "BattleAttack")): result.append(node)
	for child in node.get_children():
		result.append_array(all_buttons(child,text))
	return result
func click(text: String) -> void:
	await process_frame
	var button := find_button(app,text)
	if button == null and text.begins_with("制造"):
		var id: String = ""
		for recipe_id in app.catalog.table("recipes"):
			if text.begins_with(app.catalog.entry("recipes",recipe_id).name): id=recipe_id
		for candidate in find_recipe_buttons(app):
			if candidate.get_meta("recipe_id","")==id: button=candidate; break
	if button == null and text.begins_with("制造") and " · " in text:
		var recipe_button := find_button(app,text.split(" · ")[0])
		if recipe_button != null: await click(recipe_button.text); button = find_button(app,text)
	if button == null and (text.begins_with("使用 · ") or text.begins_with("弃置 · ")):
		var prev_title: String = "上一页" if app.session.phase() == "battle" else "上一组手牌"
		var next_title: String = "下一页" if app.session.phase() == "battle" else "下一组手牌"
		var previous := find_button(app,prev_title)
		while previous != null and not previous.disabled:
			await click(prev_title); previous = find_button(app,prev_title)
		button = find_button(app,text)
		var next := find_button(app,next_title)
		while button == null and next != null and not next.disabled:
			await click(next_title); button = find_button(app,text); next = find_button(app,next_title)
	check(button != null and not button.disabled,"可操作按钮 "+text)
	if button == null or button.disabled: return
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button); break
		ancestor = ancestor.get_parent()
	await process_frame

	await process_frame
	var pos: Vector2 = root.get_final_transform() * button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = pos; Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position = pos; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame
func shot(id: String) -> void:
	await process_frame
	await process_frame
	if capture:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://evidence/hud-"+id+".png") == OK,"保存截图")
func find_recipe_buttons(node: Node) -> Array:
	var result: Array=[]
	if node is Button and node.has_meta("recipe_id"): result.append(node)
	for child in node.get_children(): result.append_array(find_recipe_buttons(child))
	return result
func run() -> void:
	root.size = Vector2i(1600,900)
	app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await process_frame
	check(find_button(app,"继续游戏").disabled,"没有有效档案不能继续")
	await shot("home")
	await click("图鉴"); await shot("encyclopedia"); await click("X")
	await click("局外商店"); await shot("meta-shop"); await click("X")
	if failures > 0:
		app.queue_free(); await process_frame; quit(1); return
	await click("剧情模式")
	check(not app.session.active(),"剧情准备页不自动创建新局")
	await click("X")
	await click("挑战模式"); await shot("setup"); await click("开始航程")
	check(app.session.phase() == "navigation","新局导航")
	check(find_button(app,"合成") == null,"导航不显示合成入口")
	check(app.session.state.candidates.size() <= 3,"仅当前候选")
	await shot("game")
	var first: Dictionary = app.session.state.candidates[0]
	await click("出发 · "+first.name)
	await click("合成"); await shot("craft"); await click("X")
	app.handle_command("panel",{"id":"raft"}); await process_frame; await shot("raft"); await click("X")
	await click("进入节点"); await shot("story")
	await click("X")
	check(app.session.phase() == "story","收起事件不推进阶段")
	check(find_button(app,"合成") == null and find_button(app,"结束航行") == null,"事件处理中无非法动作")
	await click("处理当前事件")
	await click("返回首页")
	await click("继续游戏")
	check(app.session.panel == "story","继续原事件")
	# Fixture only for mechanical pages; navigation above uses real seed/candidates.
	for node_id in ["trader","battle"]:
		var data: Dictionary = app.session.snapshot()
		data.state.node = app.catalog.entry("nodes",node_id)
		data.state.node.visit_id = "ui-test-fixture"
		data.state.phase = "preparation"; data.state.ap = 3
		check(app.session.restore(data),"夹具恢复")
		app.handle_command("resume")
		await click("进入节点"); await click("继续")
		if node_id == "trader":
			await click("进入商店"); await shot("shop"); await click("离开商店")
		else:
			await click("迎战"); await shot("battle")
			for i in range(3): await click("使用 · 出拳")
			await click("结束战斗回合")
			for i in range(3): await click("使用 · 出拳")
		check(app.session.phase() == "story" and app.session.state.story_step == "result","机制返回结果剧情")
		await click("结束节点")
		check(app.session.phase() == "aftermath","结果结束才收尾")
	for i in range(5):
		app.handle_command("home"); app.handle_command("resume"); await process_frame
	check(app.get_child_count() == 2,"界面层与持久3D层没有重复残留")
	await full_mouse_route()
	print("FLOW UI: %s (mouse, new game, conditional pages, mechanism returns, 9 pages)" % ("PASS" if failures == 0 else "FAIL"))
	app.queue_free(); await process_frame
	quit(0 if failures == 0 else 1)

func full_mouse_route() -> void:
	# Fresh seed 22: all decisions below use visible buttons and actual candidates.
	app.handle_command("abandon"); app.handle_command("home")
	await click("挑战模式"); await click("开始航程")
	var operations := 0
	while app.session.active() and operations < 250:
		operations += 1
		var before: Dictionary = app.session.snapshot()
		var v: Dictionary = app.session.view()
		match v.phase:
			"navigation":
				var candidate: Dictionary = v.candidates[0]
				for n in v.candidates:
					if n.id == "camp": candidate = n; break
				await click("出发 · "+candidate.name)
			"preparation","aftermath":
				if v.phase == "preparation" and v.cells.filter(func(c): return c.equipment.get("id","") == "crossbow").is_empty():
					var materials_ok := true
					for id in ["wood","iron","rope"]:
						if v.hand.filter(func(c): return c.id == id).is_empty(): materials_ok = false
					if materials_ok and v.ap >= 2:
						await click("合成"); await click("制造弓弩 · 1 AP"); await click("X")
						app.handle_command("panel",{"id":"raft"}); await process_frame; await click("安装 · 弓弩"); await click("X")
				for card in v.hand:
					if card.definition.kind == "survival": await click("使用 · "+card.definition.name)
				await click("进入节点" if v.phase == "preparation" else "结束航行")
			"story":
				if v.story_step == "intro": await click("继续")
				elif v.story_step == "result": await click("结束节点")
				elif v.node.has("monster"): await click("迎战" if v.node.get("boss",false) else "离开遭遇")
				else:
					var selected := {}
					for option in v.node.options:
						if option.get("disabled_reason","") == "":
							if selected.is_empty() or option.id == "rest": selected = option
							if option.id == "rest": break
					if not selected.is_empty(): await click(selected.name)
			"discard":
				if not v.hand.is_empty(): await click("弃置全部 · 贝币" if v.hand[0].id == "coin" else "弃置 · "+v.hand[0].definition.name)
			"battle":
				for card in v.hand:
					if card.id == "pollution" and app.session.state.battle.ap >= 2: await click("使用 · 潮蚀污染")
				for card in v.hand:
					if app.session.phase() == "battle" and card.id == "arrow": await click("使用 · 射箭")
				while app.session.phase() == "battle" and app.session.state.battle.ap > 0: await click("使用 · 出拳")
				if app.session.phase() == "battle": await click("结束战斗回合")
			_: break
		if before == app.session.snapshot():
			printerr("UI BLOCK phase=%s node=%s step=%s error=%s" % [app.session.phase(),app.session.state.node.get("id",""),app.session.state.story_step,app.session.error])
			await shot("blocked")
			check(false,"鼠标指令没有推进规则")
			break
		if failures > 0: break
	check(app.session.state.get("result","") == "survived","鼠标完成种子22全部航程并战胜首领")
	if app.session.state.get("result","") == "survived":
		print("MOUSE FULL ROUTE seed=22 length=%d nodes=%d result=survived" % [app.session.state.length,app.session.state.completed])
		await shot("completed")
