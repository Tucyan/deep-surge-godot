extends SceneTree
var failures := 0
const Session=preload("res://core/game_session.gd")
func check(ok: bool,why: String) -> void:
	if not ok:failures+=1;printerr("FAIL: "+why)
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new();check(catalog.load_catalog(),"catalog")
	catalog._tables.balance.economy.repair_wood=2
	catalog._tables.balance.economy.repair_ap=2
	catalog._tables.balance.economy.discount_wood=2
	catalog._tables.balance.economy.expansion_ap=2
	var s=Session.new(catalog);check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"new")
	s._auto_advancing=true;s.state.hand=[];s.give("wood",4)
	s.state.cells[0].status="damaged";s.state.cells[0].damaged_at=1
	check(s.dispatch("repair_cell",{"cell":s.state.cells[0].id,"material":"wood"}),"repair")
	check(s.state.ap==1 and s.I.count(s.state,"wood")==2,"repair obeys shared materials and AP config")
	check(s.view().expansion_cost.wood==2,"expansion quote obeys shared discount config")
	var malformed: Dictionary=catalog._tables.duplicate(true)
	malformed.balance.growth.erase("xp_per_level")
	check(not s.Survival.valid_content(malformed),"missing growth key rejects catalogue")
	print("V03 BALANCE: %s" % ("PASS" if failures==0 else "FAIL"));quit(failures)
