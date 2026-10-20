extends SceneTree
const Session=preload("res://core/game_session.gd")
const IDS=["boss_shallows","boss_open_sea","boss_abyss"]
const EXPECTED={
	"boss_shallows":["redCoral","tideTablet","homeCompass","hunterSpear"],
	"boss_open_sea":["crimsonVial","crackedCarapace","foldingRule","drifterQuiver","scavengerSatchel"],
	"boss_abyss":["crimsonVial","hunterSpear","tideBoneBlade","foldingRule","sailorsKnot","drifterQuiver","barbedBundle"]
}
# Pool choices use permanent growth, battle modifiers, or multi-battle utility; they exclude immediate-only recovery relics.
var failures:=0
var checks:=0
var catalog
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func fresh():
	var s=Session.new(catalog); s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}); s._auto_advancing=true
	return s
func test_quality_pools() -> void:
	for id in IDS:
		var rewards: Dictionary=catalog.entry("nodes",id).get("rewards",{})
		var drops: Array=rewards.get("relics",[])
		check(drops.size()==1,""+id+" keeps exactly one collectible drop")
		if drops.is_empty(): continue
		var pool: Array=drops[0].get("pool",[])
		check(pool==EXPECTED[id],id+" uses explicit progressive quality pool")
		check(int(drops[0].get("amount",0))==1,id+" preserves single collectible count")
		check(not "glowConch" in pool and not "drifterMedkit" in pool,id+" excludes immediate-only recovery")
		for relic_id in pool:
			var effects: Array=catalog.entry("relics",relic_id).get("effects",[])
			check(effects.any(func(effect): return effect.type in ["grant_max","modifier","grant_card","install_level","probability"]),id+" reward has persistent/build/combat value: "+relic_id)
func boss_victory(id: String):
	var s=fresh(); var layer_id={"boss_shallows":"shallows","boss_open_sea":"open_sea","boss_abyss":"abyss"}[id]
	var index=0
	for i in range(s.Campaign.profile(s.catalog,s.state).layers.size()):
		if s.Campaign.profile(s.catalog,s.state).layers[i]==layer_id: index=i
	s.state.journey.layer_index=index
	s.state.journey.layer_voyage=int(s.catalog.entry("layers",layer_id).length)
	s.state.voyage=1
	for i in range(index): s.state.voyage+=int(s.catalog.entry("layers",s.Campaign.profile(s.catalog,s.state).layers[i]).length)
	s.state.node=catalog.entry("nodes",id); s.state.node.visit_id="boss-collectible-"+id; s.state.candidates=[]; s.state.phase="story"; s.state.story_step="choice"
	return s
func win_boss(s) -> bool:
	if not s.dispatch("fight"): return false
	s.state.battle.hp=1
	return s.dispatch("battle_action",{"action":"attack"})
func test_real_boss_awards() -> void:
	for id in IDS:
		var s=boss_victory(id); check(win_boss(s),id+" real victory completes")
		var obtained: Array=s.state.collectibles.items.map(func(item): return item.id)
		var pool: Array=EXPECTED[id]
		check(obtained.size()==1 and obtained[0] in pool,id+" victory draws from configured pool")
func test_exhausted_unique_pool_pays_coin() -> void:
	var s=boss_victory("boss_shallows"); var pool: Array=EXPECTED.boss_shallows
	for id in pool: check(s.Collectibles.acquire(s,id),"pre-own unique boss drop "+id)
	check(s.Collectibles.eligible_ids(s,pool).is_empty(),"all owned shallow Boss pool items are exhausted")
	var coins=int(s.state.coins); var item_count: int=s.state.collectibles.items.size()
	check(win_boss(s),"exhausted-pool Boss still wins")
	check(s.state.collectibles.items.size()==item_count,"exhausted unique pool grants no duplicate collectible")
	check(int(s.state.coins)==coins+4,"Boss coin reward plus exhausted-pool 2-coin exchange is paid")
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog loads")
	test_quality_pools(); test_real_boss_awards(); test_exhausted_unique_pool_pays_coin()
	print("BOSS COLLECTIBLE POOLS: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]); quit(failures)
