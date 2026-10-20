extends SceneTree
const Shop=preload("res://core/shop_rules.gd")
var failures:=0
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func fresh(catalog, profile_id: String="default", mode: String="challenge"):
	var s=load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",load("res://core/tutorial_rules.gd").start_args() if mode=="tutorial" else {"seed":22,"origin":"strong","mode":mode})
	s.state.node={"id":"trader","kind":"shop","visit_id":"shop-config-test","shop_profile":profile_id}
	s.state.phase="interaction"; s.state.coins=10000; s.state.shop={}
	return s
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	catalog._tables.shop_profiles={"default":{"resource_slots":3,"equipment_slots":3,"relic_slots":3,"resource_limit":2,"equipment_limit":1,"resource_base_price":1,"resource_price_multiplier":2,"corpse_sell_price":3,"other_sell_price":1},"small":{"resource_slots":2,"equipment_slots":1,"relic_slots":1,"resource_limit":3,"equipment_limit":2,"resource_base_price":2,"resource_price_multiplier":3,"corpse_sell_price":7,"other_sell_price":4}}
	check(Shop.valid_content(catalog._tables),"valid default and alternate shop profiles")
	for value in [-1,1.5,true,"3"]:
		var tables: Dictionary=catalog._tables.duplicate(true); tables.shop_profiles.small.resource_slots=value
		check(not Shop.valid_content(tables),"reject malformed slot count "+str(value))
	for field in ["resource_limit","equipment_limit","resource_base_price","resource_price_multiplier","corpse_sell_price","other_sell_price"]:
		var tables: Dictionary=catalog._tables.duplicate(true); tables.shop_profiles.small[field]=0
		check(not Shop.valid_content(tables),"reject nonpositive shop parameter "+field)
	var invalid: Dictionary=catalog._tables.duplicate(true); invalid.nodes.trader.shop_profile="missing"
	check(not Shop.valid_content(invalid),"reject unknown node shop profile")
	invalid=catalog._tables.duplicate(true); invalid.shop_profiles.small.resource_slots=6
	check(not Shop.valid_content(invalid),"reject unavailable resource shelf size")
	invalid=catalog._tables.duplicate(true); invalid.shop_profiles.small.extra=1
	check(not Shop.valid_content(invalid),"reject unknown shop profile fields")
	var ordinary=fresh(catalog)
	check(Shop.enter(ordinary) and ordinary.state.shop.stock.size()==6,"defaults preserve six goods")
	var s=fresh(catalog,"small")
	check(Shop.enter(s),"configured shelf generation")
	var initial: Dictionary=s.snapshot()
	check(Shop.enter(s) and s.snapshot()==initial,"same visit does not redraw configured shelf")
	var view: Dictionary=Shop.view(s)
	check(view.stock.size()==3 and view.stock.filter(func(row):return row.kind=="resource").size()==2 and view.relic_stock.size()==1 and view.relic_slots==1,"configured shelf slots")
	var resource: Dictionary=view.stock.filter(func(row):return row.kind=="resource")[0]
	check(resource.price==2 and resource.limit==3,"configured resource price and limit")
	var device: Dictionary=view.stock.filter(func(row):return row.kind=="equipment")[0]
	check(device.limit==2 and device.base_price==catalog.entry("shops",device.id).price,"equipment keeps table price and configurable limit")
	check(Shop.buy(s,{"id":device.id}) and Shop.buy(s,{"id":device.id}) and not Shop.buy(s,{"id":device.id}),"configured equipment purchase limit enforced")
	check(Shop.buy(s,{"id":resource.id}),"configured first resource purchase")
	check(Shop._quote(s,resource.id).price==6,"configured shared resource price multiplier")
	check(Shop.buy(s,{"id":resource.id}) and Shop.buy(s,{"id":resource.id}),"configured third resource available")
	check(not Shop.buy(s,{"id":resource.id}),"configured resource limit enforced")
	s.give("corpse"); s.give("medkit")
	for id in ["corpse","medkit"]:
		var card: Dictionary=s.state.hand.filter(func(row):return row.id==id)[0]
		var coins: int=s.state.coins
		check(Shop.sell(s,{"uid":card.uid}) and s.state.coins==coins+(7 if id=="corpse" else 4),"configured sell price "+id)
	check(Shop.valid_state(s,s.state),"configured stock validates")
	var forged: Dictionary=s.state.duplicate(true); forged.shop.profile_id="default"
	check(not Shop.valid_state(s,forged),"saved shelf profile must match current node")
	forged=s.state.duplicate(true); forged.shop.stock.pop_back()
	check(not Shop.valid_state(s,forged),"saved shelf slot shape must match profile")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(s.state))
	check(Shop.valid_state(s,saved),"configured stock JSON roundtrip validates")
	saved.shop.purchased[device.id]=3; check(not Shop.valid_state(s,saved),"overlimit saved purchase rejected")
	saved=s.state.duplicate(true); saved.node={"id":"rest","kind":"rest","visit_id":"next"}; saved.phase="aftermath"
	check(Shop.valid_state(s,saved),"past shelf retains its profile after leaving shop node")
	var tutorial=fresh(catalog,"small","tutorial")
	check(Shop.enter(tutorial) and tutorial.state.shop.stock==load("res://core/tutorial_rules.gd").fixed_stock() and Shop.valid_state(tutorial,tutorial.state),"tutorial fixed stock/default profile preserved")
	print("V03 SHOP: "+("PASS" if failures==0 else "FAIL")); quit(failures)
