extends SceneTree
const Session = preload("res://core/game_session.gd")
const I = preload("res://core/inventory.gd")
var failures := 0
var catalog

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)

func fixture(mode: String = "challenge"):
	var s = Session.new(catalog)
	check(s.dispatch("new",{"mode":mode,"origin":"strong","seed":31}),"new session")
	s.state.hand=[]; s.state.phase="aftermath"; s.state.ap=3
	s.state.node=catalog.entry("nodes","camp"); s.state.node.visit_id="production-fixture"
	s.state.cells[0].equipment={"id":"filter","level":2,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
	return s

func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	print("CONTENT FINGERPRINT: "+catalog.fingerprint())
	var s=fixture()
	s.give("wood",11)
	check(s.dispatch("end_voyage"),"end current voyage")
	check(s.phase()=="discard" and s.state.voyage==1,"existing excess is discarded before next round")
	check(I.count(s.state,"water")==0 and s.state.cells[0].equipment.progress==0,"no production or progress during end settlement")
	var old_discard: Dictionary=s.snapshot()
	old_discard.state.player.hp=40; old_discard.state.player.hp_max=40
	old_discard.content_version="godot-flow-v02-5"; old_discard.fingerprint=catalog.previous_production_fingerprint()
	check(s.dispatch("discard",{"uid":s.state.hand[0].uid}),"finish previous round discard")
	check(s.phase()=="navigation" and s.state.voyage==2,"new round opens navigation even above capacity")
	check(I.count(s.state,"water")==1 and I.capacity(s.state)>I.hand_limit(s.state,catalog),"new output bypasses previous round discard")
	check(s.state.stats.devices["filter/cell-0"].outputs.water==1,"production is counted once")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()))
	var restored=Session.new(catalog)
	check(restored.restore(saved),"round-start output saves and restores")
	check(restored.dispatch("resume") and restored.dispatch("close"),"resume and reopen interface")
	check(restored.state.hand==saved.state.hand and restored.state.rng==saved.state.rng,"restore and interface do not produce or reroll")
	check(not restored.dispatch("end_voyage"),"navigation cannot repeat end settlement")
	var migrated=Session.new(catalog)
	check(not migrated.restore(old_discard),"Demo development rejects obsolete production saves")
	var slow=fixture(); slow.state.cells[0].equipment.level=1
	check(slow.dispatch("end_voyage"),"first production tick at next round start")
	check(slow.state.voyage==2 and I.count(slow.state,"water")==0 and slow.state.cells[0].equipment.progress==1,"level one waits for two round starts")
	slow.state.phase="aftermath"
	check(slow.dispatch("end_voyage") and I.count(slow.state,"water")==1,"second round start completes level one cycle")
	var broken=fixture(); broken.state.cells[0].status="damaged"
	check(broken.dispatch("end_voyage") and I.count(broken.state,"water")==0,"damaged cell pauses production")
	var detached=fixture(); detached.state.voyage=3; detached.state.cells[0].status="damaged"; detached.state.cells[0].damaged_at=1
	check(detached.dispatch("end_voyage") and detached.state.cells[0].status=="detached" and I.count(detached.state,"water")==0,"aging removes device before next round production")
	var gen=fixture(); gen.state.cells[0].equipment={"id":"generator","level":2,"fuel":2,"progress":0,"boost_cards":[{"uid":"stored","id":"power"}],"production_bonus":0}
	check(gen.dispatch("end_voyage"),"generator produces at round start")
	var boosts: Array=gen.state.cells[0].equipment.boost_cards
	check(gen.state.voyage==2 and boosts.size()==2 and gen.state.cells[0].equipment.fuel==1,"generator consumes fuel once at round start")
	check(boosts.size()==2 and boosts[1].get("expires_voyage",0)==2,"overflow boost lasts until current round end")
	var terminal=fixture(); terminal.state.voyage=terminal.state.length
	check(terminal.dispatch("end_voyage") and terminal.phase()=="finished" and I.count(terminal.state,"water")==0,"no phantom production after final voyage")
	print("ROUND START PRODUCTION: %s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
