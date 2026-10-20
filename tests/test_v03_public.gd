extends SceneTree
var failures:=0
func check(ok: bool,why: String) -> void:
	if not ok:failures+=1;printerr("FAIL: "+why)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new();check(catalog.load_catalog(),"catalog")
	var s=load("res://core/game_session.gd").new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"fool","seed":22}),"start")
	var chest: Dictionary=catalog.entry("nodes","sealedChest");chest.visit_id="public-chest"
	s.state.candidates=[chest];s.EnvironmentRules.prepare_navigation(s)
	var before: Dictionary=s.snapshot();var view: Dictionary=s.view()
	check(not view.candidates[0].options[0].has("outcomes"),"common navigation projection hides random branches")
	check(s.snapshot()==before,"projection leaves definitions and RNG untouched")
	s.state.node=chest;s.state.candidates=[];s.state.phase="story";s.state.story_step="choice";s.Encounter.arrived(s)
	view=s.view()
	check(not view.node.options[0].has("outcomes"),"common current node hides random branches")
	check(not view.event_options[0].has("outcomes") and not view.event_options[0].has("battle"),"common offered option hides internal battle request")
	check(s.state.node.options[0].has("outcomes"),"private rule definition remains executable")
	print("V03 PUBLIC: %s" % ("PASS" if failures==0 else "FAIL"));quit(failures)
