extends SceneTree
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func execute(agent, command: String, args: Dictionary={}) -> bool:
	var response: Dictionary=agent.handle({"method":"actions"})
	for item in response.data.actions:
		if item.command!=command: continue
		var matches:=true
		for key in args:
			if key=="revision": continue
			if item.args.get(key)!=args[key]: matches=false; break
		if matches:
			return agent.handle({"method":"act","params":{"action_id":item.action_id,"revision":item.revision}}).ok
	return false
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	var agent=load("res://adapters/agent_session.gd").new(catalog)
	# Independent public route: merchant opening coins fund a first-voyage shelf offer.
	check(agent.handle({"method":"reset","params":{"seed":6,"origin":"merchant"}}).ok,"public merchant reset")
	var opening: Dictionary=agent.handle({"method":"observe"}).data
	var destination := ""
	for candidate in opening.candidates:
		if candidate.get("kind","")=="shop": destination=str(candidate.visit_id); break
	check(not destination.is_empty(),"opening navigation exposes actual merchant")
	if destination.is_empty(): quit(failures); return
	check(execute(agent,"voyage",{"id":destination}),"public voyage to actual merchant")
	check(execute(agent,"enter") and execute(agent,"advance"),"public merchant arrival")
	check(execute(agent,"shop_enter"),"public shop entry")
	var obs: Dictionary=agent.handle({"method":"observe"}).data
	var buy: Dictionary={}
	for item in agent.handle({"method":"actions"}).data.actions:
		if item.command=="buy_collectible": buy=item; break
	check(not buy.is_empty(),"affordable real collectible offer")
	if buy.is_empty(): quit(failures); return
	check(execute(agent,"buy_collectible",buy.args),"purchase via real action ID")
	obs=agent.handle({"method":"observe"}).data
	check(obs.collectibles.size()==1,"public held projection")
	var uid: String=obs.collectibles[0].uid
	check(not obs.has("rng") and not obs.has("seed"),"no hidden RNG in public view")
	check(execute(agent,"shop_leave") and execute(agent,"advance"),"actual merchant completion")
	check(execute(agent,"discard_collectible",{"uid":uid}),"public instance discard")
	check(agent.handle({"method":"observe"}).data.collectibles.is_empty(),"discarded projection")
	check(not execute(agent,"discard_collectible",{"uid":uid}),"duplicate discard absent from public actions")
	var recorded: Dictionary=agent.handle({"method":"trace"}).data
	var replay: Dictionary=agent.handle({"method":"replay","params":{"trace":JSON.parse_string(JSON.stringify(recorded))}})
	check(replay.ok and replay.data.steps==recorded.steps.size(),"full actual purchase/discard trace replay")
	if failures==0:
		var output=FileAccess.open("user://collectible-agent.trace.json",FileAccess.WRITE)
		output.store_string(JSON.stringify(recorded)); output.close()
		print("COLLECTIBLE AGENT: PASS (%d public steps, purchased %s, discarded %s)" % [recorded.steps.size(),buy.args.id,uid])
	quit(failures)
