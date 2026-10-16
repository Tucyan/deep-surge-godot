extends SceneTree
var failures := 0
const Q = preload("res://core/action_query.gd")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	var s=load("res://core/game_session.gd").new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"new game")
	s.state.hand=[]; s.give("wood",6)
	var before=s.snapshot()
	check(not s.dispatch("expand",{"x":1,"y":1}) and s.snapshot()==before,"invalid target preserves discount, inventory and RNG")
	for point in [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)]:
		var wood: int=s.I.count(s.state,"wood"); var ap: int=s.state.ap
		check(s.dispatch("expand",{"x":point.x,"y":point.y}),"first three expansions succeed")
		check(s.I.count(s.state,"wood")==wood-1 and s.state.ap==ap-1,"first three cost one wood and one AP")
	check(int(s.state.get("expansion_count",-1))==3,"successful expansion count persists independently of cell count")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()))
	var copy=load("res://core/game_session.gd").new(catalog)
	check(copy.restore(saved),"same-version save restores after discount consumed")
	if copy.state.is_empty(): quit(1); return
	# Detachment does not replenish an already used discount. Rebuilding is expand.
	for game in [s,copy]:
		game.state.cells[-1].status="detached"; game.state.ap=1
		var wood: int=game.I.count(game.state,"wood")
		check(game.dispatch("expand",{"x":2,"y":0}),"rebuild after three expansions")
		check(game.I.count(game.state,"wood")==wood-2 and game.state.ap==0,"fourth expansion costs two wood")
	check(JSON.parse_string(JSON.stringify(s.snapshot()))==JSON.parse_string(JSON.stringify(copy.snapshot())),"restored continuation is deterministic")
	for bad_value in [-1,1.5,"3",true]:
		var bad: Dictionary=saved.duplicate(true); bad.state.expansion_count=bad_value
		check(not copy.restore(bad),"malformed expansion counter rejected")
	var missing: Dictionary=saved.duplicate(true); missing.state.erase("expansion_count")
	check(not copy.restore(missing),"missing expansion counter rejected")
	var old: Dictionary=saved.duplicate(true); old.content_version="godot-flow-v02-14"
	check(not copy.restore(old),"v14 save rejected")
	var fresh=load("res://core/game_session.gd").new(catalog)
	fresh.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	fresh.state.hand=[]; fresh.give("wood")
	before=fresh.snapshot()
	check(Q.list_actions(fresh).any(func(a):return a.command=="expand"),"one wood exposes expansion to Agent")
	check(fresh.snapshot()==before,"queries do not consume discount")
	check(fresh.view().get("expansion_cost",{}).get("wood",0)==1,"observation projects current cost")
	var agent=load("res://adapters/agent_session.gd").new(catalog)
	var response: Dictionary=agent.handle({"method":"reset","params":{"seed":22,"starting_resources":["wood"]}})
	check(response.data.observation.get("expansion_count",-1)==0 and response.data.observation.get("expansion_cost",{}).get("wood",0)==1,"Agent exposes discount count and cost")
	var available: Dictionary=agent.handle({"method":"actions"})
	var expansions: Array=available.data.actions.filter(func(a):return a.command=="expand")
	check(not expansions.is_empty(),"Agent can expand")
	if not expansions.is_empty():
		var acted: Dictionary=agent.handle({"method":"act","params":{"action_id":expansions[0].action_id,"revision":response.data.observation.revision}})
		check(acted.ok,"Agent expansion succeeds")
		var trace: Dictionary=agent.handle({"method":"trace"}).data
		var replay: Dictionary=agent.handle({"method":"replay","params":{"trace":JSON.parse_string(JSON.stringify(trace))}})
		check(replay.ok,"expansion trace survives JSON replay")
		var forged: Dictionary=JSON.parse_string(JSON.stringify(trace)); forged.steps[0].args.x=99
		check(not agent.handle({"method":"replay","params":{"trace":forged}}).ok,"replay still rejects illegal expansion coordinates")
	print("EXPANSION DISCOUNT: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
