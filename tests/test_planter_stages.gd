extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr("FAIL: "+message)
func run():
	var models = load("res://presentation/raft_state_models.gd").new()
	check(models.has_method("planter_stage"),"planter visual stage selector exists")
	if failures > 0: quit(failures); return
	check(models.planter_stage({"progress":0,"level":1}) == "seedling","level one non-producing voyage is seedling")
	check(models.planter_stage({"progress":1,"level":1}) == "mature","level one production voyage is mature")
	for level in [2,3]: check(models.planter_stage({"progress":0,"level":level}) == "mature","higher levels produce each voyage, always mature")
	var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.session.I.give(app.session.state,"planter",1,false,"planter-stage-test")
	app.handle_command("install",{"uid":app.session.state.hand.back().uid,"cell":"cell-2"}); await process_frame
	var model = app.world_view.cells.get_node("cell-2/Equipment")
	check(model.get_meta("growth_stage","") == "seedling","real install loads seedling")
	var fixture = app.session.view().duplicate(true); var saved = app.session.snapshot()
	fixture.cells[2].equipment.progress = 1
	app.world_view.sync(fixture); await process_frame
	model = app.world_view.cells.get_node("cell-2/Equipment")
	check(model.get_meta("growth_stage","") == "mature","production voyage replaces plant mesh")
	check(app.world_view.cells.get_node("cell-2/StateLabel").text.contains("成长完"),"mature label")
	fixture.cells[2].status = "damaged"; app.world_view.sync(fixture); await process_frame
	model = app.world_view.cells.get_node("cell-2/Equipment")
	check(model.get_meta("growth_stage","") == "mature" and not model.get_meta("active",true),"damage retains plant shape and disables equipment")
	fixture.cells[2].status = "intact"; fixture.cells[2].equipment.progress = 0
	app.world_view.sync(fixture); await process_frame
	model = app.world_view.cells.get_node("cell-2/Equipment")
	check(model.get_meta("growth_stage","") == "seedling","harvest reset restores seedling")
	check(app.world_view.cells.get_node("cell-2/StateLabel").text.contains("小苗"),"seedling label")
	for level in [2,3]:
		fixture.cells[2].equipment.level = level
		app.world_view.sync(fixture); await process_frame
		check(app.world_view.cells.get_node("cell-2/Equipment").get_meta("growth_stage","") == "mature","level 2/3 progress zero uses mature mesh")
	check(app.session.snapshot() == saved,"visual stage changes do not mutate rules/RNG")
	# Actual production commands verify the visual forecast matches the existing cycle.
	var s = load("res://core/game_session.gd").new(app.session.catalog)
	check(s.restore(saved),"restore production fixture")
	var food: int = s.I.count(s.state,"food")
	s.state.phase = "aftermath"
	check(s.dispatch("end_voyage"),"first real voyage settlement")
	check(s.state.cells[2].equipment.progress == 1 and s.I.count(s.state,"food") == food,"first level-one settlement grows without producing")
	check(models.planter_stage(s.state.cells[2].equipment) == "mature","next voyage is due to produce, shows mature")
	s.state.phase = "aftermath"
	check(s.dispatch("end_voyage"),"second real voyage settlement")
	check(s.state.cells[2].equipment.progress == 0 and s.I.count(s.state,"food") == food+1,"level-one production and reset unchanged")
	check(models.planter_stage(s.state.cells[2].equipment) == "seedling","following non-producing voyage shows seedling")
	for level in [2,3]:
		s.state.cells[2].equipment.level = level; s.state.phase = "aftermath"
		check(s.dispatch("end_voyage"),"higher level settlement")
		check(s.state.cells[2].equipment.progress == 0 and models.planter_stage(s.state.cells[2].equipment) == "mature","higher level always shows mature after production reset")
	app.queue_free(); await process_frame
	print("PLANTER STAGES: PASS" if failures == 0 else "PLANTER STAGES: FAIL"); quit(failures)
