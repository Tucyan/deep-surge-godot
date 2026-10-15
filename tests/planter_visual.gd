extends SceneTree
var stage: Node3D
var camera: Camera3D
var failures := 0
var stylized := false
var user_wood_v2 := false
var raft_wood := false
func _init(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr("FAIL: "+message)
func capture(id: String):
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var prefix := "planter-raft-wood-" if raft_wood else "planter-user-wood-v2-" if user_wood_v2 else "planter-v4-" if stylized else "planter-v3-"
	check(root.get_texture().get_image().save_png("res://evidence/"+prefix+id+".png") == OK,"capture "+id)
func run():
	stylized = "--stylized" in OS.get_cmdline_user_args()
	user_wood_v2 = "--user-wood-v2" in OS.get_cmdline_user_args()
	raft_wood = "--raft-wood" in OS.get_cmdline_user_args() or (not stylized and not user_wood_v2)
	root.size = Vector2i(1100,800)
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new(); root.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("34434e"); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color.WHITE; env.ambient_light_energy = .65
	environment.environment = env; stage.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55,-35,0); light.light_energy = 1.8; stage.add_child(light)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 1.9; stage.add_child(camera)
	for variant in ["mature","seedling"]:
		var path := "res://assets/models/raft-modules/"+("planter.glb" if variant == "mature" else "planter-seedling.glb")
		var model: Node3D = load(path).instantiate(); stage.add_child(model)
		check(model.get_child_count() == 4,"four material batches; no extra cube")
		for item in [["front",Vector3(3,2.5,4)],["back",Vector3(-3,2.5,-4)],["top",Vector3(.01,5,.01)],["bottom",Vector3(2,-3,3)]]:
			camera.position = item[1]; camera.look_at(Vector3(0,.65,-.13),Vector3.UP)
			await capture(variant+"-"+item[0])
		model.queue_free(); await process_frame
	stage.queue_free(); await process_frame
	root.size = Vector2i(1600,900)
	var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.session.I.give(app.session.state,"planter",1,false,"planter-visual-fixture")
	var uid: String = app.session.state.hand.back().uid
	app.handle_command("install",{"uid":uid,"cell":"cell-2"}); await process_frame
	check(app.world_view.cells.get_node("cell-2").has_node("Equipment"),"actual install command creates planter")
	check(app.session.state.cells[2].equipment.id == "planter","actual state planter ID")
	app.world_view.motion = false; app.world_view._time = 3; app.world_view._process(0)
	await capture("seedling-raft-1600")
	root.size = Vector2i(1280,720); await capture("seedling-raft-1280")
	var fixture = app.session.view().duplicate(true); fixture.cells[2].equipment.progress = 1
	app.world_view.sync(fixture); app.world_view._process(0)
	await capture("mature-raft-1280")
	root.size = Vector2i(1600,900); await capture("mature-raft-1600")
	app.queue_free(); await process_frame
	print("PLANTER GPU AND INSTALL: PASS" if failures == 0 else "PLANTER GPU AND INSTALL: FAIL")
	quit(failures)
