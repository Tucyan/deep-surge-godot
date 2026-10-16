extends SceneTree
## v11 public-interface routes, captured by tools/validate_economy.py.
## The v7 health-route fixture remains historical and is not replayed against v11.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"load catalogue")
	for name in ["challenge-39","challenge-9","story-22"]:
		var trace=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/economy-v11-"+name+".trace.json"))
		check(trace is Dictionary,"recorded public trace exists "+name)
		if not trace is Dictionary: continue
		var agent=load("res://adapters/agent_session.gd").new(catalog)
		var response: Dictionary=agent.handle({"method":"replay","params":{"trace":trace}})
		check(response.ok,"full route replays "+name)
		if not response.ok: printerr(response); continue
		var result: Dictionary=agent.handle({"method":"result"}).data
		check(result.terminal,"route terminates "+name)
		check(result.report.complete,"complete statistics "+name)
		for card in result.report.cards:
			var departures: int=card.use_consumed+card.cost_consumed+card.deployed+card.discarded+card.lost+card.cleared+card.get("sold",0)
			check(int(card.obtained)==int(card.remaining)+departures,"card conservation "+name+"/"+card.id)
		var snapshot=agent._session.snapshot()
		var loaded=load("res://core/game_session.gd").new(catalog)
		check(loaded.restore(JSON.parse_string(JSON.stringify(snapshot))),"terminal snapshot restores "+name)
		if name=="challenge-39": check(result.outcome=="survived" and result.completed==12,"recorded surviving challenge")
		if name=="challenge-9": check(result.outcome=="dead","recorded failed challenge")
		if name=="story-22": check(result.phase=="chapterComplete" and result.completed==15,"all fifteen story nodes")
		print("ROUTE "+name+": "+result.phase+" / "+result.outcome)
	print("ROUTES: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
