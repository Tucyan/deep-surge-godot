extends SceneTree
const Session=preload("res://core/game_session.gd")
const Query=preload("res://core/action_query.gd")
var failures:=0
var checks:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"load catalog")
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"new")
	s._auto_advancing=true
	s.state.node=catalog.entry("nodes","trader"); s.state.node.visit_id="collectible-shop"
	s.state.phase="story"; s.state.story_step="choice"; s.state.candidates=[]
	s.Survival.lock_costs(s); s.Encounter.arrived(s)
	check(s.dispatch("shop_enter"),"enter actual shop")
	var view=s.view()
	if not view.shop.has("relic_stock"):
		check(false,"formal shop exposes enabled collectible shelf"); quit(failures); return
	check(view.shop.relic_stock.size()==3,"three collectible offers")
	var before=s.snapshot()
	s.view(); Query.list_actions(s)
	check(s.snapshot()==before,"view and quotes preserve state and RNG")
	var offer: Dictionary=view.shop.relic_stock[0]
	check(not s.dispatch("buy_collectible",{"id":offer.id}),"insufficient coins rejected")
	check(s.snapshot()==before,"rejected purchase rollback")
	s.give("coin",50)
	check(Query.list_actions(s).any(func(a):return a.command=="buy_collectible"),"Agent can purchase")
	check(s.dispatch("buy_collectible",{"id":offer.id,"payment":"coin"}),"purchase collectible")
	check(s.view().collectibles.size()==1,"held projection")
	check(s.state.coins==50-int(offer.price),"purchase charged once")
	var uid: String=s.view().collectibles[0].uid
	before=s.snapshot()
	check(not s.dispatch("buy_collectible",{"id":offer.id}),"shelf once only")
	check(s.snapshot()==before,"duplicate buy rollback")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()))
	var copy=Session.new(catalog)
	check(copy.restore(saved),"same-version full save restores")
	check(copy.view().collectibles==s.view().collectibles,"restored effects projection")
	check(copy.state.shop==saved.state.shop and copy.state.rng==saved.state.rng,"no shelf reroll on restore")
	check(s.dispatch("shop_leave") and s.dispatch("advance"),"leave actual shop to aftermath")
	check(Query.list_actions(s).any(func(a):return a.command=="discard_collectible" and a.args.uid==uid),"Agent discard exposed")
	check(s.dispatch("panel",{"id":"collectibles"}),"held collection panel")
	check(s.dispatch("discard_collectible",{"uid":uid}),"discard by instance")
	check(s.view().collectibles.is_empty(),"discard removes active projection")
	before=s.snapshot()
	check(not s.dispatch("discard_collectible",{"uid":uid}) and s.snapshot()==before,"duplicate discard refused")
	check(not s.dispatch("acquire_collectible",{"id":offer.id}),"no arbitrary grant command")
	var bad=saved.duplicate(true); bad.state.collectibles.items[0].effects={"invented":{"remaining":99,"active":true}}
	check(not copy.restore(bad),"invalid effect runtime rejected")
	print("COLLECTIBLE INTEGRATION: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(failures)
