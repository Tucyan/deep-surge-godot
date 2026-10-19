extends SceneTree
const Query = preload("res://core/action_query.gd")
var failures := 0
var total := 0
func check(ok: bool, why: String) -> void:
	total += 1
	if not ok: failures += 1; printerr("FAIL: " + why)
func find_action(agent, command: String) -> Dictionary:
	for item in agent.handle({"method":"actions"}).data.actions:
		if item.command==command and (command!="craft" or item.args.get("id", "")=="filter"):
			return item
	return {}
func act(agent, action: Dictionary) -> Dictionary:
	return agent.handle({"method":"act", "params":{"action_id":action.get("action_id", ""), "revision":agent._session.revision}})
func _init() -> void:
	var catalog = load("res://content/catalog.gd").new()
	catalog.load_catalog()
	var agent = load("res://adapters/agent_session.gd").new(catalog)
	check(agent.handle({"method":"reset", "params":{"seed":22,"starting_resources":["plastic","plastic","wood","rope","rope"]}}).ok, "start through public interface")
	check(act(agent, find_action(agent,"craft")).ok, "craft filter through public action")
	check(act(agent, find_action(agent,"install")).ok, "install filter through public action")
	var before: Dictionary = agent._session.snapshot()
	var cell_id: String = agent._session.state.cells.filter(func(cell): return not cell.equipment.is_empty())[0].id
	check(Query.quote(agent._session,"dismantle",{"cell":cell_id}).allowed, "core permits installed device dismantle")
	var dismantle: Dictionary = find_action(agent,"dismantle")
	check(not dismantle.is_empty() and dismantle.get("args",{}).get("cell","")==cell_id, "legal dismantle is discoverable with its real target")
	check(agent._session.snapshot()==before, "catalogue and previews preserve RNG and statistics")
	var damaged = Query.fork(agent._session)
	damaged.state.cells[0].status="damaged"
	check(Query.list_actions(damaged).any(func(item): return item.command=="dismantle" and item.args.cell==cell_id), "damaged installed device is covered when core permits it")
	damaged.state.ap=0
	check(not Query.list_actions(damaged).any(func(item): return item.command=="dismantle"), "AP-ineligible dismantle is not advertised")
	if not dismantle.is_empty():
		var stale: Dictionary = agent.handle({"method":"act", "params":{"action_id":dismantle.action_id,"revision":agent._session.revision-1}})
		check(not stale.ok and agent._session.snapshot()==before, "stale dismantle is atomically rejected")
		var direct = load("res://core/game_session.gd").new(catalog)
		check(direct.restore(before), "same-version test state restores")
		direct.screen="game"
		check(direct.dispatch("dismantle",dismantle.args), "direct dispatch accepts enumerated arguments")
		check(act(agent,dismantle).ok, "Agent executes enumerated dismantle")
		check(agent._session.snapshot()==direct.snapshot(), "Agent and direct dispatch have identical AP, materials and RNG")
		check(agent._session.state.ap==int(before.state.ap)-1 and agent._session.state.cells[0].equipment.is_empty(), "dismantle charges one AP and clears equipment")
		var trace: Dictionary = agent.handle({"method":"trace"}).data
		var replay: Dictionary = agent.handle({"method":"replay", "params":{"trace":JSON.parse_string(JSON.stringify(trace))}})
		check(replay.ok, "public craft/install/dismantle trace replays")
	print("ACTION CATALOGUE: %d checks, %d failures" % [total,failures])
	quit(0 if failures==0 else 1)
