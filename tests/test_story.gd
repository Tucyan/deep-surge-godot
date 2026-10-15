extends SceneTree
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+text)
func _init() -> void:
	var c = load("res://content/catalog.gd").new()
	check(c.load_catalog(),"装载内容")
	var s = load("res://core/game_session.gd").new(c)
	check(s.dispatch("new",{"mode":"story","origin":"fool","seed":22}),"测试剧情可开始")
	if s.state.is_empty(): print("STORY: FAIL (入口未实现)"); quit(1); return
	check(s.state.length == 15 and s.state.candidates.size() == 1,"15站首次固定教学")
	check(s.state.candidates[0].id == "ST.L1.T01","稳定剧情节点ID")
	for route in ["scholar","solo"]:
		for plan in (["seal","tow","release"] if route == "scholar" else ["continue"]): play_route(c,route,plan)
	print("STORY: %s (15站学者A/B/C、独航、夜间与存档)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func command(s, name: String, args: Dictionary = {}) -> void:
	check(s.dispatch(name,args),name+" "+str(args)+" "+s.error)

func use_survival(s) -> void:
	for card in s.state.hand.duplicate(true):
		var stat: String = {"food":"hunger","water":"hydration","calm":"sanity"}.get(card.id,"")
		if stat != "" and s.state.player[stat] <= s.state.player[stat+"_max"]-int(s.catalog.entry("cards",card.id).effects[0].delta): command(s,"play",{"uid":card.uid})

func install_card(s, id: String) -> void:
	for cell in s.state.cells:
		if cell.status == "intact" and cell.equipment.is_empty():
			for card in s.state.hand:
				if card.id == id: command(s,"install",{"cell":cell.id,"uid":card.uid}); return

func fuel(s) -> void:
	for cell in s.state.cells:
		if cell.status == "intact" and cell.equipment.get("id","") == "lamp" and cell.equipment.fuel < 2:
			for material in ["corpse","wood"]:
				if s.I.count(s.state,material) > (2 if material == "wood" else 0): command(s,"fuel",{"cell":cell.id,"material":material}); break

func preparation(s) -> void:
	use_survival(s)
	if s.state.voyage == 2:
		command(s,"craft",{"id":"filter"}); install_card(s,"filter")
		for cell in s.state.cells:
			if cell.equipment.get("id","") == "filter":
				for card in s.state.hand:
					if card.id == "filter": command(s,"upgrade",{"cell":cell.id,"uid":card.uid}); break
	if s.state.voyage == 3:
		install_card(s,"crossbow"); install_card(s,"lamp")
	fuel(s)

func roundtrip(s) -> void:
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.snapshot()))
	var copy = load("res://core/game_session.gd").new(s.catalog)
	check(copy.restore(saved),"每阶段存档恢复 "+s.phase()+" "+copy.error)
	if copy.state.is_empty(): return
	check(JSON.stringify(copy.state) == JSON.stringify(saved.state),"恢复状态与剧情游标完全相同")
	var before: Dictionary = s.snapshot()
	command(s,"home"); command(s,"resume")
	check(s.state == before.state,"收起与继续不改变剧情、随机、夜间预算")
	check(s.restore(saved),"实际会话从JSON重新加载后继续操作")
	command(s,"resume")

func play_route(c, route: String, plan: String) -> void:
	var s = load("res://core/game_session.gd").new(c)
	command(s,"new",{"mode":"story","origin":"fool","seed":22})
	var n := 0
	var night_actions := 0
	var visited_public: Array = []
	var traded: Array = []
	var abandoned_quest := false
	while s.phase() not in ["finished","chapterComplete"] and n < 600:
		n += 1
		roundtrip(s)
		var before: Dictionary = s.snapshot()
		match s.phase():
			"navigation":
				var node: Dictionary = s.state.candidates[0]
				for candidate in s.state.candidates:
					if candidate.id == "camp": node = candidate; break
				var pool: int = s.state.pool.size()
				var day: int = s.state.voyage
				command(s,"voyage",{"id":node.visit_id})
				check(s.state.pool.size() == pool-(1 if day in range(5,15) else 0),"固定/夜间不消费普通池")
			"preparation":
				if s.state.voyage == 2:
					var rejected: Dictionary = s.snapshot(); check(not s.dispatch("enter"),"教学不能用文字跳过制造/安装/升级"); check(s.snapshot() == rejected,"拒绝教学跳过不改变状态")
					check(not s.dispatch("craft",{"id":"planter"}) and s.snapshot() == rejected,"设备教学保留必要AP，不因误选其他配方锁死")
				preparation(s); command(s,"enter")
			"story":
				var scene: Dictionary = s.state.campaign.runtime
				if s.state.story_step == "intro": command(s,"advance")
				elif s.state.story_step == "result": command(s,"advance")
				elif not scene.is_empty():
					if scene.id in ["ST.L1.A08","ST.L1.A11","ST.L1.P14"]: visited_public.append(scene.id)
					if scene.id == "ST.L1.T03": check(not s.dispatch("leave_encounter"),"不能绕过教学战斗"); command(s,"fight")
					elif scene.id == "ST.L1.S04": command(s,"option",{"id":route})
					elif scene.id == "ST.L1.F15":
						if plan == "seal": check(s.Campaign.choice_reason(s,"seal") == "","真实路线充分准备可执行封闭")
						if plan == "tow": check(s.Campaign.choice_reason(s,"tow") == "","真实路线可支付拖离")
						var materials: Dictionary = {"wood":s.I.count(s.state,"wood"),"rope":s.I.count(s.state,"rope")}
						command(s,"option",{"id":plan})
						if plan == "seal": check(s.I.count(s.state,"wood") == materials.wood-2 and s.I.count(s.state,"rope") == materials.rope-1,"A实际扣物资")
						if plan == "tow": check(s.I.count(s.state,"rope") == materials.rope-2 and s.state.cells.any(func(cell): return cell.status == "damaged"),"B实际扣物资并损坏筏格")
						var paid: Dictionary = s.snapshot(); check(not s.dispatch("option",{"id":plan}),"危机方案不能重复支付"); check(s.snapshot() == paid,"重复选择拒绝原子化")
					else: command(s,"option",{"id":c.entry("story_nodes",scene.id).choices[0].id})
				elif s.state.node.has("monster"): command(s,"leave_encounter")
				else:
					var chosen := {}
					for option in s.state.node.get("options",[]):
						if s.Rules.option_reason(s,option) == "": chosen = option; break
					check(not chosen.is_empty(),"随机节点有可执行出口")
					if chosen.is_empty(): break
					command(s,"option",{"id":chosen.id})
			"battle":
				if s.state.battle.ap <= 0: command(s,"battle_end")
				else:
					var card: Dictionary = {}
					for arrow in s.state.hand:
						if arrow.id == "arrow": card = arrow; break
					if card.is_empty(): command(s,"battle_action",{"action":"attack"})
					else: command(s,"play",{"uid":card.uid})
			"aftermath":
				use_survival(s)
				if s.phase()=="aftermath": fuel(s)
				if s.phase()=="aftermath": command(s,"end_voyage")
			"nightHub":
				var night: Dictionary = s.state.campaign.night
				check(not s.dispatch("end_voyage"),"夜间未完成不能直接航行结算")
				check(not s.dispatch("craft",{"id":"lamp"}),"夜间没有免费基地制造AP")
				match night.stage:
					"services":
						if route == "scholar" and not abandoned_quest: command(s,"accept_quest"); abandoned_quest = true
						# Keep rope for the crisis; submitting the ordinary quest is separately tested.
						if s.state.voyage not in traded:
							for material in ["iron","plastic","cloth","wood"]:
								if s.I.count(s.state,material) > 2:
									command(s,"night_exchange",{"material":material}); traded.append(s.state.voyage)
									check(not s.dispatch("night_exchange",{"material":material}),"每晚交换仅一次")
									break
						command(s,"finish_night" if s.state.voyage == 5 else "night_actions")
					"awaitAction":
						var action: String = "rest"
						if route == "scholar":
							if s.state.voyage == 7: action = "seam"
							if plan == "seal" and s.state.voyage == 10: action = "knocks"
							if plan == "seal" and s.state.voyage == 13: action = "depth"
							if plan == "seal" and s.state.voyage == 14: action = "memory"
						command(s,"night_action",{"id":action}); night_actions += 1
						check(not s.dispatch("night_action",{"id":"rest"}),"同晚不能再次休息或调查")
					"result": command(s,"night_ack")
					"complete": command(s,"finish_night")
			"discard":
				var chosen: Dictionary = s.state.hand[0]
				for card in s.state.hand:
					if card.id in ["iron","plastic","cloth"]: chosen = card; break
				command(s,"discard",{"uid":chosen.uid})
		if before.state == s.state: check(false,"路线无进展 "+s.phase()); break
		check(not s.view().has("campaign"),"前端不暴露固定事件账本或未来剧本")
	check(s.phase() == "chapterComplete","实际15站到达章节停点 "+route+"/"+plan+"，实际"+s.phase()+" 第"+str(s.state.voyage))
	check(s.state.completed == 15 and not s.state.awarded and s.profile.points == 0,"章节完成不伪造整局结算")
	if "--settlement-fixtures" in OS.get_cmdline_user_args() and route=="scholar" and plan=="seal":
		var evidence := FileAccess.open("res://evidence/settlement-chapter-A.json",FileAccess.WRITE)
		evidence.store_string(JSON.stringify(s.snapshot())); evidence.close()
	check(s.state.settlement.scope=="chapter" and s.state.settlement.points.granted==0 and s.state.settlement.points.pending==15,"章节报告展示未入账点数")
	check(s.state.stats.completed_ids.size()==15,"夜间/尾声不重复增加日间节点统计")
	for row in s.state.settlement.cards:
		check(row.obtained==row.remaining+row.use_consumed+row.cost_consumed+row.deployed+row.discarded+row.lost+row.cleared,"完整剧情卡牌收支守恒 "+row.id)
	check(night_actions == 9,"第6到14晚恰好九次行动")
	if route == "scholar":
		check(visited_public == ["ST.L1.A08","ST.L1.A11","ST.L1.P14"],"公共异变按顺序各触发一次")
		check(s.state.campaign.resolution.get("outcome","") == {"seal":"A","tow":"B","release":"C"}[plan],"各方案记录章节结果")
	else: check(s.state.campaign.clues.is_empty() and s.state.campaign.quests.is_empty() and visited_public.is_empty(),"独航不暗中改为学者路线")
	roundtrip(s)
	command(s,"abandon"); check(s.profile.points == 15,"主动结束本局才发一次整局点数")
	check(s.state.settlement.scope=="run" and s.state.settlement.outcome=="abandon" and s.last_settlement.points.granted==15,"章节后真实整局报告独立更新")
	check(s.state.chapter_report.scope=="chapter" and s.state.settlement.prior_chapters.size()==1,"章节成绩独立保存")
	check(s.state.settlement.campaign_summary.route==route,"结算冻结实际剧情路线")
	check(not s.dispatch("abandon") and s.profile.points == 15,"不重复结算")
	print("STORY ROUTE %s/%s: phase=%s, day=%d, actions=%d, hp=%d SAN=%d" % [route,plan,s.phase(),s.state.voyage,night_actions,s.state.player.hp,s.state.player.sanity])
