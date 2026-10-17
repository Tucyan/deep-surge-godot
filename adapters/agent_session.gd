extends RefCounted
## Transport-independent, isolated test run. Never accesses SaveStore/user://.
const Session = preload("res://core/game_session.gd")
const Query = preload("res://core/action_query.gd")
const PROTOCOL := "deep-surge-agent-v1"
const TRACE_VERSION := "deep-surge-trace-v1"
var _catalog: RefCounted
var _session: RefCounted
var _trace: Dictionary={}
var _actions: Array=[]
var _action_revision := -1

func _init(catalog: RefCounted) -> void:
	_catalog=catalog

func handle(request: Variant) -> Dictionary:
	if not request is Dictionary: return failure(null,"invalid_request","请求必须是对象")
	var id: Variant=request.get("id")
	if not request.get("method") is String: return failure(id,"invalid_request","method必须是字符串")
	var params: Variant=request.get("params",{})
	if not params is Dictionary: return failure(id,"invalid_params","params必须是对象")
	match request.method:
		"reset": return reset(id,params)
		"replay": return replay(id,params.get("trace"))
		"observe", "actions", "act", "result", "trace":
			if _session==null: return failure(id,"not_started","先调用reset或replay")
			match request.method:
				"observe": return success(id,observe())
				"actions": return success(id,{"revision":_session.revision,"actions":actions().duplicate(true)})
				"act": return act(id,params)
				"result": return success(id,result())
				"trace": return success(id,_trace.duplicate(true))
	return failure(id,"unknown_method","未知方法")

func reset(id: Variant, params: Dictionary) -> Dictionary:
	for key in params:
		if key not in ["seed","mode","origin","starting_resources","difficulty","purchases"]: return failure(id,"invalid_params","未知开局字段："+str(key))
	if not integer(params.get("seed")) or params.seed<0 or params.seed>4294967295:
		return failure(id,"invalid_params","seed必须是0～4294967295整数")
	if not params.get("mode","challenge") is String or not params.get("origin","strong") is String:
		return failure(id,"invalid_params","mode/origin必须是字符串")
	var args: Dictionary={"difficulty":params.get("difficulty","standard"),"seed":int(params.seed),"mode":params.get("mode","challenge"),"origin":params.get("origin","strong"),"starting_resources":params.get("starting_resources",[])}
	var next=Session.new(_catalog)
	if params.has("purchases") and params.purchases is Dictionary:
		next.profile.purchases = params.purchases.duplicate(true)
	if not next.dispatch("new",args): return failure(id,"rejected",next.error)
	_session=next; _action_revision=-1; _actions=[]
	_trace={"version":TRACE_VERSION,"protocol":PROTOCOL,"initial":_session.snapshot(),"steps":[]}
	return success(id,{"observation":observe()})

func actions() -> Array:
	if _action_revision!=_session.revision:
		_actions=Query.list_actions(_session)
		_action_revision=_session.revision
	return _actions

func act(id: Variant, params: Dictionary) -> Dictionary:
	if not params.get("action_id") is String or not integer(params.get("revision")):
		return failure(id,"invalid_params","act需要action_id字符串和整数revision")
	if int(params.revision)!=_session.revision: return failure(id,"stale_revision","操作已过期，请重新查询")
	var selected: Dictionary={}
	for item in actions():
		if item.action_id==params.action_id: selected=item; break
	if selected.is_empty(): return failure(id,"unknown_action","操作不在当前合法列表中")
	var resolved: Dictionary=Query.resolve_args(selected,params.get("arguments",{}))
	if not resolved.valid: return failure(id,"invalid_params",resolved.reason)
	var args: Dictionary=resolved.args.duplicate(true)
	args.revision=_session.revision
	var event_start: int=_session.state.get("stats",{}).get("events",[]).size()
	if not _session.dispatch(selected.command,args): return failure(id,"rejected",_session.error)
	_trace.steps.append({"command":selected.command,"args":resolved.args.duplicate(true),"hash":state_hash(_session)})
	return success(id,{"observation":observe(),"events":_session.state.get("stats",{}).get("events",[]).slice(event_start).duplicate(true),"terminal":terminal()})

func observe() -> Dictionary:
	var view: Dictionary=_session.view()
	var observation: Dictionary={}
	# Explicit player-facing projection; no seed/RNG, future pool, full stats,
	# profile/debug reports, UI pages or hidden narrative state.
	for key in ["survival_settlement","expansion_count","expansion_cost","difficulty","environments","navigation","revision","phase","mode","origin","voyage","length","ap","player","hand","coins","cells","node","candidates","story_step","result_text","battle","completed","level","xp","capacity","can_base","boost_cards","battle_actions","scene","shop","encounter","event_options"]:
		if view.has(key): observation[key]=view[key]
	for node in observation.get("candidates",[])+[observation.get("node",{})]:
		for key in ["lines","choices","handler","outcomes","effects"]: node.erase(key)
		node.erase("stages")
		for option in node.get("options",[]):
			for key in ["outcomes","effects"]: option.erase(key)
	for option in observation.get("event_options",[]):
		for field in ["effects","outcomes","next_stage"]: option.erase(field)
	observation.terminal=terminal()
	observation.tech_tree=view.tech_tree.duplicate(true)
	if _session.phase()=="battle":
		observation.enemy=_session.Difficulty.enemy(_catalog,_session.state,str(_session.state.battle.id))
		observation.battle_combinations=_session.Battle.COMBO.duplicate(true)
	return observation

func terminal() -> bool:
	return _session.phase() in ["finished","chapterComplete"]

func result() -> Dictionary:
	return {"terminal":terminal(),"phase":_session.phase(),"outcome":_session.state.get("result",""),"completed":_session.state.get("completed",0),"report":_session.state.get("settlement",{}).duplicate(true) if terminal() else {}}

func replay(id: Variant, trace: Variant) -> Dictionary:
	if not trace is Dictionary or trace.get("version")!=TRACE_VERSION or trace.get("protocol")!=PROTOCOL or not trace.get("initial") is Dictionary or not trace.get("steps") is Array or trace.steps.size()>10000:
		return failure(id,"invalid_trace","轨迹格式或版本错误")
	var probe=Session.new(_catalog)
	if not probe.restore(trace.initial) or probe.state.is_empty(): return failure(id,"invalid_trace","起始快照无效或内容版本不匹配")
	probe.screen="game"; probe.panel=probe.event_panel()
	for index in range(trace.steps.size()):
		var step: Variant=trace.steps[index]
		if not step is Dictionary or not step.get("command") is String or not step.get("args") is Dictionary or not step.get("hash") is String:
			return failure(id,"invalid_trace","步骤格式错误：%d" % index)
		var found := false
		for item in Query.candidates(probe):
			if item.command!=step.command: continue
			var extra: Dictionary=step.args.duplicate(true)
			var fixed_match := true
			for key in item.args:
				if not extra.has(key) or extra[key]!=item.args[key]: fixed_match=false; break
				extra.erase(key)
			if not fixed_match: continue
			var resolved: Dictionary=Query.resolve_args(item,extra)
			# JSON parses integer coordinates as floats. Normalize both objects
			# before dictionary comparison, as state_hash already does.
			if resolved.valid and JSON.parse_string(JSON.stringify(resolved.args))==JSON.parse_string(JSON.stringify(step.args)): found=true; break
		if not found or not probe.dispatch(step.command,step.args) or state_hash(probe)!=step.hash:
			return failure(id,"replay_mismatch","重放不一致，步骤：%d" % index)
	_session=probe; _trace=trace.duplicate(true); _action_revision=-1; _actions=[]
	return success(id,{"observation":observe(),"steps":trace.steps.size()})

static func state_hash(session: RefCounted) -> String:
	# Normalize integer/float representation across JSON wire round trips.
	return JSON.stringify(JSON.parse_string(JSON.stringify(session.snapshot()))).sha256_text()

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value))<=9007199254740991.0 and float(value)==floor(float(value))

static func success(id: Variant, data: Dictionary) -> Dictionary:
	return {"protocol":PROTOCOL,"id":id,"ok":true,"data":data}

static func failure(id: Variant, code: String, message: String) -> Dictionary:
	return {"protocol":PROTOCOL,"id":id,"ok":false,"error":{"code":code,"message":message}}
