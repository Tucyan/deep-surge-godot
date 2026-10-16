extends SceneTree
var failures:=0
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void:
	if not ResourceLoader.exists("res://presentation/raft_actions.gd"):
		check(false,"Missing direct raft interaction policy"); quit(1); return
	var catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	var session=load("res://core/game_session.gd").new(catalog)
	session.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	session.give("filter",2,false,"interaction-fixture"); session.give("wood",4,false,"interaction-fixture")
	var policy=load("res://presentation/raft_actions.gd").new(); policy.refresh(session)
	var cell: Dictionary=session.state.cells[0]; var before: Dictionary=session.snapshot()
	var install: Array=policy.cell_actions(cell.id).filter(func(a):return a.command=="install")
	check(not install.is_empty() and install[0].allowed,"Empty cell offers install from real hand")
	check(policy.expansions().is_empty(),"No expansion ghosts while usable empty cells remain")
	check(session.snapshot()==before,"Preview never changes AP, cards, revision or RNG")
	session.dispatch("install",install[0].args); policy.refresh(session)
	check(policy.cell_actions(cell.id).any(func(a):return a.command=="upgrade" and a.allowed),"Matching hand card offers valid upgrade")
	session.state.cells[0].status="damaged"; policy.refresh(session)
	check(policy.cell_actions(cell.id).any(func(a):return a.command=="repair_cell"),"Damaged cell offers repair")
	check(not policy.cell_actions(cell.id).any(func(a):return a.allowed and a.command in ["install","upgrade"]),"Broken cell cannot install or upgrade; disabled reasons may remain visible")
	for c in session.state.cells: c.status="intact"; c.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
	policy.refresh(session); before=session.snapshot()
	var ghosts: Array=policy.expansions()
	check(ghosts.size()==1,"Full raft offers exactly one next adjacent expansion ghost")
	check(not ghosts.any(func(c):return c.y==1 and c.x in [1,2]),"Decorative roots never become targets")
	check(ghosts[0].allowed and ghosts[0].cost=={"wood":1} and ghosts[0].ap==1,"Expansion quotes discounted wood/AP cost")
	check(session.snapshot()==before,"Expansion preview/confirmation does not spend resources")
	var command: Dictionary=ghosts[0]
	check(session.dispatch("expand",command.args),"Confirmed expansion uses existing rule command")
	policy.refresh(session); check(policy.expansions().is_empty(),"New free cell hides expansion hints")
	for c in session.state.cells: c.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
	session.state.hand=session.state.hand.filter(func(c):return c.id!="wood")
	policy.refresh(session)
	check(policy.expansions().all(func(c):return not c.allowed),"Insufficient materials produce disabled red previews")
	print("RAFT INTERACTIONS: "+("PASS" if failures==0 else "FAIL")); quit(failures)
