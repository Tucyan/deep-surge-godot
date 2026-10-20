extends SceneTree
const Session=preload("res://core/game_session.gd")
const Encounter=preload("res://core/encounter_rules.gd")
const Navigation=preload("res://core/navigation_rules.gd")
const NEW_IDS=["restCove","relicCache","tollGate","luckyDrift","deepCache"]
const RETIRED=["sealedLarder","powderWreck","kelpDryingRack","silentWayfinder","boneHunter","shellGraveyard","drownedMint","rescuePontoon","coralShrine","riggersCache","sealedChest"]
const FIRST_VOYAGE={"restCove":2,"relicCache":3,"tollGate":4,"luckyDrift":5,"deepCache":5}
var failures:=0
var checks:=0
var catalog
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func fresh():
	var s=Session.new(catalog); s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}); s._auto_advancing=true
	return s
func test_pool_replacement() -> void:
	for id in NEW_IDS:
		var node: Dictionary=catalog.entry("nodes",id)
		check(not node.is_empty(),"new node exists: "+id)
		if node.is_empty(): continue
		check(int(node.get("min_voyage",0))==FIRST_VOYAGE[id],"draft voyage gate retained: "+id)
		check(int(node.get("max_visits",0))==1 and int(node.get("cooldown",0))==3,"new node quota and cooldown: "+id)
	for layer in ["shallows","open_sea","abyss","story","tutorial"]:
		var pool: Dictionary=catalog.entry("node_pools",layer)
		if pool.is_empty(): continue
		var ids: Array=pool.entries.map(func(entry): return entry.node)
		for id in NEW_IDS:
			check((id in ids)==(layer in ["shallows","open_sea","abyss"]),layer+" has expected scope for "+id)
		for id in RETIRED: check(id not in ids,layer+" excludes retired "+id)
	check(catalog.entry("nodes","storm/surface").is_empty(),"surface storm definition stays retired/absent")
func test_layer_quota_and_reset() -> void:
	var s=fresh(); var node: Dictionary=catalog.entry("nodes","restCove")
	if node.is_empty(): return
	var shallow: Dictionary=s.state.duplicate(true)
	shallow.flags.node_visits={}
	shallow.flags.node_last={}
	shallow.journey.layer_voyage=2; shallow.voyage=2
	check(Navigation.eligible(s,node,shallow),"rest cove becomes eligible at local voyage 2")
	var counter="shallows:"+Encounter.key(node)
	shallow.flags.node_visits[counter]=1
	check(not Navigation.eligible(s,node,shallow),"one visit consumes its layer quota")
	var later: Dictionary=shallow.duplicate(true); later.journey.layer_index=1; later.journey.layer_voyage=2; later.voyage=8; later.flags.node_visits.clear(); later.flags.node_last.clear()
	check(Navigation.eligible(s,node,later),"same node quota resets in a new layer")
func test_lucky_drift_stages() -> void:
	var node: Dictionary=catalog.entry("nodes","luckyDrift")
	check(node.get("stages",[]).size()==4,"lucky drift has four stages including the completion panel")
	if node.get("stages",[]).size()!=4: return
	var costs=[1,1,2]
	for index in range(3):
		var choices: Array=node.stages[index]
		var reach: Dictionary=choices[0]
		check(int(reach.get("statCosts",{}).get("hp",0))==costs[index],"stage %d reach HP cost" % index)
		check(int(reach.get("next_stage",-1))==index+1,"stage %d advances exactly once" % index)
		for outcome in reach.get("outcomes",[]):
			var battle: Dictionary=outcome.get("battle",{})
			if not battle.is_empty():
				check(int(battle.get("return_stage",-1))==index+1,"stage %d battle resumes at next valid stage" % index)
				check(int(battle.return_stage)<node.stages.size(),"stage %d battle return is in range" % index)
				var local_catalog=catalog.get_script().new(); local_catalog._tables=catalog._tables.duplicate(true)
				var forced: Dictionary=local_catalog._tables.nodes.luckyDrift.duplicate(true)
				forced.stages[index][0].outcomes=[outcome.duplicate(true)]
				local_catalog._tables.nodes.luckyDrift=forced; local_catalog._tables=JSON.parse_string(JSON.stringify(local_catalog._tables)); local_catalog._fingerprint=JSON.stringify(local_catalog._tables).sha256_text()
				var s=Session.new(local_catalog); s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}); s._auto_advancing=true
				s.state.phase="story"; s.state.story_step="choice"; s.state.node=forced.duplicate(true); s.state.node.visit_id="lucky-%d" % index; s.state.candidates=[]; s.state.ap=6; s.Encounter.arrived(s); s.state.encounter.stage=index
				check(s.dispatch("option",{"id":reach.id}),"stage %d battle outcome enters combat" % index)
				check(s.state.encounter.battle_continuation==index+1,"stage %d runtime battle resumes at next stage" % index)
				var restored=Session.new(local_catalog)
				check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"stage %d battle continuation restores: %s" % [index,restored.error])
				s.state.battle.hp=1
				check(s.dispatch("battle_action",{"action":"attack"}) and s.state.encounter.stage==index+1,"stage %d battle victory resumes event" % index)
		var leave: Dictionary=choices[-1]
		check(leave.id=="leave","stage %d retains stop option" % index)
	var last: Dictionary=node.stages[2][0]
	for outcome in last.outcomes:
		if outcome.get("battle",{}).is_empty(): continue
		check(outcome.battle.return_stage==3,"final reach battle resumes at the valid terminal fourth stage")
	check(node.stages[3].size()==1 and node.stages[3][0].id=="done","fourth stage is terminal completion")
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog loads")
	test_pool_replacement(); test_layer_quota_and_reset(); test_lucky_drift_stages()
	print("COLLECTIBLE NODES: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]); quit(failures)

