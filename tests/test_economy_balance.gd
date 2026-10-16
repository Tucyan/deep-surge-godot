extends SceneTree
var failures:=0
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void:
	var Score=load("res://core/settlement.gd")
	var input={"completed":15,"length":15,"goal":true,"hp":10.0/12.0,"sanity":1.0,"cells":0.5,"events_entered":5,"events_won":3,"battles_entered":1,"battles_won":1,"tags":4}
	var before: Dictionary=Score.score(input)
	var after: Dictionary=Score.score(JSON.parse_string(JSON.stringify(input)))
	check(before.total==after.total and before.components==after.components,"生命10/12的评分经JSON恢复不跨越半分舍入边界")
	var c=load("res://content/catalog.gd").new(); check(c.load_catalog(),"catalog")
	var Session=load("res://core/game_session.gd")
	var s=Session.new(c); check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"new")
	var old: Dictionary=s.snapshot(); old.content_version="godot-flow-v02-10"
	var current: Dictionary=s.snapshot()
	check(not s.restore(old) and s.snapshot()==current,"拒绝v10旧内容且不覆盖当前状态")
	s.give("lamp"); check(s.dispatch("install",{"cell":"cell-0","uid":s.state.hand[-1].uid}),"install lamp")
	s.give("wood");check(s.dispatch("fuel",{"cell":"cell-0","material":"wood","uid":s.state.hand[-1].uid}),"wood fuel")
	for tick in range(3):
		s.state.phase="navigation";s.state.player.sanity=80;s.Rules.candidates(s)
		check(s.dispatch("voyage",{"id":s.state.candidates[0].visit_id}),"actual move")
		check(s.state.player.sanity==(80 if tick<2 else 65),"木头前两次移动抵消航耗，第三次耗尽")
	var run=Session.new(c);run.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	run.state.voyage=7
	for node in run.Encounter.definitions(run):
		if not node.has("monster"):run.state.flags.event_visits[run.Encounter.key(node)]=99
	run.Rules.candidates(run)
	check(run.state.candidates.all(func(n):return n.has("monster")),"免费事件耗尽后只抽合格战斗，不插免费回退保底")
	print("ECONOMY BALANCE: "+("PASS" if failures==0 else "FAIL"));quit(failures)
