extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	check(load("res://core/raft_layout.gd").positions(3,4).size()==12,"base expansion rectangle is 3 by 4")
	check(load("res://core/raft_layout.gd").positions(4,4).size()==16,"raft permit retains 4 by 4 rectangle")
	for unlocked in [false,true]:
		var s=load("res://core/game_session.gd").new(catalog)
		if unlocked: s.profile.purchases.raft=1
		s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
		check(s.state.cells.map(func(c):return Vector2i(c.x,c.y))==[Vector2i(2,2),Vector2i(1,2),Vector2i(0,2),Vector2i(0,1)],"initial playable cells are spiral 3/4/5/6")
		var models=load("res://presentation/raft_state_models.gd").new()
		check(models.root_cells(s.state.flags.raft_layout).map(func(c):return Vector2i(c.x,c.y))==[Vector2i(1,1),Vector2i(2,1)],"decorative 1/2 move to centre")
		for p in [Vector2i(1,1),Vector2i(2,1)]:
			var before=s.snapshot()
			check(not s.dispatch("expand",{"x":p.x,"y":p.y}) and s.snapshot()==before,"decorative roots reject expansion atomically")
		s.state.hand=[]; s.give("wood",30)
		var points=[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(3,1),Vector2i(3,2),Vector2i(3,3),Vector2i(2,3),Vector2i(1,3),Vector2i(0,3)] if unlocked else [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(2,3),Vector2i(1,3),Vector2i(0,3)]
		var policy=load("res://presentation/raft_actions.gd").new()
		var build_limit=10 if unlocked else 6
		for index in range(build_limit):
			for c in s.state.cells: c.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
			s.state.ap=3; policy.refresh(s)
			var ghosts=policy.expansions()
			check(ghosts.size()==1,"exactly one spiral expansion ghost")
			if ghosts.is_empty(): break
			check(Vector2i(ghosts[0].x,ghosts[0].y)==points[index],"next spiral cell %d" % (index+7))
			check(s.dispatch("expand",ghosts[0].args),"build spiral cell")
		for c in s.state.cells: c.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
		policy.refresh(s)
		check(policy.expansions().is_empty(),"12/16 total-cell limit remains")
		check(s.state.cells.size()==(14 if unlocked else 10),"functional capacity becomes 10/14")
		if not unlocked:
			var outside=s.snapshot()
			check(not s.dispatch("expand",{"x":3,"y":0}) and s.snapshot()==outside,"base raft rejects fourth column")
		var saved=JSON.parse_string(JSON.stringify(s.snapshot()))
		var restored=load("res://core/game_session.gd").new(catalog)
		check(restored.restore(saved),"spiral save restores")
		var invalid_layout=saved.duplicate(true); invalid_layout.state.flags.raft_layout="123456"
		check(not restored.restore(invalid_layout),"legacy layout marker is rejected without migration")
		var occupied_root=saved.duplicate(true); occupied_root.state.cells[0].x=1; occupied_root.state.cells[0].y=1
		check(not restored.restore(occupied_root),"save cannot place functional cell on decoration")
		var old=saved.duplicate(true); old.content_version="godot-flow-v02-15"
		check(not restored.restore(old),"v15 save rejected")
		s.state.cells[0].status="detached"; s.state.cells[0].equipment={}; s.state.ap=3; policy.refresh(s)
		var repair_hint=policy.expansions()
		check(repair_hint.size()==1 and int(repair_hint[0].number)==3,"earliest detached spiral gap is offered for rebuild")
	print("SPIRAL RAFT: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
