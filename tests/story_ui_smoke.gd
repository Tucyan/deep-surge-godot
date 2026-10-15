extends "res://tests/flow_ui_smoke.gd"

func all_options(node: Node) -> Array:
	var result: Array = []
	if node is OptionButton: result.append(node)
	for child in node.get_children(): result.append_array(all_options(child))
	return result

func select_option(text: String) -> void:
	for choice in all_options(app.current_page):
		for i in range(choice.item_count):
			if choice.get_item_text(i) == text:
				choice.select(i); choice.item_selected.emit(i); await process_frame; return
	check(false,"下拉选项存在："+text)

func install_ui(id: String) -> void:
	if app.session.I.count(app.session.state,id) < 1: return
	await click("木筏详情")
	for cell in app.session.state.cells:
		if cell.status == "intact" and cell.equipment.is_empty():
			await click("%d,%d\n空格" % [cell.x+1,cell.y+1])
			await select_option(app.catalog.entry("cards",id).name)
			await click("安装 · "+app.catalog.entry("cards",id).name)
			break
	await click("X")

func fuel_ui() -> void:
	for cell in app.session.state.cells:
		if cell.status == "intact" and cell.equipment.get("id","") == "lamp" and cell.equipment.fuel < 2:
			var material := ""
			for id in ["corpse","wood"]:
				if app.session.I.count(app.session.state,id) > (2 if id == "wood" else 0): material = id; break
			if material == "": return
			await click("木筏详情")
			await click("%d,%d\n灯" % [cell.x+1,cell.y+1])
			await click("投入 · "+app.catalog.entry("cards",material).name)
			await click("X")

func supplies_ui() -> void:
	for card in app.session.state.hand.duplicate(true):
		var stat: String = {"food":"hunger","water":"hydration","calm":"sanity"}.get(card.id,"")
		if stat != "" and app.session.state.player[stat] <= app.session.state.player[stat+"_max"]-int(app.catalog.entry("cards",card.id).effects[0].delta): await click("使用 · "+app.catalog.entry("cards",card.id).name)

func bounds(node: Node) -> void:
	if node is ScrollContainer: check(false,"剧情/夜间/任务不能有滚动条")
	if node is Button and node.is_visible_in_tree() and not node.disabled:
		var r: Rect2 = node.get_global_rect()
		check(r.position.x >= -1 and r.position.y >= -1 and r.end.x <= 1601 and r.end.y <= 901,"按钮在窗口内 "+node.text+" "+str(r))
	for child in node.get_children(): bounds(child)

func run() -> void:
	root.size = Vector2i(1600,900)
	app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app)
	await process_frame
	await click("剧情模式"); await shot("story-setup"); await click("开始航程")
	check(app.session.state.mode == "story","实际剧情入口")
	var operations := 0
	var captured: Array = []
	while app.session.phase() not in ["chapterComplete","finished"] and operations < 450 and failures == 0:
		operations += 1
		await process_frame; await process_frame
		bounds(app.layout)
		var before: Dictionary = app.session.snapshot()
		var v: Dictionary = app.session.view()
		if v.phase == "nightHub" and v.night.stage == "awaitAction" and "night" not in captured: await shot("story-night"); captured.append("night")
		if v.phase == "story" and not v.scene.is_empty():
			var id: String = v.scene.id
			if id in ["ST.L1.S05","ST.L1.P14","ST.L1.F15","ST.L1.EP15"] and id not in captured:
				await shot("story-"+id.get_slice(".",2)); captured.append(id)
		match v.phase:
			"navigation":
				var node: Dictionary = v.candidates[0]
				for candidate in v.candidates:
					if candidate.id == "camp": node = candidate; break
				await click("出发 · "+node.name)
			"preparation":
				await supplies_ui()
				if v.voyage == 2:
					await shot("story-teaching")
					await click("合成"); await click("制造滤水器 · 1 AP"); await click("X")
					await install_ui("filter")
					await click("木筏详情"); await click("1,1\n滤水器"); await click("合并升级 · AP1"); await click("X")
				if v.voyage == 3: await install_ui("crossbow"); await install_ui("lamp")
				await fuel_ui(); await click("进入节点")
			"story":
				if v.story_step == "intro": await click("继续")
				elif v.story_step == "result": await click("继续剧情" if not v.scene.is_empty() and v.scene.id == "ST.L1.F15" else ("完成这段剧情" if not v.scene.is_empty() else "结束节点"))
				elif not v.scene.is_empty():
					if v.scene.combat: await click("迎战")
					elif v.scene.id == "ST.L1.S04": await click("作为临时协作者同行")
					elif v.scene.id == "ST.L1.F15": await shot("story-final-choice"); await click("按节律封闭")
					else: await click(v.scene.choices[0].name)
				elif v.node.has("monster"): await click("离开遭遇")
				else:
					for option in v.node.get("options",[]):
						if option.disabled_reason == "": await click(option.name); break
			"battle":
				var arrow: Array = v.hand.filter(func(c): return c.id == "arrow")
				if not arrow.is_empty(): await click("使用 · 射箭")
				elif v.battle.ap > 0: await click("使用 · 出拳")
				else: await click("结束战斗回合")
			"aftermath":
				await supplies_ui(); await fuel_ui()
				await click("结束白天" if v.voyage in range(5,15) else "结束航行")
			"nightHub":
				match v.night.stage:
					"services":
						if v.voyage == 5: await click("接受委托"); await click("完成今晚，整理手牌")
						else: await click("安排今晚行动")
					"awaitAction":
						var title: String = {7:"检查门框",10:"记录敲击间隔",13:"测量舱壁外深度",14:"核对分队的记忆"}.get(int(v.voyage),"休息")
						await click(title)
					"result": await click("记下今晚结果")
					"complete": await click("完成今晚，整理手牌")
			"discard":
				var chosen: Dictionary = v.hand[0]
				for card in v.hand:
					if card.id in ["iron","plastic","cloth"]: chosen = card; break
				await click("弃置 · "+app.catalog.entry("cards",chosen.id).name)
		if before.state == app.session.state:
			check(false,"UI流程无进展 "+v.phase+" 第"+str(v.voyage)+" "+app.message); await shot("story-blocked"); break
	check(app.session.phase() == "chapterComplete" and app.session.state.campaign.resolution.get("outcome","") == "A","15站真实GUI到达A章节停点")
	await shot("story-complete")
	await click("任务与线索"); await shot("story-journal"); bounds(app.layout)
	await click("下一条"); await click("X")
	print("STORY UI: %s (实际15站、按钮鼠标输入、下拉选择、3D、无滚动条)" % ("PASS" if failures == 0 else "FAIL"))
	app.queue_free(); await process_frame; quit(0 if failures == 0 else 1)
