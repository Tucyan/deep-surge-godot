extends SceneTree
const Session=preload("res://core/game_session.gd")
const Query=preload("res://core/action_query.gd")
const Rewards=preload("res://core/relic_rewards.gd")
var failures:=0
var checks:=0
var catalog
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func same(a, b) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a)))==JSON.stringify(JSON.parse_string(JSON.stringify(b)))
func fixture(id: String, changes: Dictionary = {}):
	# Synthetic content exercises dispatch and exact-definition save validation.
	var local_catalog=catalog.get_script().new()
	local_catalog._tables=catalog._tables.duplicate(true)
	local_catalog._fingerprint=catalog.fingerprint()
	local_catalog._tables.nodes[id].merge(changes,true)
	local_catalog._tables=JSON.parse_string(JSON.stringify(local_catalog._tables))
	var s=Session.new(local_catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	s._auto_advancing=true; s.state.phase="story"; s.state.story_step="choice"
	# Manual arrival keeps the legal current journey/weather and departure lock.
	s.state.node=local_catalog.entry("nodes",id); s.state.node.visit_id="reward-test"
	s.state.candidates=[]; s.Encounter.arrived(s)
	return s
func test_event() -> void:
	var s=fixture("camp",{"options":[{"id":"take","name":"取走遗物","cost":0,"effects":[{"type":"GiveRelic","id":"crimsonVial"}]}]})
	var before=s.snapshot(); s.view(); Query.list_actions(s)
	check(s.snapshot()==before,"事件查看和行动报价不改变状态或随机")
	check(s.dispatch("option",{"id":"take"}),"事件允许获得指定遗物")
	check(s.state.collectibles.items.size()==1,"事件创建独立遗物实例")
	check(s.state.player.hp_max==before.state.player.hp_max+3,"获得时永久上限生效")
	check("relic.crimsonVial" in s.profile.discovered,"事件发放登记图鉴")
	check(s.state.rng.rewards==before.state.rng.rewards,"固定遗物不额外耗随机")
	var copy=Session.new(s.catalog)
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"事件发奖后保存恢复")
	before=s.snapshot()
	check(not s.dispatch("option",{"id":"take"}) and s.snapshot()==before,"同一事件奖励不能重复领取")
func test_battle() -> void:
	var s=fixture("battle",{"rewards":{"coin":0,"corpse":0,"resources":0,"xp":0,"relics":[{"id":"barbedBundle"}]}})
	check(s.dispatch("fight"),"普通战斗带奖励进入")
	var copy=Session.new(s.catalog)
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"普通战斗奖励保存恢复")
	var bad=s.snapshot(); bad.state.battle.rewards.relics[0].id="sailorsKnot"
	check(not copy.restore(bad),"拒绝篡改战斗遗物奖励")
	s.state.battle.hp=1
	check(s.dispatch("battle_action",{"action":"attack"}),"实际胜利发奖")
	check(s.state.collectibles.items.size()==1,"战斗创建遗物实例")
	check(s.state.hand.all(func(card):return not card.temporary),"战后获得矛匣不补发本场临时矛")
	check("relic.barbedBundle" in s.profile.discovered,"战斗发放登记图鉴")
	var before=s.snapshot()
	check(not s.dispatch("battle_action",{"action":"attack"}) and s.snapshot()==before,"胜利奖励不能重复领取")
	check(s.dispatch("advance"),"确认战斗结果")
	check(s.dispatch("discard_collectible",{"uid":s.state.collectibles.items[0].uid}),"战斗遗物可正常丢弃")
	var retreat=fixture("battle",{"rewards":{"relics":[{"id":"sailorsKnot"}]}})
	check(retreat.dispatch("fight") and retreat.dispatch("battle_end") and retreat.dispatch("retreat"),"实际撤退")
	check(retreat.state.collectibles.items.is_empty(),"撤退不发遗物")
func test_random_and_restore() -> void:
	var offer={"id":"take","name":"漂来的礼物","cost":0,"effects":[{"type":"GiveRandomRelic","pool":["sealedFishTin","sailorsKnot"],"amount":3}]}
	var s=fixture("camp",{"options":[offer]})
	var before=s.snapshot(); var preview=s.Encounter.reward_preview(offer)
	check(preview.relics==[{"pool":["sealedFishTin","sailorsKnot"],"amount":3}],"随机预览只包含范围和数量")
	var probe=Query.fork(s)
	check(probe.dispatch("option",{"id":"take"}) and probe.state.rng.rewards==s.state.rng.rewards and probe.state.collectibles.items.is_empty(),"报价副本不抽取或泄露随机遗物")
	var copy=Session.new(s.catalog)
	check(copy.restore(JSON.parse_string(JSON.stringify(before))),"事件奖励领取前保存恢复")
	copy._auto_advancing=true
	check(s.dispatch("option",{"id":"take"}) and copy.dispatch("option",{"id":"take"}),"读档两侧领取随机奖励")
	check(s.state.collectibles.items.size()==2 and s.state.collectibles.next_id==3 and s.state.coins==2,"run与held唯一遗物各发一次，耗尽请求兑换贝币")
	check(same(s.state.collectibles,copy.state.collectibles) and same(s.state.rng,copy.state.rng),"同保存点随机奖励完全一致")
	check(int(s.state.rng.rewards.cursor)==int(before.state.rng.rewards.cursor)+2,"唯一筛选后仅对实际遗物奖励抽取随机")
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"随机发奖后保存恢复")
	var single=fixture("camp",{"options":[{"id":"take","name":"补给","effects":[{"type":"GiveRandomRelic","pool":["crimsonVial"],"amount":2}]}]})
	var base_max: int=single.state.player.hp_max
	check(single.dispatch("option",{"id":"take"}) and single.state.player.hp_max==base_max+3 and single.state.coins==2,"run唯一遗物只获得一次，剩余请求兑换贝币")

func test_unique_random_pool() -> void:
	var entry={"pool":["crimsonVial","sailorsKnot"],"amount":3}
	var s=fixture("camp",{"options":[{"id":"take","name":"随机遗物","effects":[]} ]})
	var summary: Array=[]
	check(Rewards.grant(s,[entry],summary),"唯一过滤后的随机奖励仍成功")
	check(s.state.collectibles.items.size()==2,"随机池内run唯一只发一次，held唯一可重复直到持有")
	check(s.state.coins==2,"随机池耗尽时每个剩余请求兑换2贝币")
	check(summary.size()==3 and summary[-1].contains("贝币2枚"),"随机池耗尽的兑换写入可见奖励摘要")
	check(s.state.rng.rewards.cursor==2,"耗尽的随机请求不额外抽取随机数")
	var exhausted=fixture("camp",{"options":[]})
	var relics: Array=[]
	for item in ["crimsonVial","sealedFishTin","tideTablet","copperStill","rescueBadge","redCoral"]:
		check(Collectibles.acquire(exhausted,item),"预先获得run唯一遗物 "+item)
	var cursor=int(exhausted.state.rng.rewards.cursor); var coins=exhausted.state.coins
	summary=[]
	check(Rewards.grant(exhausted,[{"pool":["crimsonVial","sealedFishTin"],"amount":2}],summary),"run唯一池全部耗尽仍成功")
	check(exhausted.state.coins==coins+4 and exhausted.state.rng.rewards.cursor==cursor,"全部耗尽按请求兑换且不消耗随机数")

const Collectibles=preload("res://core/collectible_rules.gd")
func test_event_battle_and_stages() -> void:
	var rewards={"coin":0,"corpse":0,"resources":0,"xp":0,"relics":[{"pool":["drifterQuiver"],"amount":1}]}
	var offer={"id":"fight","name":"守护者","battle":{"enemy":"biter","rewards":rewards},"effects":[]}
	var s=fixture("duel",{"options":[offer]})
	check(s.dispatch("option",{"id":"fight"}),"事件选项进入遗物奖励战斗")
	var copy=Session.new(s.catalog)
	check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"事件战斗奖励保存恢复")
	s.state.battle.hp=1
	check(s.dispatch("battle_action",{"action":"attack"}) and s.state.collectibles.items.size()==1,"事件战斗胜利随机发放遗物")
	if not s.state.collectibles.items.is_empty():
		var runtime: Dictionary=s.state.collectibles.items[0].effects.values()[0]
		check(runtime.remaining==2 and not runtime.active,"新获得临时血量遗物次数保留到下场")
	var staged=fixture("camp",{"stages":[[offer]],"options":[]})
	check(staged.dispatch("option",{"id":"fight"}),"分段事件战斗进入")
	copy=Session.new(staged.catalog)
	check(copy.restore(JSON.parse_string(JSON.stringify(staged.snapshot()))),"分段事件战斗也验证原奖励定义")
	var outcome=fixture("camp",{"options":[{"id":"take","name":"宝箱","outcomes":[{"weight":1,"effects":[{"type":"GiveRelic","id":"sailorsKnot"}]}]}]})
	check(outcome.dispatch("option",{"id":"take"}) and outcome.state.collectibles.items.size()==1,"事件随机结果分支允许发放遗物")
func test_invalid() -> void:
	var definitions: Dictionary=catalog.table("relics")
	for entry in [{"id":"missing"},{"id":"guardian"},{"pool":[]},{"pool":["sailorsKnot","missing"]},{"pool":["sailorsKnot","sailorsKnot"]},{"id":"sailorsKnot","amount":0},{"id":"sailorsKnot","amount":1.5},{"id":"sailorsKnot","amount":true},{"id":"sailorsKnot","pool":["sailorsKnot"]}]:
		check(not Rewards.valid_rewards(definitions,{"relics":[entry]}),"拒绝无效奖励："+JSON.stringify(entry))
	check(not Rewards.valid_content(definitions,{"variants":[{"stages":[[{"outcomes":[{"effects":[{"type":"GiveRandomRelic","pool":[]}]}]}]]}]}),"内容校验覆盖嵌套随机结果")
	check(not Rewards.valid_rewards(definitions,{"relics":"sailorsKnot"}),"奖励列表必须为数组")
	var s=fixture("camp",{"options":[{"id":"take","name":"坏奖励","cost":1,"effects":[{"type":"GiveCard","id":"wood"},{"type":"GiveRelic","id":"missing"}]}]})
	var before=s.snapshot()
	check(not s.dispatch("option",{"id":"take"}) and s.snapshot()==before,"非法事件奖励无扣费、无发卡、无随机变化")
	s=fixture("battle",{"rewards":{"relics":[{"pool":[]}]}}); before=s.snapshot()
	check(not s.dispatch("fight") and s.snapshot()==before,"非法战斗奖励在进入前拒绝并回滚")
func agent_execute(agent, command: String, args: Dictionary = {}) -> bool:
	for action in agent.handle({"method":"actions"}).data.actions:
		if action.command!=command: continue
		var matches:=true
		for key in args:
			if action.args.get(key)!=args[key]: matches=false
		if matches: return agent.handle({"method":"act","params":{"action_id":action.action_id,"revision":action.revision}}).ok
	return false
func test_agent_routes() -> void:
	for id in ["camp","battle"]:
		var content=catalog.get_script().new(); content._tables=catalog._tables.duplicate(true)
		# Content fixture only; after reset every action goes through public Agent IDs.
		for node in content._tables.nodes:
			if node not in [id,"boss","fallback"]: content._tables.nodes[node].retired=true
		if id=="camp": content._tables.nodes[id].options=[{"id":"take","name":"取走遗物","effects":[{"type":"GiveRandomRelic","pool":["sailorsKnot","barbedBundle"]}]}]
		else:
			content._tables.nodes[id].rewards={"relics":[{"id":"drifterQuiver"}]}
			# Synthetic route explicitly permits this reward battle on opening voyage.
			# Production B pools retain their safe-voyage minimum.
			for entry in content._tables.node_pools.shallows.entries:
				if entry.node==id: entry.min_voyage=1
		content._tables=JSON.parse_string(JSON.stringify(content._tables))
		content._fingerprint=JSON.stringify(content._tables).sha256_text()
		var agent=load("res://adapters/agent_session.gd").new(content)
		check(agent.handle({"method":"reset","params":{"seed":22}}).ok,"Agent奖励路线公开开局")
		var obs: Dictionary=agent.handle({"method":"observe"}).data
		var candidates: Array=obs.candidates.filter(func(node):return node.id==id)
		check(not candidates.is_empty(),"Agent可选测试节点")
		if candidates.is_empty(): continue
		check(agent_execute(agent,"voyage",{"id":candidates[0].visit_id}) and agent_execute(agent,"enter") and agent_execute(agent,"advance"),"Agent真实航行进入奖励节点")
		if id=="camp": check(agent_execute(agent,"option",{"id":"take"}),"Agent真实事件发奖")
		else:
			check(agent_execute(agent,"fight"),"Agent真实进入战斗")
			for step in range(30):
				obs=agent.handle({"method":"observe"}).data
				if obs.phase!="battle": break
				check(agent_execute(agent,"battle_action",{"action":"attack"}) if obs.battle.ap>0 else agent_execute(agent,"battle_end"),"Agent真实战斗行动")
		obs=agent.handle({"method":"observe"}).data
		check(obs.collectibles.size()==1,"Agent观察到节点/战斗获得遗物")
		if obs.collectibles.is_empty(): continue
		check(agent_execute(agent,"advance") and agent_execute(agent,"discard_collectible",{"uid":obs.collectibles[0].uid}),"Agent可丢弃奖励遗物")
		var trace: Dictionary=agent.handle({"method":"trace"}).data
		var replay: Dictionary=agent.handle({"method":"replay","params":{"trace":JSON.parse_string(JSON.stringify(trace))}})
		check(replay.ok and replay.data.steps==trace.steps.size(),"Agent获得/丢弃完整路线逐步重放一致")
		print("RELIC REWARD AGENT ",id,": ",trace.steps.size()," steps (synthetic content)")
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"内容加载")
	test_event(); test_battle(); test_random_and_restore(); test_unique_random_pool(); test_event_battle_and_stages(); test_invalid(); test_agent_routes()
	print("RELIC REWARDS: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(failures)
