extends SceneTree
const Session=preload("res://core/game_session.gd")
const NODES=preload("res://tests/test_relic_expedition.gd").NODES
var failures:=0
var catalog
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func fresh():
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"new")
	s._auto_advancing=true
	return s
func test_pools() -> void:
	# Legacy A min_voyage values describe GLOBAL arrival windows (3..6).
	# B pool min/max are layer-local: shallows starts1, open_sea6, abyss16.
	for layer in ["shallows","open_sea","abyss"]:
		var offset: int={"shallows":0,"open_sea":5,"abyss":15}[layer]
		for id in NODES:
			var d: Dictionary=catalog.entry("nodes",id)
			var entries: Array=catalog.entry("node_pools",layer).entries.filter(func(e):return e.node==id)
			if layer=="shallows" and int(d.min_voyage)>5:
				check(entries.is_empty(),"global6 node excluded from shallows: "+id); continue
			check(entries.size()==1,"registered in "+layer+": "+id)
			if entries.is_empty():continue
			var e: Dictionary=entries[0]
			check(e.min_voyage==maxi(1,int(d.min_voyage)-offset),"global-to-local minimum: "+layer+id)
			check(e.scope=="run" and e.max_visits==1 and e.cooldown==3 and e.weight==1,"once per run policy: "+layer+id)
	for layer in ["story","tutorial"]:
		check(catalog.entry("node_pools",layer).entries.all(func(e):return e.node not in NODES),"paused modes unchanged: "+layer)
	var s=fresh()
	s.state.flags.node_visits={}
	for id in NODES:
		var d: Dictionary=catalog.entry("nodes",id)
		s.state.journey.layer_voyage=int(d.min_voyage); s.state.voyage=int(d.min_voyage)
		if d.min_voyage>5:continue
		check(preload("res://core/navigation_rules.gd").eligible(s,d,s.state),"new node actually eligible: "+id)
		s.state.flags.node_visits[id]=1
		s.state.journey.layer_index=1; s.state.journey.layer_voyage=1; s.state.voyage=6
		check(not preload("res://core/navigation_rules.gd").eligible(s,d,s.state),"run visit survives layer transition: "+id)
		s.state.journey.layer_index=0
func test_public_art() -> void:
	var s=fresh()
	for id in NODES:
		s.state.node=catalog.entry("nodes",id); s.state.node.visit_id="art-contract"
		s.state.phase="story"; s.state.story_step="choice"; s.Survival.lock_costs(s); s.Encounter.arrived(s)
		var before: Dictionary=s.snapshot()
		var v: Dictionary=s.view()
		check(v.node.get("art","")==s.state.node.art,"safe display art survives public projection: "+id)
		check(not v.node.has("rewards") and not v.node.has("stages"),"hidden node data stripped")
		for o in v.node.options:check(not o.has("battle") and not o.has("outcomes") and not o.has("effects"),"hidden option data stripped")
		check(s.snapshot()==before,"art view is pure")
func restored(s):
	var other=Session.new(catalog)
	check(other.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"legal v03 relic state restores: "+s.phase()+" "+other.error)
	other._auto_advancing=true
	return other
func test_battle_restore_and_cross_layer() -> void:
	var s=fresh()
	# Replace only the encounter definition after a real departure. Journey,
	# weather provenance and immutable survival basis remain fully legal B state.
	check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"real departure")
	check(s.dispatch("enter"),"real preparation")
	s.state.node=catalog.entry("nodes","boneHunter");s.state.node.visit_id="relic-battle"
	s.state.phase="story";s.state.story_step="choice";s.state.candidates=[];s.Encounter.arrived(s)
	s.state.player.hp_max=100;s.state.player.hp=100;s.state.player.damage=100
	check(s.Collectibles.acquire(s,"drifterQuiver"),"quiver acquired before battle")
	check(s.dispatch("option",{"id":"blade"}),"new reward battle starts")
	check(s.state.hand.filter(func(c):return c.id=="arrow" and c.temporary).size()==2,"two temporary arrows at battle start")
	var charges: Dictionary=s.state.collectibles.items[0].effects.duplicate(true)
	s=restored(s)
	check(s.state.hand.filter(func(c):return c.id=="arrow" and c.temporary).size()==2 and same(s.state.collectibles.items[0].effects,charges),"midfight restore neither duplicates cards nor spends charges")
	check(s.dispatch("battle_action",{"action":"attack"}),"win new reward battle")
	check(s.state.collectibles.items.filter(func(i):return i.id=="tideBoneBlade").size()==1,"victory awards new blade once")
	check(s.state.hand.all(func(c):return not c.temporary),"victory removes temporary arrows")
	s=restored(s)
	var before: Dictionary=s.snapshot()
	check(not s.dispatch("battle_action",{"action":"attack"}) and s.snapshot()==before,"restored victory cannot pay award twice")
	var blade_uid: String=str(s.state.collectibles.items.filter(func(i):return i.id=="tideBoneBlade")[0].uid)
	for step in range(140):
		if s.state.voyage>=6:break
		check(progress(s),"legal cross-layer action: "+s.phase()+" "+s.error)
		if s.phase()=="finished":break
	check(s.state.voyage==6 and s.state.journey.layer_index==1,"real Boss and survival settlement cross first layer")
	check(s.state.collectibles.items.any(func(i):return i.id=="tideBoneBlade" and str(i.uid)==blade_uid),"new relic UID preserved across layer")
	s=restored(s)
	check(s.state.collectibles.items.any(func(i):return str(i.uid)==blade_uid),"cross-layer relic save restores")
func progress(s) -> bool:
	match s.phase():
		"navigation":
			s.state.player.hunger=100;s.state.player.hydration=100;s.state.player.sanity=100
			return s.dispatch("voyage",{"id":s.state.candidates[0].visit_id})
		"preparation":return s.dispatch("enter")
		"story":
			if s.state.story_step!="choice":return s.dispatch("advance")
			if s.state.node.has("monster"):return s.dispatch("fight")
			if s.state.node.kind=="shop":return s.dispatch("shop_enter")
			for option in s.Encounter.options(s):
				for args in s.Encounter.arguments(s,option):
					if s.Encounter.reason(s,option,args)=="":return s.dispatch("option",args)
		"battle":return s.dispatch("battle_action",{"action":"attack"}) if s.state.battle.ap>0 else s.dispatch("battle_end")
		"interaction":return s.dispatch("shop_leave")
		"aftermath":return s.dispatch("end_voyage")
		"discard":return s.dispatch("discard",{"uid":s.state.hand[0].uid})
	return false
func test_live_survival_modifiers() -> void:
	for id in ["kelpRation","copperStill","emberFuse","tideBoneBlade","crimsonVial"]:
		var s=fresh()
		check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"departure before modifier: "+id)
		var base: Dictionary=s.state.flags.voyage_survival_costs.duplicate(true)
		var basis: Dictionary=s.state.flags.voyage_cost_basis.duplicate(true)
		var initial: Dictionary=s.Survival.quote(s).costs
		check(s.Collectibles.acquire(s,id),"acquire after departure: "+id)
		var stat: String="hunger" if id in ["kelpRation","tideBoneBlade"] else "hydration"
		var delta: int=-5 if id in ["kelpRation","copperStill"] else 5
		check(s.Survival.quote(s).costs[stat]==maxi(0,int(initial[stat])+delta),"live quote uses acquired modifier: "+id)
		check(same(s.state.flags.voyage_survival_costs,base) and same(s.state.flags.voyage_cost_basis,basis),"acquisition preserves base/weather lock: "+id)
		s=restored(s)
		var held: Dictionary=s.Survival.quote(s).costs
		var settlement=restored(s)
		var food: int=settlement.state.player.hunger;var water: int=settlement.state.player.hydration
		check(settlement.Survival.settle(settlement),"held modifier settlement: "+id)
		check(settlement.state.player.hunger==maxi(0,food-int(held.hunger)) and settlement.state.player.hydration==maxi(0,water-int(held.hydration)),"settlement uses acquired modifier: "+id)
		check(s.dispatch("discard_collectible",{"uid":s.state.collectibles.items[0].uid}),"discard after departure: "+id)
		check(s.Survival.quote(s).costs==initial,"discard updates live quote: "+id)
		check(same(s.state.flags.voyage_survival_costs,base) and same(s.state.flags.voyage_cost_basis,basis),"discard preserves base/weather lock: "+id)
		s=restored(s)
		food=s.state.player.hunger;water=s.state.player.hydration
		check(s.Survival.settle(s),"discarded modifier settlement: "+id)
		check(s.state.player.hunger==maxi(0,food-int(initial.hunger)) and s.state.player.hydration==maxi(0,water-int(initial.hydration)),"settlement uses discarded modifier: "+id)
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	test_pools();test_public_art();test_battle_restore_and_cross_layer();test_live_survival_modifiers()
	print("V03 RELIC INTEGRATION: %s" % ("PASS" if failures==0 else "FAIL"));quit(failures)
