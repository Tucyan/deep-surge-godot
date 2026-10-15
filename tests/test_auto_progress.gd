extends SceneTree
const I=preload("res://core/inventory.gd")
var failures:=0
var catalog
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func fixture(phase: String,ap: int,ids: Array):
	var s=load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	s.state.phase=phase; s.state.ap=ap; s.state.hand=[]
	s.state.node=catalog.entry("nodes","battle" if phase=="battle" else "camp"); s.state.node.visit_id="auto-fixture"
	if phase=="battle":
		s.state.battle={"id":s.state.node.monster,"hp":10,"turn":1,"ap":ap,"entry_hp":40,"poison_until":0,"fear_until":0}
	for id in ids: s.give(id)
	return s
func _init():
	catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	var s=fixture("aftermath",0,["wood"])
	s.dispatch("resume")
	check(s.phase()=="navigation" and s.state.voyage==2,"no actions auto settles and skips satisfied discard")
	s=fixture("aftermath",0,[])
	for i in range(12): s.give("wood")
	s.dispatch("resume")
	check(s.phase()=="discard" and s.state.voyage==1,"over capacity waits for manual discard")
	s=fixture("aftermath",0,["water"])
	s.dispatch("resume")
	check(s.phase()=="aftermath","effective zero AP water keeps aftermath open")
	s.dispatch("play",{"uid":s.state.hand[0].uid})
	check(s.phase()=="navigation","last free card triggers settlement")
	s=fixture("aftermath",0,["water"]); s.state.player.hydration=s.state.player.hydration_max
	s.dispatch("resume")
	check(s.phase()=="navigation","capped survival card is not effective")
	s=fixture("aftermath",1,["wood","iron"]); s.dispatch("resume")
	check(s.phase()=="aftermath","legal crafting keeps aftermath open")
	s.dispatch("craft",{"id":"lamp"})
	check(s.phase()=="navigation","last AP craft automatically settles")
	s=fixture("aftermath",1,["filter"]); s.dispatch("resume")
	check(s.phase()=="aftermath","legal installation with remaining AP is preserved")
	for phase in ["navigation","preparation"]:
		s=fixture(phase,0,[]); s.dispatch("resume")
		check(s.phase()==phase,"do not skip required destination or node: "+phase)
	s=fixture("battle",1,["punch"]); var hp: int=s.state.player.hp
	s.dispatch("play",{"uid":s.state.hand[0].uid})
	check(s.phase()=="battle" and s.state.battle.turn==2 and s.state.battle.ap==3 and s.state.player.hp<hp,"last AP auto runs enemy and refreshes next turn")
	s=fixture("battle",1,["punch","arrow"])
	s.dispatch("play",{"uid":s.state.hand[0].uid})
	check(s.state.battle.turn==1 and s.state.battle.ap==0,"free arrow blocks automatic enemy turn")
	s.dispatch("play",{"uid":s.state.hand[-1].uid})
	check(s.state.battle.turn==2,"using final free arrow advances turn")
	s=fixture("battle",0,["water"]); s.state.player.hydration=s.state.player.hydration_max
	s.dispatch("resume")
	check(s.state.battle.turn==2,"ineffective free heal does not block battle")
	s=fixture("battle",1,["punch"]); s.state.battle.hp=1
	s.dispatch("play",{"uid":s.state.hand[0].uid})
	check(s.phase()=="story" and s.state.story_step=="result","victory keeps result instead of advancing enemy")
	s=fixture("battle",0,["punch"]); s.state.player.hp=1; s.dispatch("resume")
	check(s.phase()=="finished" and s.state.result=="dead","automatic enemy turn handles death and settlement")
	s=fixture("aftermath",0,["wood"])
	s.state.cells[0].equipment={"id":"lamp","level":1,"fuel":0,"progress":0}
	var before: Dictionary=s.snapshot()
	check(s.AutoProgress.next_command(s)=="" and s.AutoProgress.next_command(s)=="","free fuel remains a legal action")
	check(s.snapshot()==before,"repeated legality probes do not mutate inventory stats or RNG")
	s=fixture("aftermath",0,[]); s.state.mode="story"; s.Campaign.initialize(s); s.state.voyage=5
	s.dispatch("resume")
	check(s.phase()=="nightHub" and s.state.voyage==5,"automatic end of day respects mandatory night services")
	print("AUTO PROGRESS: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
