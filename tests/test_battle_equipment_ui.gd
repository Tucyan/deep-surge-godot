extends SceneTree

var failures := 0
var app: Control
const Session = preload("res://core/game_session.gd")
const Main = preload("res://flow_app.gd")
const Models = preload("res://presentation/raft_state_models.gd")

class MissingAssets:
	func model(_id: String) -> PackedScene:
		return null
class WorldStub:
	var _assets = MissingAssets.new()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: "+message)

func find_named(node: Node, id: String) -> Control:
	if node.name == id and node is Control:
		return node
	for child in node.get_children():
		var found := find_named(child,id)
		if found != null: return found
	return null

func press_battle_card(uid: String) -> bool:
	for fan in app.get_tree().get_nodes_in_group("hand_fans"):
		if fan.get_meta("presentation_role","")!="battle": continue
		for index in range(fan.cards.size()):
			if str(fan.cards[index].uid)==uid:
				(fan.buttons[index] as Button).pressed.emit()
				return true
	return false

func _init() -> void:
	call_deferred("run")
	call_deferred("watchdog")

func watchdog() -> void:
	await create_timer(15.0).timeout
	printerr("BATTLE EQUIPMENT UI: timed out")
	quit(2)

func run() -> void:
	var fallback = Models.new().module(WorldStub.new(),"generator")
	check(fallback.get_meta("temporary_placeholder",false),"missing equipment model uses an explicitly temporary fallback")
	var fallback_label:=fallback.find_child("TemporaryModelLabel",true,false) as Label3D
	check(fallback_label!=null and fallback_label.text.contains("临时模型"),"missing model fallback explains it is temporary")
	fallback.free()
	root.size = Vector2i(1280,720)
	app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await process_frame
	var s = app.session
	for id in ["shieldRack","generator","fishingNet","crate"]:
		check(app.assets.model("model.raft.module."+id)!=null,"stable new equipment model ID resolves without overwriting its registered path: "+id)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":37})
	s.state.hand=[]
	s.state.node=app.catalog.entry("nodes","battle"); s.state.node.visit_id="ui-equipment"
	s.state.phase="battle"; s.panel="battle"
	s.state.battle={"id":"biter","hp":30,"turn":1,"ap":3,"entry_hp":40,"poison_until":0,"fear_until":0,"shields":[],"raft_target_cell":"cell-0","intent":{"type":"biter_bite","target_cell":"cell-0","cell_damage":1}}
	s.give("wood"); var wood_uid: String=s.state.hand[-1].uid
	s.give("arrow"); var arrow_uid: String=s.state.hand[-1].uid
	s.state.cells[0].equipment={"id":"generator","level":1,"fuel":2,"progress":0,"boost_cards":[{"uid":"boost-ui","id":"barrier"}],"production_bonus":0}
	s.state.next_boost_id=1
	app.render()
	await process_frame
	check(find_named(app,"BattleAttack") != null and find_named(app,"BattleBlock") != null,"battle exposes fixed attack and block actions")
	check(find_named(app,"BattleShieldSummary") != null,"battle exposes shield amounts and expiry labels")
	check(find_named(app,"BattleIntentTarget") != null,"battle exposes biter's announced raft target")
	var before: Dictionary=s.snapshot()
	var select_resource := find_named(app,"BattleFanResource_"+wood_uid)
	check(select_resource != null,"resource hand card can be selected for a combo")
	if select_resource != null: (select_resource as Button).pressed.emit()
	await process_frame
	check(s.snapshot()==before,"selecting a resource is local and leaves the active snapshot unchanged")
	var attack := find_named(app,"BattleAttack")
	if attack != null: (attack as Button).pressed.emit()
	await process_frame
	var attack_preview: Dictionary=JSON.parse_string(str(app.ui_state.battle_selection))
	check(attack_preview.get("action","")=="attack" and attack_preview.get("preview",{}).get("valid",false),"resource combo attack preview records the selected attack action")
	var block := find_named(app,"BattleBlock")
	if block != null: (block as Button).pressed.emit()
	await process_frame
	var block_preview: Dictionary=JSON.parse_string(str(app.ui_state.battle_selection))
	check(block_preview.get("action","")=="block" and block_preview.get("preview",{}).get("valid",false),"switching the same combo to block replaces the stale attack preview")
	check(s.snapshot()==before,"previewing a selected combo leaves the active snapshot unchanged")
	var cancel := find_named(app,"CancelBattleSelection")
	check(cancel != null,"combo preview has an explicit cancel control")
	if cancel != null: (cancel as Button).pressed.emit()
	await process_frame
	check(s.snapshot()==before,"cancel does not dispatch or spend the selected resource")
	# Re-select and confirm; the exact resource UID is consumed once.
	select_resource=find_named(app,"BattleFanResource_"+wood_uid)
	if select_resource != null: (select_resource as Button).pressed.emit()
	await process_frame
	block=find_named(app,"BattleBlock")
	if block != null: (block as Button).pressed.emit()
	await process_frame
	var confirm := find_named(app,"ConfirmBattleAction")
	check(confirm != null,"valid combo preview can be confirmed")
	if confirm != null: (confirm as Button).pressed.emit()
	await process_frame
	check(s.state.battle.ap==2 and s.state.hand.all(func(c):return c.uid!=wood_uid),"confirm spends one AP and only the selected resource UID")
	check(s.state.battle.shields.size()>=1,"confirmed block applies real shield effects")
	# A card preview must not survive changing the selection into a resource/action combo.
	s.give("wood"); var combo_wood_uid: String=s.state.hand[-1].uid
	var boost_before: Dictionary=s.snapshot()
	var boost_select:=find_named(app,"BattleBoostSelect") as OptionButton
	check(boost_select!=null and boost_select.item_count>0,"battle offers an independent generator boost selector")
	if boost_select!=null:
		boost_select.select(0); boost_select.item_selected.emit(0)
	await process_frame
	check(s.snapshot()==boost_before,"selecting a boost does not mutate the active snapshot")
	check(press_battle_card(arrow_uid),"arrow hand control opens a boost preview")
	await process_frame
	var stale_preview: Dictionary=JSON.parse_string(str(app.ui_state.battle_selection))
	check(not stale_preview.get("preview",{}).get("valid",false) and stale_preview.has("play_args"),"incompatible barrier plus arrow creates an invalid card preview without dispatch")
	check(s.snapshot()==boost_before,"card preview does not mutate the active snapshot")
	cancel=find_named(app,"CancelBattleSelection")
	if cancel!=null: (cancel as Button).pressed.emit()
	await process_frame
	check(s.snapshot()==boost_before,"cancel leaves arrow, boost and resources unchanged")
	boost_select=find_named(app,"BattleBoostSelect") as OptionButton
	if boost_select!=null:
		boost_select.select(0); boost_select.item_selected.emit(0)
	await process_frame
	check(press_battle_card(arrow_uid),"card can be previewed again before switching combo selection")
	await process_frame
	select_resource=find_named(app,"BattleFanResource_"+combo_wood_uid)
	check(select_resource!=null,"second wood resource is available for the switched combo")
	if select_resource!=null: (select_resource as Button).pressed.emit()
	await process_frame
	block=find_named(app,"BattleBlock")
	if block!=null: (block as Button).pressed.emit()
	await process_frame
	confirm=find_named(app,"ConfirmBattleAction")
	var switched_selection: Dictionary=JSON.parse_string(str(app.ui_state.battle_selection))
	check(switched_selection.get("preview",{}).get("valid",false) and not switched_selection.has("play_args") and not switched_selection.has("card_uid"),"resource selection replaces the stale card command before the new preview")
	if confirm!=null: (confirm as Button).pressed.emit()
	await process_frame
	check(not s.state.hand.any(func(c):return c.uid==combo_wood_uid) and s.state.hand.any(func(c):return c.uid==arrow_uid),"confirm executes the new wood combo and leaves the previously previewed arrow in hand")
	check(not s.state.cells[0].equipment.boost_cards.any(func(c):return c.uid=="boost-ui") and s.state.battle.shields.any(func(c):return c.get("source","")=="barrier"),"confirm consumes the selected barrier UID and applies its shield layer")
	# Verify the raft detail controls use the current generator and equipment view.
	s.state.phase="preparation"; s.panel="raft"; s.state.ap=3
	s.state.cells[0].equipment={"id":"generator","level":1,"fuel":2,"progress":1,"boost_cards":[{"uid":"ready-fixture","id":"ready"},{"uid":"temporary-fixture","id":"production","expires_voyage":2}],"production_bonus":0}
	s.state.cells[1].equipment={"id":"filter","level":1,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
	s.state.cells[2].equipment={"id":"crate","level":2,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
	s.give("corpse")
	app.handle_ui("local_panel","raft"); app.handle_ui("selected_id","cell-0")
	await process_frame
	var capacity_label:=find_named(app,"GeneratorCapacity") as Label
	check(capacity_label!=null and capacity_label.text.contains("长期槽 1/1") and capacity_label.text.contains("待领取 1") and capacity_label.text.contains("临时 1"),"generator detail shows permanent capacity, ready count and overflow")
	check(find_named(app,"GeneratorProgress")!=null and find_named(app,"GeneratorFuel")!=null,"generator detail shows production progress and fuel")
	var fuel_before: int=s.state.cells[0].equipment.fuel
	var fuel_button:=find_named(app,"GeneratorFuelButton")
	if fuel_button!=null: (fuel_button as Button).pressed.emit()
	await process_frame
	check(s.state.cells[0].equipment.fuel==fuel_before+3,"generator fuel control dispatches one corpse as three fuel")
	var claim:=find_named(app,"ClaimBoost_ready-fixture_barrier")
	check(claim!=null,"ready generator boost offers power/barrier/production choices")
	if claim!=null: (claim as Button).pressed.emit()
	await process_frame
	check(s.state.cells[0].equipment.boost_cards.any(func(c):return c.uid=="ready-fixture" and c.id=="barrier"),"boost claim applies the selected option")
	var production_uid: String="temporary-fixture"
	var target_select:=find_named(app,"ProductionTargetSelect_"+production_uid) as OptionButton
	check(target_select!=null,"production boost exposes an explicit eligible target selector")
	var apply_production:=find_named(app,"ApplyProductionBoost_"+production_uid)
	if apply_production!=null: (apply_production as Button).pressed.emit()
	await process_frame
	check(int(s.state.cells[1].equipment.production_bonus)==1 and not s.state.cells[0].equipment.boost_cards.any(func(c):return c.uid==production_uid),"production target confirmation consumes the boost on the chosen filter")
	var craft_before: Dictionary=app.session.view()
	app.handle_ui("local_panel","craft"); app.handle_ui("list_page","1")
	await process_frame
	var recipe_ids: Array=[]
	for tile in find_recipe_tiles(app): recipe_ids.append(str(tile.get_meta("recipe_id","")))
	check("fishingNet" in recipe_ids or "crate" in recipe_ids,"craft page two exposes at least one new equipment recipe")
	var limit_label:=find_named(app,"CraftInventory")
	app.handle_ui("local_panel","raft"); app.handle_ui("selected_id","cell-2")
	await process_frame
	check(find_label_containing(app,"有效手牌上限 %d" % int(craft_before.player.limit))!=null,"raft details show effective hand capacity, including installed crate")
	# Dense-hand bounds at both supported desktop sizes; selections stay non-rules state.
	s.state.phase="battle"; s.panel="battle"; s.state.battle.ap=2
	s.state.hand=[]
	for i in range(4):
		for id in ["wood","iron","rope","plastic","cloth"]: s.give(id)
	s.state.cells[0].equipment.boost_cards=[]
	for i in range(8): s.state.cells[0].equipment.boost_cards.append({"uid":"boost-dense-%d" % i,"id":"power" if i%2==0 else "barrier"})
	s.state.battle.shields=[]
	for i in range(12): s.state.battle.shields.append({"uid":"shield-dense-%d" % i,"source":"action","amount":1,"expires_turn":1 if i%2==0 else 2,"extendable":false,"extended":false})
	app.local_panel=""; app.ui_state.selected_id=""; root.size=Vector2i(1280,720); app.render(); await process_frame
	check_page_bounds(Vector2i(1280,720),"dense battle 1280×720")
	root.size=Vector2i(1600,900); app.render(); await process_frame
	check_page_bounds(Vector2i(1600,900),"dense battle 1600×900")
	app.queue_free(); await process_frame
	print("BATTLE EQUIPMENT UI: %s" % ("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)

func find_recipe_tiles(node: Node) -> Array:
	var result: Array=[]
	if node is Control and node.has_meta("recipe_id"): result.append(node)
	for child in node.get_children(): result.append_array(find_recipe_tiles(child))
	return result

func find_label_containing(node: Node,value: String) -> Label:
	if node is Label and node.text==value: return node
	for child in node.get_children():
		var found:=find_label_containing(child,value)
		if found!=null: return found
	return null

func check_page_bounds(viewport_size: Vector2i,context_name: String) -> void:
	var modal:=find_named(app,"ModalSurface")
	var scale:=Vector2(viewport_size)/app.size
	var viewport_rect:=Rect2(Vector2.ZERO,Vector2(viewport_size))
	check(modal!=null and viewport_rect.encloses(scale_rect(modal.get_global_rect(),scale)),context_name+" modal fits viewport")
	for button in collect_buttons(modal) if modal!=null else []:
		if button.is_visible_in_tree() and button.get_global_rect().size.x>0:
			var ok:=viewport_rect.encloses(scale_rect(button.get_global_rect(),scale))
			check(ok,context_name+" button inside viewport: "+button.name)

func scale_rect(rect: Rect2,scale: Vector2) -> Rect2:
	return Rect2(rect.position*scale,rect.size*scale)

func collect_buttons(node: Node) -> Array:
	var result: Array=[]
	if node is Button: result.append(node)
	for child in node.get_children(): result.append_array(collect_buttons(child))
	return result
