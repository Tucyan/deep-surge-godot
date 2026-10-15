extends SceneTree
var failures:=0
func check(ok: bool,why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	var session=load("res://core/game_session.gd").new(catalog)
	session.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	var cell: Dictionary=session.state.cells[1]
	cell.equipment={"id":"lamp","level":1,"fuel":0,"progress":0}
	session.give("wood",2,false,"fuel-fixture"); session.give("corpse",1,true,"temporary-fixture")
	var wood: Array=session.state.hand.filter(func(c):return c.id=="wood")
	var uid: String=wood[-1].uid
	check(session.dispatch("fuel",{"cell":cell.id,"material":"wood","uid":uid}),"Fuel accepts an explicitly chosen UID")
	check(session.I.find(session.state,uid).is_empty() and not session.I.find(session.state,wood[0].uid).is_empty(),"Consumes chosen instance rather than first material")
	for args in [{"cell":cell.id,"material":"wood","uid":uid},{"cell":cell.id,"material":"corpse","uid":wood[0].uid},{"cell":cell.id,"material":"corpse","uid":session.state.hand[-1].uid}]:
		var before: Dictionary=session.snapshot()
		check(not session.dispatch("fuel",args),"Duplicate, mismatched and temporary fuel are rejected")
		check(session.snapshot()==before,"Rejected fuel leaves state and RNG unchanged")
	check(session.dispatch("fuel",{"cell":cell.id,"material":"wood"}),"Existing fuel command without UID stays supported")
	print("FUEL UID: "+("PASS" if failures==0 else "FAIL")); quit(failures)
