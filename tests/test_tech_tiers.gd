extends SceneTree
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"Catalog loads: "+catalog.error)
	var tech: Dictionary=catalog.table("tech")
	check(tech.size()==6 and tech.knowledge.get("tier")==1 and tech.spear.get("tier")==2,"Six nodes in two tiers")
	if tech.size()!=6: quit(1); return
	var Session=load("res://core/game_session.gd")
	var Query=load("res://core/action_query.gd")
	var s=Session.new(catalog); s.profile.points=50
	s.dispatch("panel",{"id":"meta_shop"})
	var before: Dictionary=s.snapshot()
	var q: Dictionary=Query.quote(s,"tech",{"id":"spear"})
	check(not q.allowed and q.reason.contains("2"),"Tier two blocked at zero first-tier nodes")
	check(Query.list_actions(s,true).any(func(a):return a.command=="tech" and a.args.id=="spear" and not a.allowed),"Query lists locked node")
	check(s.view().tech_tree.tiers[1].unlocked==false,"Projection shows locked second tier")
	check(s.snapshot()==before,"Quotes and views preserve state/RNG")
	check(not s.dispatch("tech",{"id":"spear"}) and s.snapshot()==before,"Direct command cannot bypass gate")
	check(s.dispatch("tech",{"id":"endurance"}),"Any first-tier node can be lit first")
	check(s.profile.points==46,"Individual first-tier price")
	check(not Query.quote(s,"tech",{"id":"spear"}).allowed,"One node is below gate")
	check(s.dispatch("tech",{"id":"knowledge"}),"Light second first-tier node")
	check(s.view().tech_tree.tiers[1].unlocked,"Two first-tier nodes unlock tier two")
	check(Query.quote(s,"tech",{"id":"spear"}).allowed,"Tier two allowed without craft chain")
	check(s.dispatch("tech",{"id":"spear"}) and s.profile.points==34,"Tier-two exact price")
	before=s.snapshot(); check(not s.dispatch("tech",{"id":"spear"}) and s.snapshot()==before,"No repeat spend")
	check(s.dispatch("tech",{"id":"vitality"}) and s.dispatch("tech",{"id":"tactics"}),"Tier two grants generic modifiers")
	var saved: Dictionary=s.snapshot(); var restored=Session.new(catalog)
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))),"Same-version profile restores")
	var damaged: Dictionary=saved.duplicate(true); damaged.profile.tech=["spear"]
	check(not restored.restore(damaged),"Reject bypassed tier requirement in save")
	damaged=saved.duplicate(true); damaged.profile.tech=["knowledge","knowledge","spear"]
	check(not restored.restore(damaged),"Duplicate nodes cannot inflate gate")
	damaged=saved.duplicate(true); damaged.content_version="godot-flow-v02-21"
	check(not restored.restore(damaged),"Old version explicitly rejected")
	check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"New run applies nodes")
	var plain=Session.new(catalog); plain.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	check(s.state.player.hp_max==plain.state.player.hp_max+2,"Vitality HP cap")
	check(s.state.player.battle_ap==plain.state.player.battle_ap+1,"Tactics battle AP")
	check(s.state.player.sanity_max==plain.state.player.sanity_max+10,"Endurance sanity cap")
	before=s.snapshot(); check(not s.dispatch("tech",{"id":"craft"}) and s.snapshot()==before,"Active run cannot light nodes")
	var run_save: Dictionary=s.snapshot(); check(restored.restore(JSON.parse_string(JSON.stringify(run_save))),"Same-version active run restores")
	print("tech_tiers: %d failures" % failures); quit(1 if failures else 0)
