extends SceneTree
var catalog
var failures := 0
func check(value: bool, text: String) -> void:
	if not value: failures += 1; printerr("FAIL: "+text)
func _init() -> void:
	catalog = load("res://content/catalog.gd").new()
	catalog.load_catalog()
	var recorded: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/health-route-22.json"))
	var success_seed := -1
	var failure_seed := -1
	for seed in [0,22]:
		var s = load("res://core/game_session.gd").new(catalog)
		s.dispatch("new",{"mode":"challenge","origin":"strong","seed":seed})
		var operations := 0
		while s.active() and operations < 500:
			operations += 1
			if seed==22:
				check(operations<=recorded.steps.size(),"recorded public route has next command")
				if operations>recorded.steps.size(): break
				var step: Dictionary=recorded.steps[operations-1]
				check(s.dispatch(step.command,step.args),"recorded public command "+step.command)
				continue
			var previous: Dictionary = s.snapshot()
			var v: Dictionary = s.view()
			match v.phase:
				"navigation":
					var candidate: Dictionary = v.candidates[0]
					for n in v.candidates:
						if n.id == "camp": candidate = n; break
					s.dispatch("voyage",{"id":candidate.visit_id})
				"preparation","aftermath":
					if s.state.player.hp<=6 and s.I.count(s.state,"medkit")==0: s.dispatch("craft",{"id":"medkit"})
					if v.phase == "preparation" and s.state.cells.filter(func(c): return c.equipment.get("id","") == "crossbow").is_empty():
						if s.dispatch("craft",{"id":"crossbow"}):
							var equipment: Dictionary = s.state.hand.filter(func(c): return c.id == "crossbow")[0]
							for cell in s.state.cells:
								if cell.status == "intact" and cell.equipment.is_empty(): s.dispatch("install",{"uid":equipment.uid,"cell":cell.id}); break
					for card in v.hand:
						if card.definition.kind == "survival": s.dispatch("play",{"uid":card.uid})
					s.dispatch("enter" if v.phase == "preparation" else "end_voyage")
				"story":
					if v.story_step != "choice": s.dispatch("advance")
					elif v.node.has("monster"):
						if v.node.get("boss",false): s.dispatch("fight")
						else: s.dispatch("leave_encounter")
					else:
						var selected := {}
						for option in v.node.options:
							if option.get("disabled_reason","") == "":
								if selected.is_empty() or option.id == "rest": selected = option
								if option.id == "rest": break
						if not selected.is_empty(): s.dispatch("option",{"id":selected.id})
				"discard":
					if not v.hand.is_empty():
						var chosen: Dictionary=v.hand[0]
						for card in v.hand:
							if card.id in ["plastic","iron","rope"]: chosen=card; break
						s.dispatch("discard",{"uid":chosen.uid})
					else: s.dispatch("discard",{"uid":"coins"})
				"battle":
					var turn: int=s.state.battle.turn
					for heal in v.hand:
						if heal.id=="medkit" and s.state.player.hp<=s.state.player.hp_max-3: s.dispatch("play",{"uid":heal.uid})
					for card in v.hand:
						if card.id == "pollution" and s.state.battle.ap >= 2: s.dispatch("play",{"uid":card.uid})
					for card in v.hand:
						if s.phase() == "battle" and card.id == "arrow": s.dispatch("play",{"uid":card.uid})
					while s.phase() == "battle" and s.state.battle.turn==turn and s.state.battle.ap > 0:
						if not s.dispatch("battle_action",{"action":"attack"}): break
					if s.phase() == "battle" and s.state.battle.turn==turn: s.dispatch("battle_end")
			if s.snapshot() == previous:
				printerr("BLOCK seed=%d phase=%s node=%s step=%s error=%s" % [seed,s.phase(),s.state.node.get("id",""),s.state.story_step,s.error])
				quit(1)
				return
		check(operations < 500,"规则循环不应卡死 seed=%d" % seed)
		if "--settlement-fixtures" in OS.get_cmdline_user_args():
			var evidence := FileAccess.open("res://evidence/settlement-route-%d.json" % seed,FileAccess.WRITE)
			evidence.store_string(JSON.stringify(s.snapshot())); evidence.close()
		print("ROUTE RESULT seed=%d result=%s hp=%d" % [seed,s.state.get("result",""),s.state.player.hp])
		var report: Dictionary = s.state.get("settlement",{})
		check(not report.is_empty() and report.get("complete",false),"完整挑战生成真实统计报告")
		if not report.is_empty():
			check(report.completed==s.state.completed and report.points.granted==s.profile.points,"挑战报告节点与发点一致")
			for row in report.cards:
				var departures: int = row.use_consumed+row.cost_consumed+row.deployed+row.discarded+row.lost+row.cleared
				check(row.obtained==row.remaining+departures,"完整路线卡牌收支守恒 "+row.id)
			check(s.state.stats.completed_ids.size()==s.state.completed,"节点去重账与完成数一致")
			if s.state.stats.cards.has("punch"): check(s.state.stats.cards.punch.use_consumed==0,"回牌出拳不计消耗")
			check(s.state.stats.tags.has("device")==not s.state.stats.battles.is_empty(),"实际设备供给才记成果")
		if s.state.get("result") == "survived" and success_seed == -1:
			success_seed = seed
			print("SUCCESS ROUTE seed=%d voyages=%d nodes=%d hp=%d sanity=%d result=survived" % [seed,s.state.length,s.state.completed,s.state.player.hp,s.state.player.sanity])
			var p: int = s.profile.points
			var saved: Dictionary = s.snapshot()
			var other = load("res://core/game_session.gd").new(catalog)
			check(other.restore(saved),"终局恢复")
			check(other.restore(JSON.parse_string(JSON.stringify(saved))),"完整挑战报告JSON往返")
			check(other.profile.points == p and not other.dispatch("end_voyage"),"终局恢复不重复结算")
		if s.state.get("result") in ["mad","dead"] and failure_seed == -1:
			failure_seed = seed
			print("FAILURE ROUTE seed=%d voyage=%d nodes=%d result=%s" % [seed,s.state.voyage,s.state.completed,s.state.result])
		if success_seed != -1 and failure_seed != -1: break
	check(success_seed != -1,"至少找到一条真实随机候选完成路线")
	check(failure_seed != -1,"至少找到一条生存失败路线")
	print("ROUTES: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
