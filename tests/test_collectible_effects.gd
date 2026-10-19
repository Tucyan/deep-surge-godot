extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func _initialize() -> void:
	check(ResourceLoader.exists("res://core/collectible_rules.gd"),"collectible acquisition foundation exists")
	if failures: quit(1); return
	var c=load("res://core/collectible_rules.gd")
	var q=load("res://core/effect_query.gd")
	var e=load("res://core/effect_rules.gd")
	var catalog=load("res://content/catalog.gd").new()
	catalog._tables={"cards":{"arrow":{}},"relics":{"test":{"name":"Test","description":"Composed","enabled":true,"price":2,"effects":[
		{"key":"max","type":"grant_max","stat":"hp","amount":3},
		{"key":"heal","type":"restore","stat":"hp","amount":2},
		{"key":"food","type":"modifier","target":"survival.hunger_cost","amount":-4},
		{"key":"card","type":"grant_card","trigger":"battle_start","id":"arrow","amount":2,"temporary":true,"uses":1},
		{"key":"install","type":"install_level","level":2,"uses":2},
		{"key":"temp","type":"temporary_max","trigger":"battle_start","stat":"hp","amount":2,"heal":2,"uses":1},
		{"key":"chance","type":"probability","target":"enchant_preserve","chance":0.25}]}}}
	var ctx=Fixture.new(); ctx.catalog=catalog
	c.initialize(ctx.state)
	check(c.acquire(ctx,"test"),"acquire composed item")
	var uid: String=ctx.state.collectibles.items[0].uid
	check(ctx.state.player.hp_max==13 and ctx.state.player.hp==9,"permanent maximum and bounded restore")
	check(q.survival_costs(ctx.state,catalog,{"hunger":2,"hydration":3})=={"hunger":0,"hydration":3},"survival costs clamp")
	check(q.probability(ctx.state,catalog,"enchant_preserve")==0.25,"probability composed")
	var before=ctx.state.duplicate(true)
	var plan=q.install_plan(ctx.state,catalog,{"level":1},{})
	check(plan.level==2 and plan.uses.size()==1 and ctx.state==before,"installation query pure")
	e.commit_uses(ctx,plan.uses+plan.uses)
	check(ctx.state.collectibles.items[0].effects.install.remaining==1,"duplicate consumption reference counted once")
	ctx.state.battle={"id":"test"}; ctx.state.phase="battle"; e.trigger(ctx,"battle_start")
	check(ctx.state.hand.size()==2 and ctx.state.player.hp==11 and q.effective_max(ctx.state,catalog,"hp")==15,"battle grants and temporary maximum")
	e.trigger(ctx,"battle_start")
	check(ctx.state.hand.size()==2 and ctx.state.player.hp==11,"exhausted battle grants never repeat")
	check(c.valid(ctx,JSON.parse_string(JSON.stringify(ctx.state))),"JSON runtime validates")
	var bad=ctx.state.duplicate(true); bad.collectibles.items[0].effects.temp.remaining=-1
	check(not c.valid(ctx,bad),"validation inspects supplied state and rejects negative counter")
	bad=ctx.state.duplicate(true); bad.battle={}
	check(not c.valid(ctx,bad),"active temporary maximum outside battle rejected")
	bad=ctx.state.duplicate(true); bad.phase="story"
	check(not c.valid(ctx,bad),"active temporary maximum outside battle phase rejected")
	bad=ctx.state.duplicate(true); bad.battle.collectible_effects_started="yes"
	check(not c.valid(ctx,bad),"battle activation marker must be boolean")
	bad=ctx.state.duplicate(true); bad.battle="invalid"
	check(not c.valid(ctx,bad),"invalid battle runtime rejected without crashing")
	ctx.state.player.hp=15
	check(c.discard(ctx,uid) and ctx.state.player.hp==13,"discard deactivates temporary maximum and clamps")
	check(q.modifier(ctx.state,catalog,"survival.hunger_cost")==0,"discard removes held modifier")
	check(c.acquire(ctx,"test",uid) and ctx.state.player.hp_max==13,"rehold does not repeat permanent acquisition grants")
	check(ctx.state.collectibles.items[0].effects.card.remaining==0,"rehold preserves spent charges")
	check(c.project(ctx).size()==1 and c.project(ctx)[0].uid==uid,"public held projection")
	e.trigger(ctx,"battle_end"); ctx.state.battle={}
	check(c.valid(ctx,ctx.state),"ended battle state validates")
	var empty: Dictionary=ctx.state.duplicate(true); c.initialize(empty); empty.collectibles.next_id=3
	check(not c.valid(ctx,empty),"empty runtime rejects invented next id")
	bad=ctx.state.duplicate(true); bad.collectibles.items[0].effects.install.source_uid="invented"
	check(not c.valid(ctx,bad),"runtime rejects invented source references")
	var before_query: Dictionary=ctx.state.duplicate(true)
	check(q.effective_max({},catalog,"hp")==1 and q.modifier({},catalog,"battle.damage")==0,"queries tolerate uninitialized state")
	check(q.install_plan(ctx.state,catalog,{"level":2},{}).uses.is_empty() and ctx.state==before_query,"already upgraded installation consumes nothing")
	catalog._tables.relics.test.effects[3].id="absent"
	check(not c.valid(ctx,ctx.state),"saved grant rejects unknown card definition")
	catalog._tables.relics.test.effects[3].id="arrow"
	var invalid_definition: Dictionary=catalog._tables.relics.test.duplicate(true)
	invalid_definition.effects[2].target="unsupported"
	check(not c.valid_definitions({"invalid":invalid_definition}),"unsupported modifier targets rejected")
	invalid_definition=catalog._tables.relics.test.duplicate(true); invalid_definition.effects[6].target="unsupported"
	check(not c.valid_definitions({"invalid":invalid_definition}),"unsupported probability targets rejected")
	ctx.state.mode="tutorial"
	check(not c.acquire(ctx,"test"),"tutorial cannot acquire collectible")
	check(not c.valid(ctx,ctx.state),"forged tutorial snapshot cannot retain collectibles")
	var tutorial_empty: Dictionary=ctx.state.duplicate(true); c.initialize(tutorial_empty)
	check(c.valid(ctx,tutorial_empty),"tutorial empty collectible runtime remains valid")
	ctx.state.erase("mode")
	var multi=Fixture.new(); multi.catalog=catalog; c.initialize(multi.state)
	catalog._tables.relics.multi={"name":"Multi","description":"Two battles","enabled":true,"price":1,"effects":[{"key":"card","type":"grant_card","trigger":"battle_start","id":"arrow","amount":1,"temporary":true,"uses":2}]}
	check(c.acquire(multi,"multi"),"acquire multi battle item")
	multi.state.battle={"id":"same"}; multi.state.phase="battle"
	e.trigger(multi,"battle_start"); e.trigger(multi,"battle_start")
	check(multi.state.hand.size()==1 and multi.state.collectibles.items[0].effects.card.remaining==1,"duplicate event cannot consume a second battle charge")
	e.trigger(multi,"battle_end"); multi.state.battle={"id":"same"}
	e.trigger(multi,"battle_start")
	check(multi.state.hand.size()==2 and multi.state.collectibles.items[0].effects.card.remaining==0,"new battle with same enemy consumes next charge")
	catalog._tables.relics.bad={"enabled":true,"price":1,"effects":[{"key":"x","type":"unknown"}]}
	check(not c.acquire(ctx,"bad"),"unknown effects rejected atomically")
	print("collectible effects: ","PASS" if failures==0 else "FAIL", " (", failures, ")")
	quit(1 if failures else 0)
class Fixture extends RefCounted:
	var state={"player":{"hp":7,"hp_max":10,"hunger":10,"hunger_max":100,"hydration":10,"hydration_max":100,"sanity":10,"sanity_max":100},"battle":{},"hand":[],"next_id":1}
	var catalog
