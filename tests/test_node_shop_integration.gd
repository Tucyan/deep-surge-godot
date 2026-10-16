extends SceneTree
var failures := 0
var checks := 0
var catalog
const Session = preload("res://core/game_session.gd")
const Query = preload("res://core/action_query.gd")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func same(a, b) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a)))==JSON.stringify(JSON.parse_string(JSON.stringify(b)))
func fixture(id: String, variant: String = ""):
	var s=Session.new(catalog); s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	s._auto_advancing=true; s.state.phase="story"; s.state.story_step="choice"; s.state.hand=[]
	s.state.voyage=7; s.state.environment.rolled_voyage=7; s.state.node=catalog.entry("nodes",id)
	if variant!="":
		for v in s.state.node.variants:
			if v.id==variant: s.state.node.merge(v,true); s.state.node.id=id; s.state.node.variant_id=variant; break
	s.state.node.erase("variants"); s.state.node.visit_id="integration-visit"
	s.state.candidates=[]; s.Encounter.arrived(s)
	return s
func test_saved_stages() -> void:
	var s=fixture("storm","hold")
	check(s.dispatch("option",{"id":"take"}),"真实货舱领取首袋")
	var snapshot=s.snapshot(); var copy=Session.new(catalog)
	check(copy.restore(JSON.parse_string(JSON.stringify(snapshot))),"分段同版本JSON恢复")
	check(copy.state.encounter.stage==1 and copy.state.hand.size()==1,"阶段和首袋保留")
	copy._auto_advancing=true
	var before=copy.snapshot()
	check(not copy.dispatch("option",{"id":"take"}) and copy.snapshot()==before,"读档后不能重复首袋")
	check(s.dispatch("option",{"id":"continue"}) and copy.dispatch("option",{"id":"continue"}),"读档两边继续")
	check(same(s.state.rng,copy.state.rng) and same(s.state.hand,copy.state.hand) and same(s.state.encounter,copy.state.encounter),"相同保存点随机结果相同")
	var bad=snapshot.duplicate(true); bad.state.encounter.stage=99
	check(not copy.restore(bad),"拒绝不存在的事件阶段")
func test_battle_rewards() -> void:
	var s=fixture("duel")
	check(s.dispatch("option",{"id":"elite"}),"选项进入实际强敌战斗")
	check(s.state.battle.id=="crab_elite" and s.state.battle.hp==12,"新敌人数值")
	var copy=Session.new(catalog)
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"强敌战斗保存恢复")
	var bad=s.snapshot(); bad.state.battle.rewards.coin=999; bad.state.encounter={}
	check(not copy.restore(bad),"清空事件运行时也不能伪造战斗奖励")
	var steps := 0
	while s.phase()=="battle" and steps<40:
		steps+=1
		check(s.dispatch("battle_action",{"action":"attack"}) if s.state.battle.ap>0 else s.dispatch("battle_end"),"真实行动完成强敌")
	check(s.phase()=="story" and s.state.story_step=="result","胜利返回结果文字")
	check(s.state.coins==2 and s.I.count(s.state,"corpse")==1 and s.state.hand.size()==3,"仅发总奖励2币1尸2资源")
func test_shop_commands() -> void:
	var s=fixture("trader")
	check(s.dispatch("shop_enter"),"统一入口创建商店")
	var saved=s.snapshot(); var view=s.view(); var copy=Session.new(catalog)
	check(view.shop.stock.size()==6 and view.shop.relic_slots==3,"公开九位货架")
	check(copy.restore(JSON.parse_string(JSON.stringify(saved))),"商店同版本恢复")
	check(same(copy.state.shop,s.state.shop) and same(copy.state.rng,s.state.rng),"恢复不刷新货架")
	s.give("corpse"); var uid: String=s.state.hand[-1].uid
	check(s.dispatch("sell",{"uid":uid,"revision":s.revision}),"真实出售指令")
	check(s.state.coins==2 and s.state.stats.cards.corpse.sold==1,"出售统计与币余额")
	var resource: String=s.state.shop.stock[0]
	check(s.dispatch("buy",{"id":resource}),"购买在架资源")
	check(s.state.coins==1 and s.state.shop.purchased[resource]==1,"真实扣费及库存")
	var priced_save: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()))
	check(copy.restore(priced_save),"购买后同版本保存恢复")
	check(copy.Shop.view(copy).stock.filter(func(row):return row.kind=="resource").all(func(row):return row.price==2),"读档保持全部资源共享二币价")
	check(same(copy.Shop.view(copy),s.Shop.view(s)) and same(copy.state.rng,s.state.rng),"读档不刷新货架、售价和随机")
	var before=s.snapshot()
	check(not s.dispatch("buy",{"id":resource,"revision":s.revision-1}) and s.snapshot()==before,"过期交易完全回滚")
	check(s.dispatch("shop_leave") and s.state.story_step=="result","离店恢复节点结果")
	check(s.dispatch("advance") and s.state.completed==1,"单访问仅完成一次")
func test_candidates() -> void:
	for seed in [0,1,2,7,22,42]:
		var s=Session.new(catalog); check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":seed}),"新候选开局")
		check(s.state.candidates.size()<=3 and s.state.candidates.size()>0,"候选1至3项")
		check(s.state.candidates.any(func(n): return s.Encounter.free_benefit(s,n,true)),"前两轮有免费食水选择")
		check(not s.state.candidates.any(func(n):return n.id=="altar" or n.id=="boss" or n.get("min_voyage",1)>1),"退休或过早节点不出现")
		var bad=s.snapshot(); var replacement=catalog.entry("nodes","duel")
		replacement.visit_id=bad.state.candidates[0].visit_id; bad.state.candidates[0]=replacement
		var loaded=Session.new(catalog)
		check(not loaded.restore(bad),"存档也拒绝尚未到航次的候选")
		replacement=catalog.entry("nodes","boss"); replacement.visit_id=bad.state.candidates[0].visit_id
		bad.state.candidates[0]=replacement
		check(not loaded.restore(bad),"不能通过保存候选提前进入Boss")
	var s=fixture("camp"); var node=s.state.node.duplicate(true)
	check(not s.Encounter.eligible(s,node),"冷却期内同事件不合格")
func test_risk_statistics() -> void:
	var safe=fixture("storm","surface")
	check(safe.dispatch("option",{"id":"leave"}) and safe.state.stats.crises.is_empty(),"安全绕行不登记风险失败")
	var cargo=fixture("storm","hold")
	check(cargo.dispatch("option",{"id":"take"}) and cargo.state.stats.crises.is_empty(),"首袋免费不登记风险")
	cargo.state.rng.rewards.value=1
	check(cargo.dispatch("option",{"id":"continue"}),"接受第一段真实风险")
	check(cargo.state.encounter.stage==2 and cargo.state.stats.crises.size()==1,"成功深入后可继续或收手")
	check(cargo.dispatch("option",{"id":"leave"}),"风险后可主动收手")
	var crisis: Dictionary=cargo.state.stats.crises.values()[0]
	check(crisis.success and crisis.resolved and crisis.outcome=="stopped","主动收手保留奖励且不算失败")
	var fallback=fixture("fallback")
	check(fallback.state.stats.counters.get("fallback_visits",0)==1,"回退节点有诊断计数")
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"内容加载")
	test_saved_stages(); test_battle_rewards(); test_shop_commands(); test_candidates(); test_risk_statistics()
	print("NODE SHOP INTEGRATION: %s (%d checks, %d failures)" % ["PASS" if failures==0 else "FAIL",checks,failures])
	quit(failures)
