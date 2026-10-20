extends SceneTree
const Catalog=preload("res://content/catalog.gd")
const Session=preload("res://core/game_session.gd")
const Survival=preload("res://core/survival_rules.gd")
const Difficulty=preload("res://core/difficulty_rules.gd")
var failures:=0
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void:
	var c=Catalog.new()
	check(c.load_catalog(),"catalog")
	var s=Session.new(c)
	check(s.dispatch("new",{"mode":"challenge","difficulty":"standard","origin":"strong","seed":91}),"start")
	var hp=[[10,22,30],[12,28,38],[14,34,46]]
	var damage=[[1,2,3],[1,3,4],[2,3,5]]
	var costs=[[20,30,40],[22,33,44],[24,36,48]]
	for d in range(3):
		s.state.difficulty=["standard","hard","nightmare"][d]
		for layer in range(3):
			s.state.journey.layer_index=layer
			var q: Dictionary=Survival.base_costs(s)
			check(q.hunger==costs[d][layer] and q.hydration==costs[d][layer],"nine food/water costs %d/%d"%[d,layer])
			check(q.sanity==int(c.entry("balance","survival").sanity),"SAN has no difficulty fee")
			var node: Dictionary=s.Campaign.boss_node(c,s.state)
			var enemy: Dictionary=Difficulty.enemy(c,s.state,node.monster)
			check(enemy.hp==hp[d][layer] and enemy.damage==damage[d][layer],"exact current Boss target %d/%d"%[d,layer])
			check(str(enemy.intent).contains("生命−"+str(enemy.damage)),"Boss intent matches target damage")
			var ordinary: Dictionary=Difficulty.enemy(c,s.state,"crab")
			var bonus: float=float(c.entry("difficulties",s.state.difficulty).enemy_bonus)+float(s.Campaign.layer(c,s.state).enemy_hp_bonus)
			check(ordinary.hp==roundi(9*(1+bonus)),"ordinary enemy retains formula")
	s.state.difficulty="hard"; s.state.journey.layer_index=1
	s.state.buffs=[{"id":"rain","active_from":1,"remaining":2}]
	check(Survival.base_costs(s).hunger==48,"weather +15 follows rounded 30*1.1")
	s.state.flags.avoidWave=true
	check(Survival.base_costs(s).hunger==43,"avoidWave subtracts five after multiplier/weather")
	s.state.phase="action"; s.state.voyage=7
	Survival.lock_costs(s)
	s.state.buffs=[]
	check(Survival.costs(s).hunger==43,"environment changes do not reprice locked cost")
	check(Survival.valid(s,s.state),"locked basis revalidates without current weather")
	var tampered: Dictionary=s.state.duplicate(true)
	tampered.flags.voyage_survival_costs.hunger+=1; tampered.flags.voyage_survival_cost+=1
	check(not Survival.valid(s,tampered),"tampered locked fee rejected")
	tampered=s.state.duplicate(true); tampered.difficulty="nightmare"
	check(not Survival.valid(s,tampered),"locked basis binds difficulty")
	for mode in ["story","tutorial"]:
		s.state.mode=mode; s.state.journey.layer_index=0
		check(Survival.base_costs(s).hunger==30,"nonchallenge food unchanged "+mode)
		var boss: Dictionary=Difficulty.enemy(c,s.state,"boss")
		var tier: Dictionary=c.entry("difficulties",s.state.difficulty)
		check(boss.hp==roundi(18*(1+float(tier.boss_bonus))),"nonchallenge Boss retains formula "+mode)
	s.state.mode="challenge"; s.state.difficulty="standard"; s.state.flags={}; s.state.voyage=20
	s.state.player.hp_max=200; s.state.player.hp=200
	s.state.deprivation={"hunger":0,"hydration":0}
	for n in range(7):
		s.state.journey.layer_index=mini(n,2)
		s.state.player.hunger=0; s.state.player.hydration=100
		s.state.flags.voyage_survival_costs={"hunger":0,"hydration":0}
		var before: int=s.state.player.hp
		Survival.settle(s)
		check(s.state.player.hp==before-mini(n+1,5),"<=0 shortage step one cap five across layers")
	check(s.state.deprivation.hunger==7 and s.state.deprivation.hydration==0,"independent counts persist across layers")
	var persisted=Session.new(c)
	check(persisted.dispatch("new",{"mode":"challenge","difficulty":"hard","origin":"strong","seed":91}),"hard save scenario starts")
	persisted.state.flags.avoidWave=true
	check(persisted.EnvironmentRules.add(persisted,"rain",true),"apply departure rain")
	check(persisted.dispatch("voyage",{"id":persisted.state.candidates[0].visit_id}),"real departure locks cost")
	persisted.state.buffs=[]
	var saved: Dictionary=JSON.parse_string(JSON.stringify(persisted.snapshot()))
	var restored=Session.new(c)
	check(restored.restore(saved),"JSON restore retains historical weather basis")
	check(Survival.costs(restored).hunger==32,"restored hard shallows fee is 22+15-5")
	var bad_save: Dictionary=saved.duplicate(true)
	bad_save.state.flags.voyage_survival_costs.hunger+=1
	bad_save.state.flags.voyage_survival_cost+=1
	var restored_before: Dictionary=restored.snapshot()
	check(not restored.restore(bad_save),"actual restore rejects coordinated scalar/map fee tampering")
	check(restored.snapshot()==restored_before,"rejected restore preserves session")
	var stripped: Dictionary=saved.duplicate(true)
	for key in ["voyage_survival_costs","voyage_survival_cost","voyage_cost_basis"]: stripped.state.flags.erase(key)
	check(not restored.restore(stripped),"actual restore rejects removal of all departure fee fields")
	for phase in ["preparation","story","interaction","battle","aftermath","discard"]:
		var pending: Dictionary=saved.state.duplicate(true)
		pending.phase=phase
		check(Survival.valid(persisted,pending),"pending voyage accepts complete fee at "+phase)
		for key in ["voyage_survival_costs","voyage_survival_cost","voyage_cost_basis"]: pending.flags.erase(key)
		check(not Survival.valid(persisted,pending),"pending voyage requires fee at "+phase)
	var ended: Dictionary=saved.state.duplicate(true)
	ended.phase="finished"
	check(Survival.valid(persisted,ended),"finished before survival may retain lock")
	for key in ["voyage_survival_costs","voyage_survival_cost","voyage_cost_basis"]: ended.flags.erase(key)
	check(Survival.valid(persisted,ended),"finished after survival may omit settled lock")
	var tables: Dictionary=c._tables.duplicate(true)
	for bad in [-1.0,INF,NAN,"1"]:
		var mutated: Dictionary=tables.duplicate(true)
		mutated.difficulty_stage_profiles["hard:shallows"]["survival_multipliers"]={"hunger":bad,"hydration":1.1}
		check(not Catalog.valid_difficulty_stage_profiles(mutated),"invalid survival multiplier rejected "+str(bad))
	var missing: Dictionary=tables.duplicate(true)
	missing.difficulty_stage_profiles["hard:shallows"].erase("survival_multipliers")
	check(not Catalog.valid_difficulty_stage_profiles(missing),"required survival multipliers")
	var fourth: Dictionary=tables.duplicate(true)
	fourth.layers["fourth"]=fourth.layers.abyss.duplicate(true); fourth.layers.fourth.id="fourth"
	fourth.journeys.challenge.layers.append("fourth")
	for d in Difficulty.CHALLENGE_IDS:
		var id: String=d+":fourth"
		fourth.difficulty_stage_profiles[id]=fourth.difficulty_stage_profiles[d+":abyss"].duplicate(true)
		fourth.difficulty_stage_profiles[id].id=id; fourth.difficulty_stage_profiles[id].layer="fourth"
		fourth.difficulty_stage_profiles[id].continuous_battle_limit=4
	check(Catalog.valid_difficulty_stage_profiles(fourth),"profile matrix derives fourth layer; streak limit independent of slot count")
	fourth.difficulty_stage_profiles.erase("hard:fourth")
	check(not Catalog.valid_difficulty_stage_profiles(fourth),"missing fourth-layer profile rejected")
	print("V03 STAGE BALANCE: %s"%("PASS" if failures==0 else "FAIL")); quit(failures)
