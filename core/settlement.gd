extends RefCounted
const Stats = preload("res://core/run_statistics.gd")
const SCORE_VERSION := "settlement-score-v2"
const REWARD_VERSION := "completed-nodes-v1"
const OUTCOMES := {"survived":"灯火未熄","true":"回声归航","withdrawn":"离开潮眼","dead":"沉入深潮","mad":"迷失潮声","abandon":"返回岸边","tutorial":"航程入门","A":"成功封闭","B":"付出代价后处理","C":"紧急撤离","SOLO":"独航出口","chapter":"章节完成"}

static func rounded(value: float) -> int:
	# JSON round trips can move exact half points by a few ULPs (e.g. HP10/12).
	return int(floor(value+0.5+1e-9))

static func score(input: Dictionary) -> Dictionary:
	var p: float = clampf(float(input.completed)/maxf(1.0,float(input.length)),0.0,1.0)
	var e: int = int(input.events_entered); var b: int = int(input.battles_entered)
	var re: float = clampf(float(input.events_won)/e,0,1) if e>0 else 1.0
	var rb: float = clampf(float(input.battles_won)/b,0,1) if b>0 else 1.0
	if e==0: re=rb
	if b==0: rb=re
	var parts := {"voyage":rounded(350*p+150*int(input.goal)),"crisis":rounded(p*(150*re+100*rb)),"survival":rounded(p*(75*clampf(float(input.hp),0,1)+45*clampf(float(input.sanity),0,1)+30*clampf(float(input.cells),0,1))),"exploration":rounded(p*25*maxi(int(input.tags),0))}
	var total: int = parts.voyage+parts.crisis+parts.survival+parts.exploration
	var grade: String = "S" if total>=900 else ("A" if total>=750 else ("B" if total>=600 else ("C" if total>=400 else "D")))
	return {"total":total,"grade":grade,"components":parts,"inputs":input.duplicate(true),"progress":p,"event_rate":re,"battle_rate":rb}

static func create(state: Dictionary, catalog, scope: String = "run") -> Dictionary:
	var stats: Dictionary = state.stats.duplicate(true)
	var outcome: String = state.get("result","") if scope=="run" else "chapter"
	var report := {"report_id":state.get("run_id","legacy")+"/"+scope+"/L1","run_id":state.get("run_id","legacy"),"scope":scope,"mode":state.mode,"origin":state.origin,"seed":state.seed,"outcome":outcome,"outcome_name":OUTCOMES.get(outcome,outcome),"completed":state.completed,"length":state.length,"complete":stats.complete,"score_version":SCORE_VERSION,"reward_policy_version":REWARD_VERSION,"fingerprint":catalog.fingerprint(),"score":{},"points":{"granted":state.completed if scope=="run" else 0,"pending":state.completed if scope=="chapter" else 0,"bonus":0},"logs":state.logs.duplicate(true),"stats":stats,"cards":[],"analysis":[]}
	var remaining := {}
	var temporary := {}
	for item in state.hand:
		remaining[item.id]=int(remaining.get(item.id,0))+1
		if item.temporary: temporary[item.id]=int(temporary.get(item.id,0))+1
	if state.coins>0 or stats.cards.has("coin"): remaining.coin=state.coins
	var ids: Array = stats.cards.keys()
	for id in remaining:
		if id not in ids: ids.append(id)
	ids.sort()
	for id in ids:
		var row: Dictionary = stats.cards.get(id,{}).duplicate(true)
		var definition: Dictionary = catalog.entry("cards",id)
		row.merge({"id":id,"name":definition.get("name",id),"kind":definition.get("kind","resource"),"remaining":int(remaining.get(id,0)),"remaining_temporary":int(temporary.get(id,0)),"remaining_permanent":int(remaining.get(id,0))-int(temporary.get(id,0))},true)
		report.cards.append(row)
	report.player=state.player.duplicate(true)
	report.prior_chapters=[]
	if state.has("chapter_report"):
		report.prior_chapters.append({"outcome":state.chapter_report.outcome,"score":state.chapter_report.score.duplicate(true)})
	if not stats.complete:
		report.analysis=["历史统计不完整：本局开始时尚未采集完整行为，未生成正式评分。","涌潮点仍按实际完成节点结算；日志仅展示已经保存的内容。"]
		return report
	var events_won := 0; var battles_won := 0
	for crisis in stats.crises.values():
		if crisis.success: events_won+=1
	for battle in stats.battles.values():
		if battle.outcome=="won": battles_won+=1
	var cells := 0.0
	for id in stats.initial_cells:
		if id in stats.detached: continue
		for cell in state.cells:
			if cell.id==id: cells+=1.0 if cell.status=="intact" else (0.5 if cell.status=="damaged" else 0.0)
	var inputs := {"completed":state.completed,"length":state.length,"goal":scope=="chapter" or outcome in ["survived","true"],"hp":float(state.player.hp)/state.player.hp_max,"sanity":float(state.player.sanity)/state.player.sanity_max,"cells":cells/maxi(1,stats.initial_cells.size()),"events_entered":stats.crises.size(),"events_won":events_won,"battles_entered":stats.battles.size(),"battles_won":battles_won,"tags":stats.tags.size()}
	report.score=score(inputs)
	var costs := 0; var used := 0
	for row in report.cards:
		if row.kind!="currency": costs+=int(row.get("cost_consumed",0)); used+=int(row.get("used",0))
	report.analysis.append("完成%d/%d个日间节点；本局实际入战%d场，胜利%d场。" % [state.completed,state.length,stats.battles.size(),battles_won])
	report.analysis.append("成功使用卡牌%d次，投入%d份卡牌物资作为费用，完成%d种配方。" % [used,costs,stats.crafts.size()])
	report.analysis.append("初始筏格曾脱落%d格；设备实际发挥作用%d次。" % [stats.initial_cells.filter(func(id): return id in stats.detached).size(),int(stats.counters.get("device_uses",0))])
	return report

static func valid_report(report: Variant) -> bool:
	if not report is Dictionary: return false
	if report.is_empty(): return true
	if report.get("score_version")!=SCORE_VERSION: return false
	for field in ["report_id","run_id","scope","mode","origin","outcome","score_version","reward_policy_version"]:
		if not report.get(field) is String: return false
	if report.scope not in ["run","chapter"] or not report.get("complete") is bool or not report.get("logs") is Array or not report.get("cards") is Array or not report.get("analysis") is Array or not report.get("stats") is Dictionary or not report.get("points") is Dictionary or not report.get("score") is Dictionary: return false
	if not Stats.valid({"stats":report.stats}) or report.complete!=report.stats.complete: return false
	for field in ["completed","length","seed"]:
		if not valid_number(report.get(field),true): return false
	if report.completed>report.length or report.length<1: return false
	for field in ["granted","pending","bonus"]:
		if not valid_number(report.points.get(field),true): return false
	if report.points.bonus!=0 or report.points.granted!=(report.completed if report.scope=="run" else 0) or report.points.pending!=(report.completed if report.scope=="chapter" else 0): return false
	for line in report.logs+report.analysis:
		if not line is String: return false
	for card in report.cards:
		if not card is Dictionary or not card.get("id") is String or not card.get("name") is String or not card.get("kind") is String: return false
	if report.complete:
		if not report.score.get("inputs") is Dictionary: return false
		for field in ["completed","length","goal","hp","sanity","cells","events_entered","events_won","battles_entered","battles_won","tags"]:
			if not report.score.inputs.has(field): return false
			if field=="goal":
				if not report.score.inputs.goal is bool: return false
			elif not valid_number(report.score.inputs[field],field not in ["hp","sanity","cells"]): return false
		var expected := score(report.score.inputs)
		if report.score.inputs.completed!=report.completed or report.score.inputs.length!=report.length or report.score.inputs.goal!=(report.scope=="chapter" or report.outcome in ["survived","true"]): return false
		if report.score.inputs.tags!=report.stats.get("tags",[]).size(): return false
		if report.score.get("total")!=expected.total or report.score.get("grade")!=expected.grade or not report.score.get("components") is Dictionary: return false
		for key in expected.components:
			if report.score.components.get(key)!=expected.components[key]: return false
	return true

static func valid_number(value, integer: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and (not integer or floor(float(value))==float(value))
