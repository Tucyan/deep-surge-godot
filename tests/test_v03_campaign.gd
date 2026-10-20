extends SceneTree
var failures := 0
const Session = preload("res://core/game_session.gd")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"catalogue")
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"fool","seed":22}),"start challenge")
	check(s.state.length==25,"challenge has25 voyages from configuration")
	check(s.state.get("journey",{}).get("layer_voyage",0)==1,"layer progress initialized")
	var saved: Dictionary=s.snapshot()
	var restored=Session.new(catalog)
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))),"new journey roundtrip")
	check(JSON.parse_string(JSON.stringify(restored.snapshot()))==JSON.parse_string(JSON.stringify(saved)),"roundtrip preserves all JSON state and random")
	var bad: Dictionary=saved.duplicate(true)
	bad.state["journey"]={"profile_id":"challenge","layer_index":1,"layer_voyage":1,"cleared":[]}
	check(not restored.restore(bad),"mismatched global and layer positions reject")
	var story=Session.new(catalog)
	check(story.dispatch("new",{"mode":"story","origin":"fool","seed":22}) and story.state.length==11,"story keeps11 voyages")
	print("V03 CAMPAIGN: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
