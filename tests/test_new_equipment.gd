extends SceneTree
var failures := 0
var catalog
const I=preload("res://core/inventory.gd")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func base_session():
	var s=load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":31})
	s.state.hand=[]; s.state.phase="preparation"; s.state.ap=3
	s.state.node=catalog.entry("nodes","camp"); s.state.node.visit_id="equip"
	return s
func equip(s,id,cell="cell-0"):
	s.give(id); var card=s.state.hand[-1]
	return s.dispatch("install",{"uid":card.uid,"cell":cell})
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	var s=base_session()
	check(equip(s,"crate"),"crate installs as equipment")
	check(I.hand_limit(s.state,catalog)==13,"intact level-one crate projects three additional hand slots")
	s.state.cells[0].status="damaged"
	check(I.hand_limit(s.state,catalog)==10,"damaged crate no longer increases capacity")
	var net=base_session()
	check(equip(net,"fishingNet"),"fishing net installs")
	net.state.phase="aftermath"
	check(net.dispatch("end_voyage"),"fishing net produces when the next voyage starts")
	check(net.state.hand.filter(func(c):return c.source=="production").size()==1,"fishing net produces one base resource each voyage")
	var generator=base_session()
	check(equip(generator,"generator"),"generator installs")
	generator.give("corpse")
	check(generator.dispatch("fuel",{"cell":"cell-0","material":"corpse"}),"generator accepts corpse fuel")
	check(generator.state.cells[0].equipment.fuel==3,"one corpse supplies three fuel units")
	# Production is claimed through a deterministic choice among three boost types.
	generator.state.cells[0].equipment.progress=1; generator.state.phase="aftermath"
	check(generator.dispatch("end_voyage"),"generator production cycle advances at next round start")
	check(generator.state.cells[0].equipment.boost_cards.size()==1,"completed generator cycle stores a ready boost")
	var boost=generator.state.cells[0].equipment.boost_cards[0]
	check(generator.dispatch("claim_boost",{"cell":"cell-0","id":"barrier"}),"claim selects a boost effect")
	check(generator.state.cells[0].equipment.boost_cards.size()==1,"claim keeps the chosen buff in the same storage slot")
	check(boost.uid=="boost-1" and generator.state.cells[0].equipment.boost_cards[0].uid==boost.uid and generator.state.cells[0].equipment.boost_cards[0].id=="barrier","claim keeps uid and changes ready to selected type")
	# A production buff is consumed only after a valid target is chosen, and only at production.
	var producer=base_session()
	check(equip(producer,"generator","cell-0"),"second generator installs")
	check(equip(producer,"filter","cell-1"),"filter installs as boost target")
	producer.state.cells[0].equipment.boost_cards=[{"uid":"boost-prod","id":"production"}]
	var before=producer.snapshot()
	check(not producer.dispatch("boost_device",{"cell":"cell-2","buff_uid":"boost-prod"}),"invalid boost target rejected")
	check(producer.snapshot()==before,"invalid boost target leaves boost and state unchanged")
	check(producer.dispatch("boost_device",{"cell":"cell-1","buff_uid":"boost-prod"}),"production buff attaches to filter")
	check(producer.state.cells[1].equipment.production_bonus==1 and producer.state.cells[0].equipment.boost_cards.is_empty(),"production buff is consumed once on attachment")
	producer.state.cells[1].equipment.progress=1; producer.state.phase="aftermath"
	check(producer.dispatch("end_voyage"),"production bonus resolves at next round start")
	check(producer.state.stats.devices["filter/cell-1"].outputs.water==2,"production bonus adds one item for exactly this completed cycle")
	# Current saves validate their new fields, old content versions migrate punch.
	var battle=base_session(); battle.state.phase="battle"; battle.state.node=catalog.entry("nodes","battle")
	battle.state.battle={"id":"biter","hp":4,"turn":1,"ap":2,"entry_hp":battle.state.player.hp,"poison_until":0,"fear_until":0,"shields":[{"uid":"shield-1","source":"test","amount":2,"expires_turn":2,"extendable":false,"extended":false}]}
	battle.state.next_shield_id=2; battle.state.next_boost_id=1
	var snapshot=battle.snapshot(); var loaded=load("res://core/game_session.gd").new(catalog)
	check(loaded.restore(JSON.parse_string(JSON.stringify(snapshot))),"layered shields survive JSON save restore")
	check(loaded.state.battle.shields[0].amount==2,"restored shield keeps its amount")
	var malformed=snapshot.duplicate(true); malformed.state.battle.shields[0].amount="many"
	check(not loaded.restore(malformed),"strict save validation rejects malformed shield amount")
	var old=snapshot.duplicate(true); old.content_version="godot-flow-v02-4"; old.fingerprint=catalog.previous_balance_fingerprint()
	old.state.hand=[{"uid":"card-old","id":"punch","temporary":true,"source":"battle"}]
	check(not loaded.restore(old),"Demo development rejects previous content versions")
	check(loaded.state.hand.filter(func(c):return c.id=="punch").is_empty(),"old in-hand punch migrates to fixed attack")
	old.fingerprint="not-a-known-hash"
	check(not loaded.restore(old),"unknown old fingerprint is rejected")
	print("NEW EQUIPMENT: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
