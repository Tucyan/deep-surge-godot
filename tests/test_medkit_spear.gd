extends SceneTree
var failures:=0
var catalog
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func session():
	var s=load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}); s.state.hand=[]
	return s
func _init():
	catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	for phase in ["navigation","preparation","aftermath","battle"]:
		var s=session(); s.state.phase=phase; s.state.ap=0; s.state.player.hp=5; s.give("medkit")
		if phase=="battle": s.state.battle={"hp":10,"ap":0,"turn":1,"id":"jelly","entry_hp":5,"poison_until":0,"fear_until":0}
		check(s.catalog.entry("cards","medkit").kind=="survival" and s.catalog.entry("cards","medkit").cost==0,"medkit is free survival item")
		check(s.dispatch("play",{"uid":s.state.hand[0].uid}),"medkit usable in "+phase)
		check(s.I.count(s.state,"medkit")==0,"single use consumes medkit")
		if phase!="battle": check(s.state.player.hp==8,"medkit restores three HP")
	var s=session(); s.give("medkit")
	check(not s.dispatch("install",{"uid":s.state.hand[0].uid,"auto":true}),"medkit cannot be installed")
	var legacy: Dictionary=s.snapshot(); legacy.content_version="godot-flow-v02-4"; legacy.fingerprint=catalog.previous_balance_fingerprint()
	legacy.state.hand=[]; legacy.state.cells[0].equipment={"id":"medkit","level":1,"fuel":0,"progress":0}
	check(not s.restore(legacy),"old medkit save rejected during Demo development")
	for level in [1,2]:
		s=session(); s.state.node=catalog.entry("nodes","battle"); s.state.node.visit_id="spear-test"; s.state.phase="story"; s.state.story_step="choice"
		s.state.cells[0].equipment={"id":"spearRack","level":level,"fuel":0,"progress":0}
		check(s.dispatch("fight"),"begin battle")
		var spears: Array=s.state.hand.filter(func(c):return c.id=="spear")
		check(spears.size()==1,"one spear at battle start")
		s.state.battle.hp=30; var before: int=s.state.battle.hp
		s.dispatch("play",{"uid":spears[0].uid})
		check(before-s.state.battle.hp==(3 if level==1 else 5),"spear damage at level %d" % level)
		s.dispatch("battle_end")
		check(s.state.hand.filter(func(c):return c.id=="spear").is_empty(),"no replacement spear next turn")
		# Start the next independent encounter with a usable rack; the biter now
		# explicitly damages a cell during the previous enemy turn.
		s.state.cells[0].status="intact"; s.state.cells[0].damaged_at=0
		s.state.phase="story"; s.state.story_step="choice"; s.state.hand=[]
		s.dispatch("fight")
		check(s.state.hand.filter(func(c):return c.id=="spear").size()==1,"next battle grants a fresh spear")
	print("MEDKIT AND SPEAR: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
