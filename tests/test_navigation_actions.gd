extends SceneTree
var failures := 0
const I = preload("res://core/inventory.gd")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+why)
func _init() -> void:
	var catalog = load("res://content/catalog.gd").new(); catalog.load_catalog()
	for mode in ["challenge","story"]:
		var s = load("res://core/game_session.gd").new(catalog)
		check(s.dispatch("new",{"mode":mode,"origin":"strong","seed":22}),"new "+mode)
		check(s.state.ap == s.state.player.base_ap,"AP available before first destination")
		# Enter the second navigation through real settlement/discard, with supplies.
		s.state.phase="aftermath"; s.state.hand=[]; s.state.coins=0
		check(s.dispatch("end_voyage"),"settle first voyage")
		check(s.phase()=="navigation" and s.state.voyage==2,"new navigation")
		check(s.view().can_base and s.state.ap==s.state.player.base_ap,"navigation refreshes AP once")
		s.state.hand=[]
		for id in ["plastic","plastic","wood","water"]: I.give(s.state,id,1,false,"fixture")
		var candidates: Array=s.state.candidates.duplicate(true)
		var rng: Dictionary=s.state.rng.duplicate(true)
		var water: Dictionary=I.find(s.state,s.state.hand[-1].uid)
		var hydration: int=s.state.player.hydration
		check(s.dispatch("play",{"uid":water.uid}),"use water before destination")
		check(s.state.player.hydration>hydration and I.count(s.state,"water")==0,"water effect and consumption")
		check(s.dispatch("panel",{"id":"craft"}),"open craft before destination")
		check(s.dispatch("craft",{"id":"filter"}),"craft before destination")
		check(s.state.ap==s.state.player.base_ap-1 and I.count(s.state,"filter")==1 and I.count(s.state,"plastic")==0,"craft cost and output")
		check(s.state.candidates==candidates and s.state.rng==rng and s.phase()=="navigation","actions preserve destination and random stream")
		var remaining: int=s.state.ap
		check(s.dispatch("voyage",{"id":candidates[0].visit_id}),"depart")
		check(s.state.ap==remaining,"departure does not refresh spent AP")
		check(not s.dispatch("voyage",{"id":candidates[0].visit_id}),"cannot depart twice")
		s.state.phase="discard"
		check(not s.dispatch("craft",{"id":"filter"}),"discard still blocks craft")
	print("NAVIGATION ACTIONS: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
