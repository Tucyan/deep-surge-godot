extends SceneTree
var failures := 0
var catalog
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func battle_session():
	var s=load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":17})
	s.state.hand=[]
	s.state.phase="battle"
	s.state.node=catalog.entry("nodes","battle"); s.state.node.visit_id="actions"
	s.state.battle={"id":"biter","hp":30,"turn":1,"ap":3,"entry_hp":40,"poison_until":0,"fear_until":0,"shields":[]}
	return s
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	var s=battle_session()
	check(s.dispatch("battle_action",{"action":"attack"}),"fixed attack is dispatched without a hand card")
	check(s.state.battle.hp==29 and s.state.battle.ap==2 and s.state.hand.is_empty(),"fixed attack costs one AP and deals one damage")
	s.state.battle.ap=3
	check(s.dispatch("battle_action",{"action":"block"}),"fixed block is dispatched")
	check(s.state.battle.shields.size()==1 and s.state.battle.shields[0].amount==1,"block creates one expiring shield layer")
	s.state.hand=[]; s.give("wood"); var wood=s.state.hand[-1].uid
	check(s.dispatch("battle_action",{"action":"attack","resource_uid":wood}),"wood attack consumes a real resource")
	check(s.state.battle.hp==28 and s.state.hand.is_empty(),"wood attack deals one damage plus player damage only")
	# A direct attack uses the oldest layer first; poison still bypasses shields.
	s.state.battle.shields=[{"uid":"old","source":"test","amount":1,"expires_turn":1,"extendable":false,"extended":false},{"uid":"new","source":"test","amount":2,"expires_turn":2,"extendable":false,"extended":false}]
	var hp=s.state.player.hp
	s.state.battle.ap=0
	check(s.dispatch("battle_end"),"enemy turn resolves with shield layers")
	check(s.state.player.hp==hp and s.state.battle.shields.size()==1 and s.state.battle.shields[0].uid=="new","oldest shield absorbs direct damage before the later layer")
	# Material combinations have their specified total effects.
	s.state.battle.shields=[]; s.state.battle.ap=3; s.state.hand=[]; s.give("wood")
	check(s.dispatch("battle_action",{"action":"block","resource_uid":s.state.hand[-1].uid}),"wood block uses a resource")
	check(s.state.battle.shields[0].amount==3,"wood block produces three total shield")
	s.state.battle.ap=3; s.state.hand=[]; s.give("plastic")
	check(s.dispatch("battle_action",{"action":"block","resource_uid":s.state.hand[-1].uid}),"plastic block is valid")
	var plastic=s.state.battle.shields[-1]
	check(plastic.amount==2 and plastic.extendable,"plastic block totals two and may extend")
	s.state.battle.ap=3; s.state.hand=[]; s.give("cloth"); s.give("pollution",1,true,"battle")
	s.state.battle.poison_until=2
	check(s.dispatch("battle_action",{"action":"block","resource_uid":s.state.hand[0].uid}),"cloth block clears one ongoing condition")
	check(s.state.battle.poison_until==0 and s.state.hand.filter(func(c):return c.id=="pollution").size()==1,"cloth clears poison and leaves pollution card")
	s.state.battle.ap=3; s.state.battle.shields=[]; s.state.hand=[]; s.give("rope")
	check(s.dispatch("battle_action",{"action":"attack","resource_uid":s.state.hand[-1].uid}),"rope attack is valid")
	var hp_before=s.state.player.hp
	check(s.dispatch("battle_end"),"rope attack enemy turn resolves")
	check(s.state.player.hp==hp_before,"rope attack reduces the next direct enemy hit by one")
	# Invalid boost attachment and read-only preview cannot consume state.
	# Previous biter turns damaged this fixture's first cell. Use a working
	# generator for the independent valid-attachment assertion below.
	s.state.cells[0].status="intact"; s.state.cells[0].damaged_at=0
	s.state.cells[0].equipment={"id":"generator","level":1,"fuel":0,"progress":0,"boost_cards":[{"uid":"boost-test","id":"barrier"}],"production_bonus":0}
	s.state.battle.ap=2
	var unchanged=s.snapshot()
	check(not s.dispatch("battle_action",{"action":"block","buff_uid":"missing"}),"bad buff uid is rejected")
	check(s.snapshot()==unchanged,"invalid boost attachment is atomic")
	s.give("wood")
	check(s.dispatch("battle_action",{"action":"attack","resource_uid":s.state.hand[-1].uid,"buff_uid":"boost-test"}),"barrier can attach to a wood attack that produces shield")
	check(s.state.battle.shields.size()==2 and s.state.battle.shields[0].expires_turn==s.state.battle.turn and s.state.battle.shields[1].source=="barrier" and s.state.battle.shields[1].expires_turn==s.state.battle.turn+1,"barrier adds a separate next-enemy-action shield layer")
	unchanged=s.snapshot(); var preview=s.Battle.preview(s,{"action":"attack"})
	check(preview.valid and s.snapshot()==unchanged,"battle preview is valid and cannot mutate or draw active RNG")
	print("BATTLE ACTIONS: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
