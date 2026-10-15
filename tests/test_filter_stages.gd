extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr("FAIL: "+message)
func run():
	var models = load("res://presentation/raft_state_models.gd").new()
	check(models.has_method("filter_stage"),"filter visual stage selector exists")
	if failures > 0: quit(failures); return
	check(models.filter_stage({"progress":0,"level":1}) == "waiting","level one non-producing voyage is waiting")
	check(models.filter_stage({"progress":1,"level":1}) == "ready","level one production voyage is ready")
	for level in [2,3]: check(models.filter_stage({"progress":0,"level":level}) == "ready","higher levels produce each voyage, always ready")
	var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.session.I.give(app.session.state,"filter",1,false,"filter-stage-test")
	app.handle_command("install",{"uid":app.session.state.hand.back().uid,"cell":"cell-2"}); await process_frame
	var model = app.world_view.cells.get_node("cell-2/Equipment")
	check(model.get_meta("production_stage","") == "waiting","real install loads waiting")
	var fixture = app.session.view().duplicate(true); var saved = app.session.snapshot()
	fixture.cells[2].equipment.progress = 1
	app.world_view.sync(fixture); await process_frame
	model = app.world_view.cells.get_node("cell-2/Equipment")
	check(model.get_meta("production_stage","") == "ready","production voyage replaces plant mesh")
	check(app.world_view.cells.get_node("cell-2/StateLabel").text.contains("本轮产水"),"ready label")
	fixture.cells[2].status = "damaged"; app.world_view.sync(fixture); await process_frame
	model = app.world_view.cells.get_node("cell-2/Equipment")
	check(model.get_meta("production_stage","") == "ready" and not model.get_meta("active",true),"damage retains filter shape and disables equipment")
	check(app.world_view.cells.get_node("cell-2/StateLabel").text.contains("过滤暂停") and not app.world_view.cells.get_node("cell-2/StateLabel").text.contains("本轮产水"),"damaged filter does not promise production")
	fixture.cells[2].status = "intact"; fixture.cells[2].equipment.progress = 0
	app.world_view.sync(fixture); await process_frame
	model = app.world_view.cells.get_node("cell-2/Equipment")
	check(model.get_meta("production_stage","") == "waiting","production reset restores waiting")
	check(app.world_view.cells.get_node("cell-2/StateLabel").text.contains("过滤中"),"waiting label")
	for level in [2,3]:
		fixture.cells[2].equipment.level = level
		app.world_view.sync(fixture); await process_frame
		check(app.world_view.cells.get_node("cell-2/Equipment").get_meta("production_stage","") == "ready","level 2/3 progress zero uses ready mesh")
	check(app.session.snapshot() == saved,"visual stage changes do not mutate rules/RNG")
	# Actual production commands verify the visual forecast matches the existing cycle.
	var s = load("res://core/game_session.gd").new(app.session.catalog)
	check(s.restore(saved),"restore production fixture")
	var water: int = s.I.count(s.state,"water")
	s.state.phase = "aftermath"
	check(s.dispatch("end_voyage"),"first real voyage settlement")
	check(s.state.cells[2].equipment.progress == 1 and s.I.count(s.state,"water") == water,"first level-one settlement filters without producing")
	check(models.filter_stage(s.state.cells[2].equipment) == "ready","next voyage is due to produce, shows ready")
	s.state.phase = "aftermath"
	check(s.dispatch("end_voyage"),"second real voyage settlement")
	check(s.state.cells[2].equipment.progress == 0 and s.I.count(s.state,"water") == water+1,"level-one production and reset unchanged")
	check(models.filter_stage(s.state.cells[2].equipment) == "waiting","following non-producing voyage shows waiting")
	for level in [2,3]:
		s.state.cells[2].equipment.level = level; s.state.phase = "aftermath"
		check(s.dispatch("end_voyage"),"higher level settlement")
		check(s.state.cells[2].equipment.progress == 0 and models.filter_stage(s.state.cells[2].equipment) == "ready","higher level always shows ready after production reset")
	app.queue_free(); await process_frame
	print("FILTER STAGES: PASS" if failures == 0 else "FILTER STAGES: FAIL"); quit(failures)
