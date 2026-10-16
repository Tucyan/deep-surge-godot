extends SceneTree
var failures := 0
var catalog
const Session=preload("res://core/game_session.gd")
func check(ok: bool,why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func fresh():
	var s=Session.new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"skeptic","seed":22})
	s.state.hand=[]
	return s
func encounter(enemy: String="biter",node: String="battle"):
	var s=fresh(); s.state.node=catalog.entry("nodes",node); s.state.node.visit_id="integration"
	s.state.phase="story"; s.state.story_step="choice"; s.dispatch("fight")
	s.state.battle.id=enemy; s.state.battle.hp=30
	return s
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	# Overflow is usable for one voyage, survives claiming/saving, and expires
	# even if its generator is disabled before the following settlement.
	var s=fresh(); s.state.phase="preparation"; s.state.node=catalog.entry("nodes","camp"); s.state.node.visit_id="overflow"
	s.give("generator"); check(s.dispatch("install",{"uid":s.state.hand[-1].uid,"cell":"cell-0"}),"install generator")
	var eq: Dictionary=s.state.cells[0].equipment
	eq.level=2; eq.fuel=3; eq.boost_cards=[{"uid":"boost-1","id":"power"}]; s.state.next_boost_id=2
	s.state.phase="aftermath"; check(s.dispatch("end_voyage"),"produce despite full permanent capacity")
	check(eq.boost_cards.size()==2,"full generator keeps permanent card and produces overflow")
	if eq.boost_cards.size()==2:
		var overflow_uid: String=eq.boost_cards[1].uid
		check(eq.boost_cards[1].get("expires_voyage",0)==2,"overflow expires at next voyage settlement")
		check(s.dispatch("claim_boost",{"cell":"cell-0","id":"barrier"}),"claim overflow without refreshing its lifetime")
		check(eq.boost_cards[1].get("expires_voyage",0)==2,"claim preserves overflow expiry")
		var loaded=Session.new(catalog)
		check(loaded.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"overflow can be saved and restored")
		s.state.cells[0].status="damaged"; s.state.cells[0].damaged_at=2
		s.state.phase="aftermath"; check(s.dispatch("end_voyage"),"settle disabled generator")
		check(not eq.boost_cards.any(func(c):return c.uid==overflow_uid) and eq.boost_cards.size()==1,"disabled generator still expires overflow and preserves permanent card")
	# Demo development explicitly rejects old content instead of migrating it.
	s=fresh(); s.state.candidates=[catalog.entry("nodes","ruin")]; s.state.candidates[0].visit_id="current-ruin"; s.EnvironmentRules.prepare_navigation(s)
	var old: Dictionary=s.snapshot(); old.content_version="godot-flow-v02-4"; old.fingerprint=catalog.prior_flow_fingerprint()
	old.state.candidates[0].erase("difficulty")
	var reloaded=Session.new(catalog)
	check(not reloaded.restore(old),"old ruin save is rejected")
	check(reloaded.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"current ruin saves and restores")
	# Plastic retains at most one point and lasts for exactly one extra enemy turn.
	s=encounter("jelly"); s.give("plastic")
	check(s.dispatch("battle_action",{"action":"block","resource_uid":s.state.hand[-1].uid}),"plastic guard")
	var hp: int=s.state.player.hp
	s.dispatch("battle_end")
	check(s.state.player.hp==hp and s.state.battle.shields.size()==1 and s.state.battle.shields[0].amount==1,"plastic carries its remaining single shield")
	s.dispatch("battle_end")
	check(s.state.player.hp==hp and s.state.battle.shields.is_empty(),"plastic shields the next hit then disappears")
	# Later ordinary attacks must not erase rope's already committed reduction.
	s=encounter(); s.give("rope"); hp=s.state.player.hp
	s.dispatch("battle_action",{"action":"attack","resource_uid":s.state.hand[-1].uid})
	s.dispatch("battle_action",{"action":"attack"}); s.dispatch("battle_end")
	check(s.state.player.hp==hp,"rope reduction survives a following ordinary attack")
	# Winning and restoring the same point produces the same random resource IDs.
	for node in ["battle","ruin"]:
		s=encounter("biter" if node=="battle" else "sentinel",node); s.state.battle.hp=1
		var copy=Session.new(catalog); check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"reward fixture restores")
		check(s.dispatch("battle_action",{"action":"attack"}) and copy.dispatch("battle_action",{"action":"attack"}),"both restored fights win")
		var rewards: Array=s.state.hand.filter(func(c):return c.source=="battle_reward")
		var copied: Array=copy.state.hand.filter(func(c):return c.source=="battle_reward")
		check(rewards.size()==(1 if node=="battle" else 2),"normal/hard reward count: "+node)
		check(rewards.map(func(c):return c.id)==copied.map(func(c):return c.id),"reward RNG restores: "+node)
		check(s.I.count(s.state,"corpse")==1 and s.state.coins==(1 if node=="battle" else 2),"reduced corpse and coin rewards")
	print("COMBAT INTEGRATION: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
