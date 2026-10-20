extends SceneTree
const Session=preload("res://core/game_session.gd")
const NODES=["restCove","relicCache","tollGate","luckyDrift","deepCache"]
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
	# These five nodes share the same local voyage gates in every layer.
	for layer in ["shallows","open_sea","abyss"]:
		for id in NODES:
			var d: Dictionary=catalog.entry("nodes",id)
			var entries: Array=catalog.entry("node_pools",layer).entries.filter(func(e):return e.node==id)
			check(entries.size()==1,"registered in "+layer+": "+id)
			if entries.is_empty():continue
			var e: Dictionary=entries[0]
			check(e.min_voyage==d.min_voyage,"local minimum matches node: "+layer+id)
			check(e.scope=="layer" and e.max_visits==1 and e.cooldown==3 and e.weight==1,"once per layer policy: "+layer+id)
	for layer in ["story","tutorial"]:
		check(NODES.all(func(id):return not catalog.entry("node_pools",layer).entries.any(func(e):return e.node==id)),"challenge-only scope excludes "+layer)
	var s=fresh()
	s.state.flags.node_visits={}
	for id in NODES:
		var d: Dictionary=catalog.entry("nodes",id)
		s.state.journey.layer_voyage=int(d.min_voyage); s.state.voyage=int(d.min_voyage)
		check(preload("res://core/navigation_rules.gd").eligible(s,d,s.state),"new node actually eligible: "+id)
		var key="shallows:"+s.Encounter.key(d)
		s.state.flags.node_visits[key]=1
		check(not preload("res://core/navigation_rules.gd").eligible(s,d,s.state),"one visit consumes the current layer quota: "+id)
		s.state.journey.layer_index=1; s.state.journey.layer_voyage=int(d.min_voyage); s.state.voyage=5+int(d.min_voyage)
		check(preload("res://core/navigation_rules.gd").eligible(s,d,s.state),"visit quota resets in a later layer: "+id)
		s.state.journey.layer_index=0
func test_public_art() -> void:
	var s=fresh()
	for id in NODES:
		s.state.node=catalog.entry("nodes",id); s.state.node.visit_id="art-contract"
		s.state.phase="story"; s.state.story_step="choice"; s.Encounter.arrived(s)
		var before: Dictionary=s.snapshot()
		var v: Dictionary=s.view()
		check(v.node.get("art","")==s.state.node.get("art",""),"safe display art survives public projection: "+id)
		check(not v.node.has("rewards") and not v.node.has("stages"),"hidden node data stripped")
		for o in v.node.get("options",[]):check(not o.has("battle") and not o.has("outcomes") and not o.has("effects"),"hidden option data stripped")
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
		var stat: String="hunger" if id in ["kelpRation","tideBoneBlade"] else "hydration"
		var delta: int=-5 if id in ["kelpRation","copperStill"] else 5
		var initial: Dictionary=s.Survival.quote(s).costs
		check(s.Collectibles.acquire(s,id),"acquire before departure: "+id)
		var held: Dictionary=s.Survival.quote(s).costs
		check(held[stat]==maxi(0,int(initial[stat])+delta),"preview applies the held modifier: "+id)
		# Food and water are charged by the departure itself, so a modifier held at
		# that moment is exactly what the run pays.
		var food: int=s.state.player.hunger; var water: int=s.state.player.hydration
		check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"departure with modifier: "+id)
		check(s.state.player.hunger==maxi(0,food-int(held.hunger)) and s.state.player.hydration==maxi(0,water-int(held.hydration)),"departure charges the held modifier: "+id)
		# quote() is a live preview of the NEXT departure, not a historical bill.
		# A late kelp restores 25 food once, but never refunds the previous fare.
		var paid_player: Dictionary=s.state.player.duplicate(true)
		var late_id: String="copperStill" if id=="kelpRation" else "kelpRation"
		var late_stat: String="hydration" if late_id=="copperStill" else "hunger"
		check(s.Collectibles.acquire(s,late_id),"late acquisition: "+id)
		var expected_food: int=mini(int(paid_player.hunger)+25,int(s.state.player.hunger_max)) if late_id=="kelpRation" else int(paid_player.hunger)
		check(s.state.player.hunger==expected_food and s.state.player.hydration==paid_player.hydration and s.state.player.hp==paid_player.hp and s.state.player.sanity==paid_player.sanity,"late acquisition only applies its one-time restoration, with no refund or extra fare: "+id)
		var live_costs: Dictionary=held.duplicate(true)
		live_costs[late_stat]=maxi(0,int(live_costs[late_stat])-5)
		check(s.Survival.quote(s).costs==live_costs,"late modifier immediately changes the next-departure preview: "+id)
		var after_acquire: Dictionary=s.snapshot()
		s.Survival.quote(s); s.view(); s.Survival.quote(s)
		check(s.snapshot()==after_acquire,"repeated live previews never settle or restore again: "+id)
		var round_end_player: Dictionary=s.state.player.duplicate(true)
		s.state.phase="aftermath"; check(s.dispatch("end_voyage"),"round end after modifier: "+id)
		check(s.state.player==round_end_player,"round end never charges survival or SAN again: "+id)
		# Keep the late reward, release the original modifier, then actually depart.
		s=restored(s)
		s.state.phase="navigation"; s.state.node={}; s.Encounter.candidates(s)
		check(not s.state.candidates.is_empty(),"next round offers a destination: "+id)
		check(s.Collectibles.discard(s,s.state.collectibles.items[0].uid),"discard original modifier before next departure: "+id)
		var latest_costs: Dictionary=initial.duplicate(true)
		latest_costs[late_stat]=maxi(0,int(latest_costs[late_stat])-5)
		check(s.Survival.quote(s).costs==latest_costs,"next preview reflects both late acquisition and original discard: "+id)
		var next_food: int=s.state.player.hunger; var next_water: int=s.state.player.hydration
		check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"departure with latest held modifiers: "+id)
		check(s.state.player.hunger==maxi(0,next_food-int(latest_costs.hunger)) and s.state.player.hydration==maxi(0,next_water-int(latest_costs.hydration)),"next departure charges current holdings exactly once: "+id)
		# discard() clears holdings, while acquisition history remains serializable.
		for item in s.state.collectibles.items:
			if item.held: check(s.Collectibles.discard(s,item.uid),"discard held modifier: "+id)
		check(s.state.collectibles.items.all(func(item):return not item.held),"every acquired modifier is released: "+id)
		var base_next: Dictionary=s.Survival.quote(s).costs
		check(base_next.hunger==initial.hunger and base_next.hydration==initial.hydration,"discard restores the base preview: "+id)
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	test_pools();test_public_art();test_battle_restore_and_cross_layer();test_live_survival_modifiers()
	print("V03 RELIC INTEGRATION: %s" % ("PASS" if failures==0 else "FAIL"));quit(failures)
