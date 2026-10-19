extends SceneTree
var failures:=0
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init():
	if not ResourceLoader.exists("res://application/acquisition_projection.gd"):
		check(false,"acquisition projection is missing"); quit(1); return
	var projection=load("res://application/acquisition_projection.gd")
	var catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	var s=load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	var cursor: Dictionary=projection.capture(s)
	check(s.dispatch("salvage"),"real salvage")
	var saved: Dictionary=s.snapshot()
	var batches: Array=projection.batches(s,cursor)
	check(batches.size()==1 and batches[0].source=="打捞" and batches[0].items.size()==1,"salvage card batch")
	check(projection.batches(s,projection.capture(s)).is_empty(),"no repeated rewards")
	check(s.snapshot()==saved,"projection does not mutate state or RNG")
	var presented: Dictionary=s.view()
	projection.apply_pending(presented,projection.pending(batches))
	check(not presented.hand.any(func(card):return card.uid==batches[0].items[0].uid),"pending receipt is excluded from HUD hand")
	check(s.snapshot()==saved,"pending HUD projection does not mutate committed rewards")
	var currency_view: Dictionary={"hand":[{"uid":"coins","id":"coin","quantity":7},{"uid":"waiting","id":"wood"}],"coins":7,"capacity":2}
	projection.apply_pending(currency_view,{"uids":["waiting"],"coins":2})
	check(currency_view.hand.size()==1 and currency_view.hand[0].quantity==5 and currency_view.capacity==1,"pending coin gain does not reveal new quantity or extra capacity")
	s.state.hand=[]; s.state.coins=0; s.state.phase="aftermath"
	cursor=projection.capture(s); check(s.dispatch("end_voyage"),"next voyage")
	batches=projection.batches(s,cursor)
	check(batches.size()==1 and batches[0].source=="涌泉" and batches[0].items.size()==2,"spring counts actual cards")
	cursor=projection.capture(s)
	check(s.Collectibles.acquire(s,"lifeboatTag"),"new relic")
	batches=projection.batches(s,cursor)
	check(batches.size()==1 and batches[0].kind=="collectible" and batches[0].items[0].id=="lifeboatTag","relic acquisition")
	cursor=projection.capture(s); s.dispatch("abandon"); s.dispatch("new",{"mode":"challenge","origin":"strong","seed":23})
	check(projection.batches(s,cursor).is_empty(),"new run does not replay initial cards")
	print("ACQUISITION PROJECTION: "+("PASS" if failures==0 else "FAIL")); quit(failures)
