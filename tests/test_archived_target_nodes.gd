extends SceneTree
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"load catalog")
	var s=load("res://core/game_session.gd").new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"new")
	var definitions: Array=s.Encounter.definitions(s)
	check(not definitions.any(func(n):return n.id=="workshop"),"archived workshop excluded from pool")
	check(not definitions.any(func(n):return n.id=="storm" and n.get("variant_id","")=="surface"),"archived surface excluded from pool")
	check(definitions.any(func(n):return n.id=="storm" and n.get("variant_id","")=="hold"),"hold variant remains playable")
	s.state.voyage=5
	var workshop: Dictionary=catalog.entry("nodes","workshop")
	check(not s.Encounter.eligible(s,workshop),"workshop cannot be selected")
	var storm: Dictionary=catalog.entry("nodes","storm")
	for variant in storm.variants:
		if variant.id=="surface":
			storm.merge(variant,true); storm.id="storm"; storm.variant_id="surface"; break
	check(not s.Encounter.eligible(s,storm),"surface cannot be selected")
	for node in definitions:
		var options: Array=node.get("options",[]).duplicate(true)
		for stage in node.get("stages",[]): options.append_array(stage)
		check(not options.any(func(o):return o.get("conditions",{}).has("target")),"no target dropdown in pool: "+str(node.name))
	print("ARCHIVED TARGET NODES: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
	quit(failures)
