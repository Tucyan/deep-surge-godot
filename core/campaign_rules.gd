extends RefCounted
## Test-story scheduling owns no scene, widget, art resource or wall-clock time.
const I = preload("res://core/inventory.gd")
const Stats = preload("res://core/run_statistics.gd")

static func config(ctx) -> Dictionary:
	return ctx.catalog.entry("story_config","first_layer")

static func enabled(ctx) -> bool:
	return ctx.state.get("mode","") == "story"

static func initialize(ctx) -> void:
	ctx.state.length = int(config(ctx).length)
	ctx.state.campaign = {"version":config(ctx).version,"chapter":"L1","route":"","day_closed":0,"ledger":{},"clues":[],"quests":{},"night":{},"runtime":{},"resolution":{},"tutorial":{},"night_history":[]}

static func fixed_candidate(ctx) -> bool:
	if not enabled(ctx): return false
	var id: String = config(ctx).fixed_days.get(str(int(ctx.state.voyage)),"")
	if ctx.state.voyage == 15: id = "ST.L1.F15" if ctx.state.campaign.route == "scholar" else "ST.L1.SOLO15"
	if id == "": return false
	var node: Dictionary = ctx.catalog.entry("story_nodes",id)
	node.visit_id = "candidate-%d" % ctx.state.next_id
	ctx.state.next_id += 1
	ctx.state.candidates = [node]
	return true

static func after_move(ctx) -> void:
	if not enabled(ctx): return
	var pack: Dictionary = config(ctx).packs.get(str(int(ctx.state.voyage)),{})
	for id in pack: ctx.give(id,int(pack[id]),false,"tutorial")
	if not pack.is_empty(): ctx.log_text("领取本站教学补给；物资仍需自行使用或安装。")

static func tutorial_reason(ctx) -> String:
	if not enabled(ctx) or ctx.state.voyage != 2: return ""
	var t: Dictionary = ctx.state.campaign.tutorial
	if not t.get("crafted_filter",false): return "先在合成页制造滤水器（木头1、塑料2、AP1）"
	if not t.get("installed_filter",false): return "先在木筏页安装滤水器"
	if not t.get("upgraded_filter",false): return "先用另一张滤水器将它升至Ⅱ级（AP1）"
	return ""

static func tutorial_operation(ctx) -> String:
	if not enabled(ctx) or ctx.state.voyage != 2 or ctx.phase() != "preparation": return ""
	var t: Dictionary = ctx.state.campaign.tutorial
	if not t.get("crafted_filter",false): return "craft"
	if not t.get("installed_filter",false): return "install"
	if not t.get("upgraded_filter",false): return "upgrade"
	return ""

static func tutorial_guard(ctx, command: String, args: Dictionary) -> String:
	var operation := tutorial_operation(ctx)
	if operation == "" or command not in ["craft","install","upgrade","expand","heal","repair_cell","action_card","salvage","transmute"]: return ""
	if command != operation: return tutorial_reason(ctx)
	if command == "craft" and args.get("id","") != "filter": return "设备教学先完成滤水器，保留安装和升级所需AP"
	if command == "install" and I.find(ctx.state,args.get("uid","")).get("id","") != "filter": return "设备教学先安装滤水器"
	if command == "upgrade":
		for cell in ctx.state.cells:
			if cell.id == args.get("cell","") and cell.equipment.get("id","") == "filter": return ""
		return "设备教学先升级滤水器"
	return ""

static func record_action(ctx, command: String, args: Dictionary) -> void:
	if not enabled(ctx) or ctx.state.voyage != 2: return
	var t: Dictionary = ctx.state.campaign.tutorial
	if command == "craft" and args.get("id","") == "filter": t.crafted_filter = true
	for cell in ctx.state.cells:
		if cell.equipment.get("id","") == "filter":
			if command == "install": t.installed_filter = true
			if command == "upgrade" and int(cell.equipment.level) >= 2: t.upgraded_filter = true

static func enter(ctx) -> bool:
	if not ctx.catalog.entry("story_nodes",ctx.state.node.id).is_empty():
		var reason := tutorial_reason(ctx)
		if reason != "": return ctx.fail(reason)
		start_scene(ctx,ctx.state.node.id,"day",ctx.state.node.visit_id)
		return true
	return false

static func start_scene(ctx, id: String, return_to: String, visit: String = "") -> void:
	var c: Dictionary = ctx.state.campaign
	if visit == "":
		visit = "story-%d" % ctx.state.next_id; ctx.state.next_id += 1
	c.runtime = {"id":id,"visit_id":visit,"index":0,"return_to":return_to,"handled":false}
	c.ledger[id] = {"status":"entered","visit_id":visit,"voyage":ctx.state.voyage}
	ctx.state.phase = "story"; ctx.state.story_step = "intro"; ctx.state.result_text = ""; ctx.panel = "story"
	ctx.log_text("剧情："+ctx.catalog.entry("story_nodes",id).name)
	ctx.log_text(ctx.catalog.entry("story_nodes",id).lines[0])

static func has_scene(ctx) -> bool:
	return enabled(ctx) and not ctx.state.campaign.runtime.is_empty()

static func advance(ctx, skip: bool = false) -> bool:
	var r: Dictionary = ctx.state.campaign.runtime
	if ctx.phase() != "story": return false
	var node: Dictionary = ctx.catalog.entry("story_nodes",r.id)
	if ctx.state.story_step == "intro":
		var first_unread: int = int(r.index)+1
		if skip: r.index = node.lines.size()-1
		else: r.index += 1
		for index in range(first_unread,mini(int(r.index)+1,node.lines.size())): ctx.log_text(node.lines[index])
		if r.index >= node.lines.size()-1: ctx.state.story_step = "choice"
		return true
	if ctx.state.story_step == "choice": return ctx.fail("必须选择当前行动，不能跳过")
	if not r.handled: return ctx.fail("当前剧情尚未完成")
	c_finish_scene(ctx)
	return true

static func c_finish_scene(ctx) -> void:
	var c: Dictionary = ctx.state.campaign
	var r: Dictionary = c.runtime.duplicate(true)
	c.ledger[r.id].status = "completed"
	c.runtime = {}
	if r.id == "ST.L1.F15":
		start_scene(ctx,"ST.L1.EP15","day")
		return
	if r.return_to == "day":
		ctx.state.completed += 1; ctx.state.phase = "aftermath"; ctx.panel = ""
		ctx.log_text("日间节点完成，剩余基地AP仍可使用。")
	else:
		if r.return_to == "action": c.night.stage = "awaitAction"
		else: c.night.stage = "services"
		ctx.state.phase = "nightHub"; ctx.panel = "night"

static func choice_reason(ctx, id: String) -> String:
	if not has_scene(ctx): return "没有当前剧情"
	var r: Dictionary = ctx.state.campaign.runtime
	if r.handled: return "已处理"
	if r.id != "ST.L1.F15": return ""
	var c: Dictionary = ctx.state.campaign
	if id == "seal":
		for clue in ["dry_seam","seven_knocks","false_depth"]:
			if clue not in c.clues: return "缺少已确认的结构线索"
		if burning_lamp(ctx).is_empty(): return "需要完好且有燃料的灯"
		for material in config(ctx).final_seal_costs:
			if I.count(ctx.state,material) < int(config(ctx).final_seal_costs[material]): return "封闭物资不足（木头2、绳索1）"
	elif id == "tow":
		if "dry_seam" not in c.clues: return "尚未确认结构接缝"
		if ctx.state.cells.filter(func(cell): return cell.status == "intact").size() < 2: return "至少需要两个完好筏格"
		if ctx.Rules.outer_cells(ctx.state).filter(func(cell): return cell.status == "intact").is_empty(): return "需要一格完好的外围筏格承担拖曳"
		if I.count(ctx.state,"rope") < int(config(ctx).final_tow_costs.rope): return "需要绳索2"
	return ""

static func burning_lamp(ctx) -> Dictionary:
	for cell in ctx.state.cells:
		if cell.status == "intact" and cell.equipment.get("id","") == "lamp" and cell.equipment.get("fuel",0) > 0: return cell
	return {}

static func option(ctx, id: String) -> bool:
	var c: Dictionary = ctx.state.campaign
	var r: Dictionary = c.runtime
	if ctx.phase() != "story" or ctx.state.story_step != "choice": return false
	var node: Dictionary = ctx.catalog.entry("story_nodes",r.id)
	if node.choices.filter(func(o): return o.id == id).is_empty(): return ctx.fail("不属于当前剧情的选择")
	var reason := choice_reason(ctx,id)
	if reason != "": return ctx.fail(reason)
	for choice in node.choices:
		if choice.id==id: ctx.log_text("选择："+choice.name)
	var result: String = "已记录："+node.name
	match node.handler:
		"route":
			if c.route != "": return ctx.fail("路线已选择")
			c.route = id
			if id == "solo":
				for card in config(ctx).solo_pack: ctx.give(card,int(config(ctx).solo_pack[card]),false,"farewell")
				for event in ["ST.L1.S05","ST.L1.A08","ST.L1.A11","ST.L1.P14","ST.L1.F15","ST.L1.EP15"]:
					c.ledger[event] = {"status":"bypassed","visit_id":r.visit_id,"voyage":ctx.state.voyage}
				result = "你谢绝邀请，收下告别物资。分队留下一张浮标记录，然后慢慢远去。"
			else: result = "你成为临时协作者。木筏仍属于你；分队只提供有限的夜间停泊与交流。"
		"door":
			var quest: Dictionary = config(ctx).special_quest
			c.quests[quest.id] = {"status":"active","claimed":false}
			result = "已接下异常舱门任务。门保持关闭；今晚只做记录，不进入房间。"
		"final": result = resolve_final(ctx,id)
		"solo_exit": c.resolution = {"outcome":"SOLO","plan":id,"costs":{},"losses":[],"relationship":"独航","people":"未加入分队"}; result = "独航记录已保存。你继续沿浮标漂流，第二层内容尚未开放。"
		"epilogue": result = "铁钉与旧图纸一并留在记录中。第一层的调查已经结束，异常的来源仍未明。"
	r.handled = true
	ctx.result_story(result)
	return true

static func resolve_final(ctx, plan: String) -> String:
	var c: Dictionary = ctx.state.campaign
	var resolution := {"plan":plan,"clues":c.clues.duplicate(),"costs":{},"losses":[],"people":"确认人员已撤离；本测试未记录人员死亡"}
	var text := ""
	match plan:
		"seal":
			var costs: Dictionary = config(ctx).final_seal_costs
			for material in costs: I.consume(ctx.state,material,int(costs[material]),"final_plan")
			var lamp := burning_lamp(ctx); lamp.equipment.fuel -= 1
			resolution.merge({"outcome":"A","costs":costs.duplicate(),"lamp_cell":lamp.id,"lamp_fuel":1,"relationship":"信任增加"})
			text = "你沿干燥接缝，在七次敲击的空隙里封闭舱段。灯燃料1、木头2、绳索1已消耗。人员与主要物资保住了，领队愿意继续信任你的判断。"
		"tow":
			I.consume(ctx.state,"rope",int(config(ctx).final_tow_costs.rope),"final_plan")
			var outer: Array = ctx.Rules.outer_cells(ctx.state).filter(func(cell): return cell.status == "intact")
			outer.sort_custom(func(a,b): return a.id < b.id)
			var damaged: Dictionary = outer[0]; damaged.status = "damaged"; damaged.damaged_at = ctx.state.voyage
			resolution.merge({"outcome":"B","costs":config(ctx).final_tow_costs.duplicate(),"losses":["公共储备一箱"],"damaged_cell":damaged.id,"relationship":"谨慎合作"})
			text = "绳索2已消耗，异常舱段被强行拖离。一箱公共储备丢失，外围筏格%s破损，其设备停用。人员已撤离，领队对你的方案仍有所保留。" % damaged.id
		"release":
			var loss: int = mini(int(config(ctx).emergency_hp_cost),int(ctx.state.player.hp)-1)
			ctx.change("hp",-loss)
			resolution.merge({"outcome":"C","costs":{"hp":loss},"losses":["公共储备严重流失"],"relationship":"信任受损"})
			text = "你解开缆绳，协助人员撤离。生命减少%d；公共储备严重流失。门仍在原处，你没有解除危机，只能撤离。领队沉默地收起研究记录。" % loss
	c.resolution = resolution
	Stats.resolve_crisis(ctx.state,true)
	c.quests[config(ctx).special_quest.id].status = "completed"
	c.quests[config(ctx).special_quest.id].resolution = resolution.outcome
	return text

static func battle_won(ctx) -> void:
	if has_scene(ctx) and ctx.state.campaign.runtime.id == "ST.L1.T03":
		ctx.state.campaign.runtime.handled = true
		ctx.state.campaign.tutorial.battle_won = true

static func end_day(ctx) -> bool:
	if ctx.phase() != "aftermath": return ctx.fail("先完成当前节点与结果剧情")
	var c: Dictionary = ctx.state.campaign
	if ctx.state.voyage < 5 or ctx.state.voyage == 15: return ctx.Rules.settle(ctx)
	if c.day_closed >= ctx.state.voyage: return ctx.fail("今天的夜间已完成")
	ctx.state.ap = 0
	c.night = {"voyage":ctx.state.voyage,"stage":"services","budget":0 if ctx.state.voyage == 5 else 1,"selected":"","exchanged":false,"result":""}
	ctx.state.phase = "nightHub"; ctx.panel = "night"
	if ctx.state.voyage == 5 and c.route == "scholar": start_scene(ctx,"ST.L1.S05","services")
	return true

static func open_actions(ctx) -> bool:
	if ctx.phase() != "nightHub" or ctx.state.campaign.night.stage != "services" or ctx.state.campaign.night.budget != 1: return false
	ctx.state.campaign.night.stage = "awaitAction"
	var id: String = config(ctx).public_nights.get(str(int(ctx.state.voyage)),"")
	if id != "" and ctx.state.campaign.route == "scholar": start_scene(ctx,id,"action")
	return true

static func action_reason(ctx, id: String) -> String:
	var c: Dictionary = ctx.state.campaign
	if ctx.phase() != "nightHub" or c.night.stage != "awaitAction" or c.night.budget != 1: return "今晚行动尚未开放或已使用"
	if id == "rest": return ""
	if c.route != "scholar": return "独航没有分队调查入口"
	var action: Dictionary = config(ctx).investigations.get(id,{})
	if action.is_empty(): return "未知调查"
	if action.clue in c.clues: return "已完成，不能重复领取线索"
	if action.requires != "" and action.requires not in c.clues: return "需要先完成前一方向的调查"
	var cost: int = int(config(ctx).investigation_sanity_cost)
	if ctx.state.origin == "fool": cost = maxi(0,cost-5)
	if ctx.state.player.sanity <= cost: return "精神不足以安全调查，请休息"
	return ""

static func night_action(ctx, id: String) -> bool:
	var reason := action_reason(ctx,id)
	if reason != "": return ctx.fail(reason)
	var c: Dictionary = ctx.state.campaign
	c.night.budget = 0; c.night.selected = id; c.night.stage = "result"
	if id == "rest":
		for stat in config(ctx).rest: ctx.change(stat,int(config(ctx).rest[stat]))
		c.night.result = "你在灯下休息。生命+3、食水各+50、SAN+35（受上限限制）。夜间主要行动已用完。"
	else:
		var investigation: Dictionary = config(ctx).investigations[id]
		var cost: int = int(config(ctx).investigation_sanity_cost)
		if ctx.state.origin == "fool": cost = maxi(0,cost-5)
		ctx.change("sanity",-cost)
		c.clues.append(investigation.clue)
		c.night.result = investigation.text+"\n已记录线索："+investigation.clue_name+"；SAN消耗%d。" % cost
	ctx.log_text(c.night.result)
	return true

static func night_ack(ctx) -> bool:
	if ctx.phase() != "nightHub" or ctx.state.campaign.night.stage != "result": return false
	ctx.state.campaign.night.stage = "complete"
	return true

static func finish_night(ctx) -> bool:
	if ctx.phase() != "nightHub": return false
	var c: Dictionary = ctx.state.campaign
	if c.night.stage != "complete" and not (ctx.state.voyage == 5 and c.night.stage == "services"): return ctx.fail("先完成夜间公共事件、行动及结果")
	c.day_closed = ctx.state.voyage
	c.night.stage = "complete"
	c.night_history.append(c.night.duplicate(true))
	ctx.state.phase = "aftermath"; ctx.panel = ""
	return ctx.Rules.settle(ctx)

static func quest(ctx, command: String) -> bool:
	if ctx.phase() != "nightHub" or ctx.state.campaign.night.stage != "services" or ctx.state.campaign.route != "scholar": return false
	var q: Dictionary = config(ctx).ordinary_quest
	var quests: Dictionary = ctx.state.campaign.quests
	if command == "accept_quest":
		if quests.has(q.id): return ctx.fail("已接受该委托")
		quests[q.id] = {"status":"active","claimed":false}; ctx.log_text("接受委托："+q.name); return true
	if not quests.has(q.id) or quests[q.id].status != "active" or quests[q.id].claimed: return ctx.fail("没有可提交的委托")
	for id in q.costs:
		if I.count(ctx.state,id) < int(q.costs[id]): return ctx.fail("需要绳索2")
	for id in q.costs: I.consume(ctx.state,id,int(q.costs[id]),"quest")
	for id in q.rewards: ctx.give(id,int(q.rewards[id]),false,"quest")
	quests[q.id].status = "completed"; quests[q.id].claimed = true
	ctx.log_text("提交备用缆绳，领取一次补给。")
	return true

static func exchange(ctx, material: String) -> bool:
	if ctx.phase() != "nightHub" or ctx.state.campaign.night.stage != "services": return false
	if ctx.state.campaign.night.exchanged: return ctx.fail("今晚已交换补给")
	if material not in I.RESOURCES or not I.consume(ctx.state,material,1,"night_exchange"): return ctx.fail("需要一份基础材料")
	for id in config(ctx).exchange_reward: ctx.give(id,int(config(ctx).exchange_reward[id]),false,"night-service")
	ctx.state.campaign.night.exchanged = true; ctx.log_text("交换今晚的有限补给。")
	return true

static func next_voyage(ctx) -> bool:
	if not enabled(ctx) or ctx.state.voyage != 15: return false
	ctx.state.phase = "chapterComplete"; ctx.panel = ""
	ctx.log_text("第一层结束；保留章节成果，第二层尚未开放。整局点数未结算。")
	return true

static func project(ctx, view: Dictionary) -> void:
	if not enabled(ctx): return
	var c: Dictionary = ctx.state.campaign
	view.erase("campaign")
	view.campaign_summary = {"route":c.route,"resolution":c.resolution.duplicate(true)}
	view.tutorial_reason = tutorial_reason(ctx)
	view.tutorial_operation = tutorial_operation(ctx)
	view.known_clues = []
	for id in config(ctx).investigations:
		var d: Dictionary = config(ctx).investigations[id]
		if d.clue in c.clues: view.known_clues.append({"name":d.clue_name,"text":d.text})
	view.known_quests = []
	for id in c.quests:
		var definition: Dictionary = config(ctx).special_quest if id == config(ctx).special_quest.id else config(ctx).ordinary_quest
		view.known_quests.append({"name":definition.name,"description":definition.description,"status":c.quests[id].status,"resolution":c.quests[id].get("resolution","")})
	view.scene = {}
	if has_scene(ctx):
		var r: Dictionary = c.runtime
		var node: Dictionary = ctx.catalog.entry("story_nodes",r.id)
		view.scene = {"id":r.id,"name":node.name,"art":node.art,"text":node.lines[mini(int(r.index),node.lines.size()-1)],"index":r.index,"line_count":node.lines.size(),"choices":[],"combat":node.handler == "combat","return_to":r.return_to}
		if ctx.state.story_step == "choice":
			for option in node.choices:
				option.disabled_reason = choice_reason(ctx,option.id)
				view.scene.choices.append(option)
	# Node text and choices are presentation projections, never a copy of the future script.
	for node in view.candidates:
		for key in ["lines","choices","handler"]: node.erase(key)
	for key in ["lines","choices","handler"]: view.node.erase(key)
	view.night = c.night.duplicate(true)
	view.night_actions = []
	if ctx.phase() == "nightHub" and c.night.stage == "awaitAction":
		view.night_actions.append({"id":"rest","name":"休息","reason":action_reason(ctx,"rest"),"description":"生命+3、食水各+50、SAN+35"})
		if c.route == "scholar":
			for id in config(ctx).investigations:
				var d: Dictionary = config(ctx).investigations[id]
				if d.clue in c.clues: continue
				if d.requires != "" and d.requires not in c.clues: continue
				view.night_actions.append({"id":id,"name":d.name,"reason":action_reason(ctx,id),"description":"占用今晚一次行动；SAN消耗5（愚者减免）。"})

static func valid_save(ctx, s: Dictionary) -> bool:
	if s.mode == "challenge": return s.phase not in ["nightHub","chapterComplete"] and not s.has("campaign")
	if s.length != 15 or not s.get("campaign") is Dictionary: return false
	var c: Dictionary = s.campaign
	for key in ["version","chapter","route","day_closed","ledger","clues","quests","night","runtime","resolution","tutorial","night_history"]:
		if not c.has(key): return false
	if c.version != config(ctx).version or c.chapter != "L1" or c.route not in ["","scholar","solo"]: return false
	if not ctx.Rules.integer(c.day_closed) or c.day_closed < 0 or c.day_closed > s.voyage: return false
	for key in ["ledger","quests","night","runtime","resolution","tutorial"]:
		if not c[key] is Dictionary: return false
	if not c.clues is Array or not c.night_history is Array: return false
	if s.voyage >= 5 and c.route == "": return false
	var clue_ids := []
	for d in config(ctx).investigations.values(): clue_ids.append(d.clue)
	var seen := []
	for clue in c.clues:
		if clue not in clue_ids or clue in seen or c.route != "scholar": return false
		seen.append(clue)
	for d in config(ctx).investigations.values():
		if d.clue in c.clues and d.requires != "" and d.requires not in c.clues: return false
	for key in c.tutorial:
		if key not in ["crafted_filter","installed_filter","upgraded_filter","battle_won"] or not c.tutorial[key] is bool: return false
	for id in c.ledger:
		var e = c.ledger[id]
		if ctx.catalog.entry("story_nodes",id).is_empty() or not e is Dictionary or e.get("status") not in ["entered","completed","bypassed"] or not e.get("visit_id") is String or not ctx.Rules.integer(e.get("voyage")): return false
		if e.status == "bypassed" and c.route != "solo": return false
	for id in c.quests:
		if id not in [config(ctx).special_quest.id,config(ctx).ordinary_quest.id]: return false
		var q = c.quests[id]
		if not q is Dictionary or q.get("status") not in ["active","completed"] or not q.get("claimed") is bool: return false
		if c.route != "scholar": return false
	if not c.runtime.is_empty():
		var r: Dictionary = c.runtime
		var d: Dictionary = ctx.catalog.entry("story_nodes",r.get("id",""))
		if d.is_empty() or not r.get("visit_id") is String or not ctx.Rules.integer(r.get("index")) or r.index < 0 or r.index >= d.lines.size() or not r.get("handled") is bool or r.get("return_to") not in ["day","services","action"]: return false
		if s.phase not in ["story","battle","finished"] or not c.ledger.has(r.id) or c.ledger[r.id].visit_id != r.visit_id or c.ledger[r.id].status != "entered": return false
		if s.phase == "battle" and r.id != "ST.L1.T03": return false
	elif s.phase == "story" and not ctx.catalog.entry("story_nodes",s.node.get("id","")).is_empty(): return false
	if not c.night.is_empty():
		var n: Dictionary = c.night
		if not ctx.Rules.integer(n.get("voyage")) or n.voyage < 5 or n.voyage > 14 or not ctx.Rules.integer(n.get("budget")) or n.budget < 0 or n.budget > 1 or n.get("stage") not in ["services","awaitAction","result","complete"] or not n.get("selected") is String or not n.get("exchanged") is bool or not n.get("result") is String: return false
		if n.voyage == 5 and n.budget != 0: return false
		if n.stage in ["result","complete"] and n.budget != 0: return false
		if n.selected != "" and n.selected != "rest" and not config(ctx).investigations.has(n.selected): return false
		if s.phase == "nightHub" and n.voyage != s.voyage: return false
	if s.phase == "nightHub" and (c.night.is_empty() or not c.runtime.is_empty()): return false
	var night_days := []
	for entry in c.night_history:
		if not entry is Dictionary or not ctx.Rules.integer(entry.get("voyage")) or entry.voyage < 5 or entry.voyage > c.day_closed or entry.get("stage") != "complete" or entry.get("budget") != 0 or entry.voyage in night_days: return false
		night_days.append(entry.voyage)
	if c.route == "scholar" and s.voyage > 5 and not c.quests.has(config(ctx).special_quest.id): return false
	if s.phase == "chapterComplete" and (s.voyage != 15 or c.resolution.is_empty() or s.completed != 15 or s.awarded): return false
	if not c.resolution.is_empty():
		if c.resolution.get("outcome") not in ["A","B","C","SOLO"] or not c.resolution.get("costs") is Dictionary or not c.resolution.get("plan") is String: return false
	return true
