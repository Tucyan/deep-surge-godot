extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	if not ResourceLoader.exists("res://adapters/agent_session.gd"):
		check(false,"缺少Agent会话适配器"); quit(1); return
	var catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	var agent=load("res://adapters/agent_session.gd").new(catalog)
	check(not agent.handle({"method":"observe"}).ok,"未开始不能观察")
	for request in [null,[],{"method":3},{"method":"unknown"},{"method":"reset","params":{"seed":"bad"}},{"method":"reset","params":{"seed":false}}]:
		check(not agent.handle(request).ok,"拒绝错误请求")
	var reset: Dictionary=agent.handle({"id":1,"method":"reset","params":{"seed":22,"mode":"challenge","origin":"strong"}})
	check(reset.ok and reset.id==1 and reset.protocol=="deep-surge-agent-v1","重置并返回协议和请求ID")
	var observation: Dictionary=agent.handle({"method":"observe"}).data
	check(observation.phase=="navigation" and not observation.has("rng") and not observation.has("pool") and not observation.has("seed") and not observation.has("stats") and not observation.has("screen"),"玩家观察不含内部随机/调试/UI状态")
	var before: Dictionary=agent._session.snapshot()
	var choices: Array=agent.handle({"method":"actions"}).data.actions
	check(agent.handle({"method":"actions"}).data.actions==choices and agent._session.snapshot()==before,"重复查询不改变快照")
	var move: Dictionary={}
	for action in choices:
		if action.command=="voyage": move=action; break
	check(not move.is_empty(),"可选择航行")
	for params in [{"action_id":move.action_id},{"action_id":move.action_id,"revision":-1},{"action_id":move.action_id,"revision":true},{"action_id":"missing","revision":observation.revision}]:
		check(not agent.handle({"method":"act","params":params}).ok and agent._session.snapshot()==before,"拒绝非法/过期操作且不写入")
	var acted: Dictionary=agent.handle({"method":"act","params":{"action_id":move.action_id,"revision":observation.revision}})
	check(acted.ok and acted.data.observation.phase=="preparation","执行真实航行")
	check(not agent.handle({"method":"act","params":{"action_id":move.action_id,"revision":observation.revision}}).ok,"拒绝重复旧操作")
	var trace: Dictionary=agent.handle({"method":"trace"}).data
	check(trace.steps.size()==1 and trace.steps[0].command=="voyage" and trace.steps[0].args.has("id"),"轨迹保存完整参数")
	var replay=load("res://adapters/agent_session.gd").new(catalog)
	check(replay.handle({"method":"replay","params":{"trace":JSON.parse_string(JSON.stringify(trace))}}).ok,"JSON往返后重放成功")
	check(agent.state_hash(replay._session)==agent.state_hash(agent._session),"JSON数值归一后重放恢复全部规则/随机/统计")
	var replay_before: Dictionary=replay._session.snapshot()
	trace.steps[0].args.id="missing"
	check(not replay.handle({"method":"replay","params":{"trace":trace}}).ok and replay._session.snapshot()==replay_before,"损坏轨迹不污染会话")
	check(agent.handle({"method":"result"}).data.terminal==false,"未终局结果明确")
	# Compare adapter operation with the human dispatch entry, including auto progression.
	var query=load("res://core/action_query.gd")
	var direct=query.fork(agent._session); direct._auto_advancing=false
	var choices2: Array=agent.handle({"method":"actions"}).data.actions
	var chosen: Dictionary={}
	for action in choices2:
		if action.command=="enter": chosen=action; break
	check(direct.dispatch(chosen.command,chosen.args),"直接命令执行")
	check(agent.handle({"method":"act","params":{"action_id":chosen.action_id,"revision":agent._session.revision}}).ok,"Agent相同命令执行")
	check(agent._session.snapshot()==direct.snapshot(),"Agent和玩家操作同一规则结果")
	# Let strategies preserve specific materials rather than consuming defaults.
	check(agent.handle({"method":"reset","params":{"seed":22,"starting_resources":["wood","wood","iron","iron","rope"]}}).ok,"自选资源开局")
	var transmute: Dictionary={}
	for action in agent.handle({"method":"actions"}).data.actions:
		if action.command=="transmute" and action.args.target=="wood": transmute=action; break
	check(transmute.get("parameters",{}).has("uids"),"转化提供受限投入选择")
	var inputs: Array=[]
	for card in agent._session.state.hand:
		if card.id!="wood": inputs.append(card.uid)
	var input_before: Dictionary=agent._session.snapshot()
	for arguments in [[],{"uids":"wrong"},{"uids":[inputs[0],inputs[0],inputs[0]]},{"uids":["missing","bad","other"]},{"uids":[inputs[0]]},{"target":"iron"}]:
		var bad: Dictionary=agent.handle({"method":"act","params":{"action_id":transmute.action_id,"revision":agent._session.revision,"arguments":arguments}})
		check(not bad.ok and agent._session.snapshot()==input_before,"非法投入参数拒绝且不改状态")
	var selected_result: Dictionary=agent.handle({"method":"act","params":{"action_id":transmute.action_id,"revision":agent._session.revision,"arguments":{"uids":inputs}}})
	check(selected_result.ok and agent._session.I.count(agent._session.state,"wood")==4,"按Agent指定投入保留木头")
	check(replay.handle({"method":"replay","params":{"trace":agent.handle({"method":"trace"}).data}}).ok,"含参数选择的轨迹可重放")
	# Enemy intent and damage are visible in the normal battle UI.
	agent._session.state.node=catalog.entry("nodes","battle"); agent._session.state.node.monster="jelly"; agent._session.state.node.visit_id="observation-fixture"
	agent._session.state.phase="story"; agent._session.state.story_step="choice"
	check(agent._session.dispatch("fight"),"观察战斗夹具")
	var enemy: Dictionary=agent.handle({"method":"observe"}).data.get("enemy",{})
	check(enemy.get("damage",-1)==1 and enemy.get("intent","")!="" and enemy.get("buff","")=="poisoned","观察包含玩家可见敌方伤害/意图/状态说明")
	check(agent.handle({"method":"observe"}).data.get("battle_combinations",{}).get("wood",{}).get("block",{}).get("shield",-1)==2,"观察包含公开的资源行动组合数值")
	print("AGENT SESSION: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
