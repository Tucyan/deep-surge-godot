extends SceneTree
var failures:=0
var catalog
func check(ok: bool,why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func fixture():
	var s=load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	s.state.hand=[]; s.state.ap=3
	s.state.cells[1].equipment={"id":"filter","level":1,"fuel":4,"progress":1}
	return s
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	var s=fixture(); var policy=load("res://presentation/raft_actions.gd").new(); policy.refresh(s)
	var actions: Array=policy.cell_actions(s.state.cells[1].id)
	check(actions.any(func(a):return a.command=="upgrade" and not a.args.get("craft",false) and not a.allowed and not a.reason.is_empty()),"Missing donor still shows upgrade and a reason")
	s.give("wood",1,false,"fixture"); s.give("plastic",2,false,"fixture")
	policy.refresh(s); var before: Dictionary=s.snapshot()
	actions=policy.cell_actions(s.state.cells[1].id)
	check(actions.any(func(a):return a.command=="upgrade" and a.args.get("craft",false) and a.allowed),"Materials offer one-click upgrade")
	check(s.snapshot()==before,"Action quotes do not consume materials or RNG")
	var ap_spent: int=s.state.stats.counters.get("base_ap_spent",0)
	check(s.dispatch("upgrade",{"cell":s.state.cells[1].id,"craft":true}),"Atomic craft-and-upgrade succeeds")
	check(s.state.cells[1].equipment.level==2 and s.state.ap==1,"Shortcut charges crafting AP plus upgrade AP")
	check(s.I.count(s.state,"wood")==0 and s.I.count(s.state,"plastic")==0 and s.I.count(s.state,"filter")==0,"Shortcut consumes exact recipe without leaving a device card")
	check(s.state.cells[1].equipment.fuel==4 and s.state.cells[1].equipment.progress==1,"Upgrade preserves production and fuel")
	check(s.state.stats.counters.get("base_ap_spent",0)==ap_spent+2,"AP statistics count shortcut once")
	check("filter" in s.state.stats.crafts and s.state.stats.counters.get("upgrades",0)==1,"Shortcut records crafting and upgrading")
	s=fixture(); s.give("wood",1); s.give("plastic",2); s.state.ap=2
	check(s.dispatch("upgrade",{"cell":s.state.cells[1].id,"craft":true}),"Exact combined AP is sufficient")
	check(s.state.ap==0 and s.state.cells[1].equipment.level==2,"No intermediate auto-advance between crafting and upgrading")
	s=fixture(); s.give("wood",1); s.give("plastic",2); before=s.snapshot()
	check(not s.dispatch("upgrade",{"cell":s.state.cells[1].id,"craft":true,"revision":s.revision-1}),"Stale shortcut rejected")
	check(s.snapshot()==before,"Stale shortcut consumes nothing")
	for blocked in ["materials","ap","damaged","level","technology","phase"]:
		s=fixture(); s.give("wood",1,false,"fixture"); s.give("plastic",2,false,"fixture")
		match blocked:
			"materials": s.state.hand=s.state.hand.filter(func(c):return c.id!="plastic")
			"ap": s.state.ap=1
			"damaged": s.state.cells[1].status="damaged"
			"level": s.state.cells[1].equipment.level=2
			"technology": s.state.cells[1].equipment.id="spearRack"; s.give("wood",2); s.give("iron",1)
			"phase": s.state.phase="story"
		before=s.snapshot()
		check(not s.dispatch("upgrade",{"cell":s.state.cells[1].id,"craft":true}),"Reject invalid shortcut: "+blocked)
		check(s.snapshot()==before,"Invalid shortcut rolls back all effects: "+blocked)
	print("CRAFT UPGRADE: "+("PASS" if failures==0 else "FAIL")); quit(failures)
