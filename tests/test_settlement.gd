extends SceneTree
var failures := 0
func same(a, b) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not same(a[i],b[i]): return false
		return true
	return a==b
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func _init() -> void:
	var c = load("res://content/catalog.gd").new(); check(c.load_catalog(),"内容")
	var s = load("res://core/game_session.gd").new(c)
	check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"新局")
	check(s.state.has("stats"),"新局应采集真实统计")
	if not s.state.has("stats"):
		quit(1); return
	var before: Dictionary = s.snapshot()
	var previous: Dictionary=before.duplicate(true); previous.content_version="godot-flow-v02-20"
	check(not s.restore(previous) and same(s.snapshot(),before),"拒绝v20旧档且保持当前会话")
	check(not s.dispatch("voyage",{"id":"missing"}) and s.snapshot()==before,"拒绝命令不改变统计")
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"实际出发")
	s.change("hydration",int(s.state.player.hydration_max)-30-int(s.state.player.hydration),"test_fixture")
	s.give("water"); var uid: String = s.state.hand[-1].uid
	check(s.dispatch("play",{"uid":uid}),"实际饮水")
	check(s.state.stats.cards.water.used==1 and s.state.stats.cards.water.use_consumed==1,"使用与消耗")
	check(s.state.stats.counters.get("recovery_overflow",0)>0,"饮水溢出单独记录")
	check(s.state.stats.attribute_sources.hydration.play.restored==30,"恢复来源与有效值")
	s.give("wood",1); s.give("plastic",2)
	check(s.dispatch("craft",{"id":"filter"}),"实际合成")
	check(s.state.stats.cards.plastic.cost_consumed==2,"材料按份记录")
	uid=s.state.hand[-1].uid
	check(s.dispatch("install",{"cell":s.state.cells[0].id,"uid":uid}),"实际安装")
	check(s.state.stats.cards.filter.deployed==1 and s.state.stats.cards.filter.used==0,"安装独立于出牌")
	s.give("water",2,false,"production","filter",s.state.cells[0].id)
	check(s.state.stats.devices["filter/"+s.state.cells[0].id].outputs.water==2,"按设备和格记录实际产物")
	check(s.dispatch("abandon"),"放弃结算")
	var report: Dictionary = s.state.get("settlement",{})
	check(not report.is_empty(),"终局生成报告")
	check(report.get("complete",false),"新局报告完整")
	var high_report: Dictionary=report.duplicate(true)
	high_report.completed=high_report.length; high_report.outcome="survived"
	high_report.stats.tags=["exploration","craft","device","investigation","quest"]
	high_report.score.inputs.merge({"completed":high_report.length,"goal":true,"hp":1.0,"sanity":1.0,"cells":1.0,"events_entered":0,"battles_entered":0,"tags":5},true)
	high_report.score=s.Settlement.score(high_report.score.inputs)
	high_report.points.granted=high_report.completed
	check(high_report.score.total==1025 and s.Settlement.valid_report(JSON.parse_string(JSON.stringify(high_report))),"超过千分的报告经JSON仍可校验")
	var old_score_report: Dictionary=report.duplicate(true); old_score_report.score_version="settlement-score-v1"
	check(not s.Settlement.valid_report(old_score_report),"拒绝旧评分报告，不静默重算")
	check(report.get("points",{}).get("granted",-1)==s.state.completed,"节点发点保持")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.snapshot()))
	var copy = load("res://core/game_session.gd").new(c)
	var recovered: bool = copy.restore(saved)
	check(recovered,"报告JSON恢复")
	if not recovered:
		print("DIAG stats=",s.Stats.valid(saved.state)," report=",s.Settlement.valid_report(saved.state.settlement)," last=",s.Settlement.valid_report(saved.last_settlement))
		print("DIAG original_report=",s.Settlement.valid_report(report)," expected=",s.Settlement.score(saved.state.settlement.score.inputs)," actual=",saved.state.settlement.score)
		print("DIAG schema membership=",saved.schema in [1,2]," node=",s.Rules.valid_node(s,saved.state.node,saved.state.mode)," campaign=",s.Campaign.valid_save(s,saved.state))
		quit(1); return
	var points: int = copy.profile.points
	var corrupt: Dictionary = saved.duplicate(true); corrupt.state.settlement.score.total=999
	check(not copy.restore(corrupt),"拒绝与公式不符的结算报告")
	corrupt=saved.duplicate(true); corrupt.state.stats.counters.base_ap_spent="invalid"
	check(not copy.restore(corrupt),"拒绝异常统计字段")
	corrupt=saved.duplicate(true); corrupt.state.settlement={}
	check(not copy.restore(corrupt),"拒绝空终局报告")
	corrupt=saved.duplicate(true); corrupt.state.chapter_report={}
	check(not copy.restore(corrupt),"拒绝空章节归档")
	corrupt=saved.duplicate(true); corrupt.state.settlement.score.inputs.completed=12; corrupt.state.settlement.score=copy.Settlement.score(corrupt.state.settlement.score.inputs)
	check(not copy.restore(corrupt),"拒绝完成节点与评分进度矛盾")
	corrupt=saved.duplicate(true); corrupt.state.stats.tags=["craft","craft"]
	check(not copy.restore(corrupt),"拒绝重复成果标签")
	corrupt=saved.duplicate(true); corrupt.state.stats.initial_cells.append(corrupt.state.stats.initial_cells[0])
	check(not copy.restore(corrupt),"拒绝重复基础格身份")
	var battle_fixture: Dictionary=before.duplicate(true)
	battle_fixture.state.phase="story"; battle_fixture.state.story_step="choice"; battle_fixture.state.candidates=[]
	battle_fixture.state.node=c.entry("nodes","battle"); battle_fixture.state.node.visit_id="battle-stats-fixture"
	var battling=load("res://core/game_session.gd").new(c)
	check(battling.restore(battle_fixture),"战斗统计夹具")
	check(battling.dispatch("fight") and battling.dispatch("battle_end") and battling.dispatch("battle_end"),"实际进入第三战斗回合")
	check(battling.dispatch("abandon"),"战斗中放弃")
	check(battling.state.settlement.stats.battles["battle-stats-fixture/battle"].turns==3,"未完成战斗也记录实际回合")
	check(copy.dispatch("home") and copy.dispatch("resume"),"回看")
	check(same(copy.state.settlement,report) and copy.profile.points==points,"报告不重算不重发")
	var projected: Dictionary = copy.view(); projected.settlement.logs.clear()
	check(same(copy.state.settlement,report),"只读投影隔离")
	check(copy.dispatch("home") and copy.dispatch("new",{"mode":"challenge","origin":"strong","seed":23}),"下一局")
	check(same(copy.get("last_settlement"),report),"下一局保留最近报告")
	var legacy: Dictionary = before.duplicate(true)
	legacy.schema=1; legacy.content_version="godot-flow-v02-3"
	# Synthetic v3 migration fixtures must carry v3's accepted fingerprint,
	# rather than the current content fingerprint inherited from `before`.
	legacy.fingerprint=c.prior_flow_fingerprint()
	legacy.state.erase("stats"); legacy.state.erase("run_id"); legacy.erase("last_settlement")
	var before_reject: Dictionary=copy.snapshot()
	check(not copy.restore(legacy) and same(copy.snapshot(),before_reject),"旧活动档拒绝且不覆盖当前会话")
	var old_finished: Dictionary=saved.duplicate(true)
	old_finished.schema=1; old_finished.content_version="godot-flow-v02-3"
	old_finished.fingerprint=c.prior_flow_fingerprint()
	old_finished.state.erase("stats"); old_finished.state.erase("run_id"); old_finished.state.erase("settlement"); old_finished.erase("last_settlement")
	check(not copy.restore(old_finished),"旧终局版本拒绝")
	check(same(copy.snapshot(),before_reject),"拒绝旧终局不改积分或状态")
	if ResourceLoader.exists("res://core/settlement.gd"):
		var scoring = load("res://core/settlement.gd")
		var fixture := {"completed":12,"length":12,"goal":true,"hp":0.8,"sanity":0.7,"cells":1.0,"events_entered":0,"events_won":0,"battles_entered":0,"battles_won":0,"tags":3}
		check(scoring.score(fixture).total==947,"设计947分夹具")
		fixture.merge({"completed":8,"goal":false,"hp":0.0,"sanity":0.5,"cells":0.5,"events_entered":2,"events_won":1,"battles_entered":2,"battles_won":1,"tags":2},true)
		check(scoring.score(fixture).total==374,"设计374分夹具")
		fixture.merge({"completed":12,"goal":false,"hp":1.0,"sanity":1.0,"cells":1.0,"events_entered":4,"events_won":3,"battles_entered":4,"battles_won":3,"tags":3},true)
		check(scoring.score(fixture).total==763,"设计撤离763分夹具")
		fixture.merge({"completed":15,"length":15,"goal":true,"hp":0.6,"sanity":0.4,"cells":0.5,"events_entered":0,"events_won":0,"battles_entered":0,"battles_won":0,"tags":4},true)
		check(scoring.score(fixture).total==928,"设计章节928分夹具")
		fixture.merge({"hp":1.0,"sanity":1.0,"cells":1.0,"tags":5},true)
		check(scoring.score(fixture).total==1025 and scoring.score(fixture).components.exploration==125,"第五项成果继续计分，总分可超过1000")
		fixture.tags=8
		check(scoring.score(fixture).total==1100 and scoring.score(fixture).grade=="S","成果计分无人工上限，评级阈值保持")
		fixture.completed=8
		check(scoring.score(fixture).components.exploration==107,"未完成航程仍按推进比例计算全部成果")
		fixture.completed=0; fixture.goal=false
		check(scoring.score(fixture).total==0,"零推进不刷成果分")
	else: check(false,"独立评分模块")
	print("SETTLEMENT: "+("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
