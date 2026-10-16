extends RefCounted
## Serializable facts written inside the same transaction as their effects.
const VERSION := "run-stats-v1"
const CARD_FIELDS := ["obtained","used","use_consumed","cost_consumed","deployed","discarded","lost","cleared","sold"]
const GAME_COMMANDS := ["voyage","enter","advance","skip","option","shop_enter","shop_leave","buy","sell","fight","leave_encounter","play","battle_action","claim_boost","boost_device","battle_end","retreat","craft","salvage","transmute","install","fuel","repair_cell","heal","expand","upgrade","action_card","dismantle","end_voyage","night_actions","night_action","night_ack","finish_night","accept_quest","submit_quest","night_exchange","discard","abandon"]

static func initialize(state: Dictionary, complete: bool = true) -> void:
	var initial: Array = []
	for cell in state.cells: initial.append(cell.id)
	state.stats = {"version":VERSION,"complete":complete,"coverage_start":state.voyage,"cards":{},"events":[],"commands":{},"counters":{},"minimum":{},"restored":{},"lost":{},"attribute_sources":{},"devices":{},"visits":[],"completed_ids":[],"battles":{},"crises":{},"crafts":[],"initial_cells":initial,"detached":[],"tags":[]}
	for stat in ["hp","sanity","hunger","hydration"]: state.stats.minimum[stat]=state.player[stat]

static func record(state: Dictionary, kind: String, detail: Dictionary = {}) -> void:
	if not state.has("stats"): return
	var entry := detail.duplicate(true)
	entry.merge({"sequence":state.stats.events.size(),"command_sequence":state.get("_stat_revision",0),"subsequence":state.get("_stat_subsequence",0),"run_id":state.get("run_id",""),"kind":kind,"voyage":state.voyage,"node":state.node.get("visit_id",""),"battle_instance":state.node.get("visit_id","")+"/battle" if not state.battle.is_empty() else "","command":state.get("_stat_command","system"),"source":detail.get("source",detail.get("reason",state.get("_stat_command","system")))},true)
	if state.has("_stat_revision"): state._stat_subsequence=int(state.get("_stat_subsequence",0))+1
	state.stats.events.append(entry)

static func card(state: Dictionary, id: String, field: String, amount: int = 1, reason: String = "", uid: String = "") -> void:
	if not state.has("stats") or amount<=0: return
	if not state.stats.cards.has(id):
		var row := {"sources":{},"reasons":{}}
		for key in CARD_FIELDS: row[key]=0
		state.stats.cards[id]=row
	var row: Dictionary = state.stats.cards[id]
	row[field]=int(row.get(field,0))+amount
	var bucket: String = "sources" if field=="obtained" else "reasons"
	if reason!="" and field!="used": row[bucket][reason]=int(row[bucket].get(reason,0))+amount
	record(state,"card",{"id":id,"uid":uid,"field":field,"amount":amount,"reason":reason})

static func change(state: Dictionary, stat: String, before: int, after: int, requested: int, source: String) -> void:
	if not state.has("stats"): return
	state.stats.minimum[stat]=mini(int(state.stats.minimum.get(stat,before)),after)
	var bucket: String = "restored" if after>before else "lost"
	state.stats[bucket][stat]=int(state.stats[bucket].get(stat,0))+absi(after-before)
	if stat=="hp" and after<before and not state.battle.is_empty(): increment(state,"damage_received",before-after)
	if not state.stats.attribute_sources.has(stat): state.stats.attribute_sources[stat]={}
	if source=="": source=state.get("_stat_command","system")
	var overflow: int = maxi(0,requested-maxi(0,after-before))
	var sources: Dictionary = state.stats.attribute_sources[stat]
	if not sources.has(source): sources[source]={"restored":0,"lost":0,"overflow":0}
	sources[source][bucket]+=absi(after-before); sources[source].overflow+=overflow
	increment(state,"recovery_overflow",overflow)
	if before!=after or overflow>0: record(state,"attribute",{"stat":stat,"before":before,"after":after,"delta":after-before,"requested":requested,"overflow":overflow,"source":source})

static func increment(state: Dictionary, id: String, amount: int = 1) -> void:
	if state.has("stats"): state.stats.counters[id]=int(state.stats.counters.get(id,0))+amount

static func tag(state: Dictionary, id: String) -> void:
	if state.has("stats") and id not in state.stats.tags: state.stats.tags.append(id)

static func device_used(state: Dictionary, id: String, cell: String = "", output: String = "", amount: int = 0) -> void:
	if not state.has("stats"): return
	tag(state,"device"); increment(state,"device_uses")
	var key: String = id+"/"+cell
	if not state.stats.devices.has(key): state.stats.devices[key]={"id":id,"cell":cell,"uses":0,"produced":0,"outputs":{}}
	var device: Dictionary = state.stats.devices[key]
	device.uses+=1; device.produced+=amount
	if output!="": device.outputs[output]=int(device.outputs.get(output,0))+amount
	record(state,"device_used",{"id":id,"cell":cell,"output":output,"amount":amount})

static func enter_crisis(state: Dictionary) -> void:
	if not state.has("stats"): return
	var id: String = state.node.get("visit_id","")
	# Explicit mapping: trade/rest/supply are not crises. Combat nodes and storm
	# have reviewed success/leave exits; final story's three paid plans are handled below.
	if state.node.has("monster") or state.node.get("id","")=="ST.L1.F15":
		if not state.stats.crises.has(id): state.stats.crises[id]={"success":false,"resolved":false,"id":state.node.id}

static func accept_crisis(state: Dictionary) -> void:
	if not state.has("stats"): return
	var id: String=state.node.get("visit_id","")
	if not state.stats.crises.has(id): state.stats.crises[id]={"success":false,"resolved":false,"id":state.node.id,"outcome":"active"}

static func resolve_crisis(state: Dictionary, success: bool, outcome: String = "") -> void:
	if not state.has("stats"): return
	var id: String = state.node.get("visit_id","")
	if state.stats.crises.has(id):
		state.stats.crises[id].success=success; state.stats.crises[id].resolved=true
		state.stats.crises[id].outcome=outcome if outcome!="" else ("success" if success else "failed")
		record(state,"crisis",{"success":success})

static func battle_start(state: Dictionary) -> void:
	if not state.has("stats"): return
	var id: String = state.node.get("visit_id","")+"/battle"
	state.stats.battles[id]={"outcome":"unfinished","enemy":state.battle.id,"turns":1}
	increment(state,"battle_rounds")
	record(state,"battle_enter",{"battle":id,"enemy":state.battle.id})

static func battle_result(state: Dictionary, outcome: String) -> void:
	if not state.has("stats"): return
	var id: String = state.node.get("visit_id","")+"/battle"
	if state.stats.battles.has(id):
		state.stats.battles[id].outcome=outcome
		state.stats.battles[id].turns=state.battle.get("turn",1)
	resolve_crisis(state,outcome=="won")
	record(state,"battle_result",{"battle":id,"outcome":outcome})

static func commit(state: Dictionary, before: Dictionary, command: String, args: Dictionary) -> void:
	if not state.has("stats") or command not in GAME_COMMANDS: return
	state.stats.commands[command]=int(state.stats.commands.get(command,0))+1
	if command=="voyage":
		state.stats.visits.append({"voyage":state.voyage,"id":state.node.id,"visit_id":state.node.visit_id,"name":state.node.name,"kind":state.node.kind})
	if int(state.completed)>int(before.get("completed",0)):
		var node: Dictionary = before.get("node",state.node)
		var id: String = node.get("visit_id","")
		if id not in state.stats.completed_ids: state.stats.completed_ids.append(id)
		var types: Array = []
		for visit in state.stats.visits:
			if visit.visit_id in state.stats.completed_ids and visit.kind not in types: types.append(visit.kind)
		if types.size()>=3: tag(state,"exploration")
	if command=="craft":
		if args.id not in state.stats.crafts: state.stats.crafts.append(args.id)
		tag(state,"craft")
	if command=="upgrade" and args.get("craft",false):
		for cell in state.cells:
			if cell.id==args.get("cell",""):
				if cell.equipment.id not in state.stats.crafts: state.stats.crafts.append(cell.equipment.id)
				tag(state,"craft")
	if command=="heal": device_used(state,"medkit",args.get("cell",""))
	if command=="submit_quest": tag(state,"quest")
	if command=="night_action" and args.get("id","")!="rest": tag(state,"investigation")
	if command in ["action_card","option"]:
		for old in before.get("cells",[]):
			for cell in state.cells:
				if old.id==cell.id and old.status=="damaged" and cell.status=="intact": increment(state,"repairs")
	if command=="repair_cell": increment(state,"repairs")
	if command=="transmute": increment(state,"transmutes",int(args.get("count",1)))
	if command=="expand": increment(state,"expansions")
	if command=="install": increment(state,"installations")
	if command=="upgrade": increment(state,"upgrades")
	for cell in state.cells:
		if cell.status=="detached" and cell.id not in state.stats.detached: state.stats.detached.append(cell.id)
		for old in before.get("cells",[]):
			if old.id==cell.id and not old.equipment.is_empty() and cell.equipment.is_empty():
				var reason: String = "merge" if command=="upgrade" else ("dismantle" if command=="action_card" else "loss")
				increment(state,"equipment_"+reason)
				record(state,"equipment_removed",{"id":old.equipment.id,"cell":cell.id,"reason":reason})
	var base_spent: int = maxi(0,int(before.get("ap",0))-int(state.ap))
	if command not in ["end_voyage","finish_night","abandon"]: increment(state,"base_ap_spent",base_spent)
	var old_battle: Dictionary = before.get("battle",{})
	if not old_battle.is_empty() and command=="play":
		var played: Dictionary = {}
		for item in before.hand:
			if item.uid==args.get("uid",""): played=item
		if not played.is_empty(): record(state,"battle_play",{"card":played.id})
	record(state,"command",{"id":command})

static func valid(state: Dictionary) -> bool:
	if not state.get("stats") is Dictionary: return false
	var stats: Dictionary = state.stats
	if stats.get("version")!=VERSION or not stats.get("complete") is bool: return false
	for key in ["cards","commands","counters","minimum","restored","lost","attribute_sources","devices","battles","crises"]:
		if not stats.get(key) is Dictionary: return false
	for key in ["events","visits","completed_ids","crafts","initial_cells","detached","tags"]:
		if not stats.get(key) is Array: return false
	for row in stats.cards.values():
		if not row is Dictionary or not row.get("sources") is Dictionary or not row.get("reasons") is Dictionary: return false
		for field in CARD_FIELDS:
			var value = row.get(field)
			if not nonnegative_integer(value): return false
		for bucket in ["sources","reasons"]:
			for value in row[bucket].values():
				if not nonnegative_integer(value): return false
	for bucket in ["commands","counters","minimum","restored","lost"]:
		for value in stats[bucket].values():
			if not nonnegative_integer(value): return false
	for battle in stats.battles.values():
		if not battle is Dictionary or battle.get("outcome") not in ["unfinished","won","retreated","protected","dead"] or not battle.get("enemy") is String or not nonnegative_integer(battle.get("turns")): return false
	for crisis in stats.crises.values():
		if not crisis is Dictionary or not crisis.get("success") is bool or not crisis.get("resolved") is bool or not crisis.get("id") is String: return false
	for sources in stats.attribute_sources.values():
		if not sources is Dictionary: return false
		for row in sources.values():
			if not row is Dictionary: return false
			for field in ["restored","lost","overflow"]:
				if not nonnegative_integer(row.get(field)): return false
	for device in stats.devices.values():
		if not device is Dictionary or not device.get("id") is String or not device.get("cell") is String or not nonnegative_integer(device.get("uses")) or not nonnegative_integer(device.get("produced")) or not device.get("outputs") is Dictionary: return false
		for value in device.outputs.values():
			if not nonnegative_integer(value): return false
	for visit in stats.visits:
		if not visit is Dictionary or not nonnegative_integer(visit.get("voyage")): return false
		for key in ["id","visit_id","name","kind"]:
			if not visit.get(key) is String: return false
	for i in range(stats.events.size()):
		var entry = stats.events[i]
		if not entry is Dictionary or entry.get("sequence")!=i or not entry.get("kind") is String: return false
	for bucket in ["completed_ids","crafts","initial_cells","detached","tags"]:
		var identities: Array = []
		for value in stats[bucket]:
			if not value is String or value in identities: return false
			identities.append(value)
	for value in stats.tags:
		if value not in ["exploration","craft","device","investigation","quest"]: return false
	return true

static func nonnegative_integer(value) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value>=0 and floor(float(value))==float(value)
