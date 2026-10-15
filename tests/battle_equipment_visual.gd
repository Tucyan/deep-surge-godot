extends SceneTree

var failures:=0
var app: Control
const Models=preload("res://presentation/raft_state_models.gd")

class MissingAssets:
	func model(_id: String) -> PackedScene:
		return null
class WorldStub:
	var _assets=MissingAssets.new()

func _init() -> void:
	call_deferred("run")
	call_deferred("watchdog")

func watchdog() -> void:
	await create_timer(30.0).timeout
	printerr("BATTLE EQUIPMENT VISUAL: timeout after 30 seconds")
	quit(2)

func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)

func find_named(node: Node,id: String) -> Control:
	if node is Control and node.name==id: return node
	for child in node.get_children():
		var found:=find_named(child,id)
		if found!=null: return found
	return null

func within(control: Control,viewport_size: Vector2i) -> bool:
	var scale:=Vector2(viewport_size)/app.size
	var logical:=control.get_global_rect()
	var rect:=Rect2(logical.position*scale,logical.size*scale)
	var viewport:=Rect2(Vector2.ZERO,Vector2(viewport_size))
	return viewport.encloses(rect)

func capture(path: String) -> void:
	for i in range(4): await process_frame
	check(root.get_texture().get_image().save_png("res://evidence/"+path)==OK,"capture "+path)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("BATTLE EQUIPMENT VISUAL requires the GPU display server; do not run with --headless")
		quit(2); return
	var fallback=Models.new().module(WorldStub.new(),"generator")
	check(fallback.get_meta("temporary_placeholder",false),"missing new model uses a temporary 3D placeholder")
	var label:=fallback.find_child("TemporaryModelLabel",true,false) as Label3D
	check(label!=null and label.text.contains("临时模型"),"temporary model placeholder is plainly labelled")
	fallback.free()
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":37})
	var s=app.session
	s.state.hand=[]; s.state.node=app.catalog.entry("nodes","battle"); s.state.node.visit_id="battle-ui-visual"
	s.state.phase="battle"; s.panel="battle"
	s.state.battle={"id":"biter","hp":10,"turn":2,"ap":2,"entry_hp":40,"poison_until":0,"fear_until":0,"shields":[{"uid":"shield-visual-1","source":"shieldRack","amount":2,"expires_turn":2,"extendable":false,"extended":false},{"uid":"shield-visual-2","source":"barrier","amount":1,"expires_turn":3,"extendable":false,"extended":false}],"raft_target_cell":"cell-0","intent":{"type":"biter_bite","target_cell":"cell-0","cell_damage":1}}
	s.state.cells[0].equipment={"id":"generator","level":2,"fuel":4,"progress":1,"boost_cards":[{"uid":"ready-visual","id":"ready"},{"uid":"power-visual","id":"power","expires_voyage":2}],"production_bonus":0}
	s.state.cells[1].equipment={"id":"filter","level":1,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
	s.state.cells[2].equipment={"id":"crate","level":2,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
	s.state.cells[3].equipment={"id":"generator","level":2,"fuel":2,"progress":0,"boost_cards":[{"uid":"barrier-visual","id":"barrier"},{"uid":"production-visual","id":"production","expires_voyage":2}],"production_bonus":0}
	s.give("wood"); s.give("iron"); s.give("rope"); s.give("plastic"); s.give("cloth");
	var wood_uid: String="" if s.state.hand.is_empty() else str(s.state.hand[0].uid)
	var preview_args: Dictionary={"action":"block","resource_uid":wood_uid,"buff_uid":"barrier-visual"}
	app.ui_state.battle_selection=JSON.stringify({"resource_uid":wood_uid,"buff_uid":"barrier-visual","action":"block","preview":s.Battle.preview(s,preview_args)})
	var original: Dictionary=s.snapshot()
	app.render(); await process_frame
	for id in ["shieldRack","generator","fishingNet","crate"]:
		check(app.assets.model("model.raft.module."+id)!=null,"stable model AssetId resolves: "+id)
	var modal:=find_named(app,"ModalSurface")
	check(modal!=null and within(modal,Vector2i(1280,720)),"battle modal stays within 1280×720")
	for id in ["BattleAttack","BattleBlock","ConfirmBattleAction"]:
		var button:=find_named(app,id)
		if button!=null: check(within(button,Vector2i(1280,720)),id+" stays inside 1280×720")
	check(s.snapshot()==original,"battle visuals do not dispatch or mutate rules")
	await capture("battle-equipment-1280.png")
	root.size=Vector2i(1600,900); await process_frame
	app.render(); await process_frame
	modal=find_named(app,"ModalSurface")
	check(modal!=null and within(modal,Vector2i(1600,900)),"battle modal stays within 1600×900")
	await capture("battle-equipment-1600.png")
	s.state.phase="preparation"; s.panel="raft"; app.ui_state.selected_id="cell-0"; app.ui_state.battle_selection=""; app.render(); await process_frame
	modal=find_named(app,"ModalSurface")
	check(modal!=null and within(modal,Vector2i(1600,900)),"generator modal stays within 1600×900")
	var capacity:=find_named(app,"GeneratorCapacity")
	check(capacity!=null and capacity.text.contains("临时 1") ,"generator example shows permanent and temporary slots")
	check(find_named(app,"ProductionTargetSelect_production-visual")!=null,"generator example includes production target selection")
	var raft_snapshot: Dictionary=s.snapshot()
	await capture("battle-equipment-generator.png")
	root.size=Vector2i(1280,720); app.render(); await process_frame
	check(s.snapshot()==raft_snapshot,"opening generator detail does not mutate rules")
	app.queue_free(); await process_frame
	print("BATTLE EQUIPMENT VISUAL: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
