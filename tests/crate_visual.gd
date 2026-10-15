extends SceneTree
var stage: Node3D
var camera: Camera3D
var failures := 0
var stylized := false
var user_wood_v2 := false
var raft_wood := false
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr("FAIL: "+message)
func capture(id: String):
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var prefix := "crate-raft-wood-" if raft_wood else "crate-user-wood-v2-" if user_wood_v2 else "crate-v2-" if stylized else "crate-v1-"
	check(root.get_texture().get_image().save_png("res://evidence/"+prefix+id+".png") == OK,"capture "+id)
func run():
	var blockout := "--blockout" in OS.get_cmdline_user_args()
	stylized = "--stylized" in OS.get_cmdline_user_args()
	user_wood_v2 = "--user-wood-v2" in OS.get_cmdline_user_args()
	raft_wood = "--raft-wood" in OS.get_cmdline_user_args() or (not stylized and not user_wood_v2)
	var path := "res://asset-sources/wooden-crate-v1/crate_blockout.glb" if blockout else "res://assets/models/props/wooden-crate.glb"
	check(FileAccess.file_exists(path),"crate export exists")
	if failures > 0: quit(failures); return
	root.size = Vector2i(1100,800)
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new(); root.add_child(stage)
	var environment := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("303c43"); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("ccd8dd"); env.ambient_light_energy = .50
	environment.environment = env; stage.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-48,-35,0); light.light_energy = 1.3; light.shadow_enabled = true; stage.add_child(light)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-25,130,0); fill.light_energy = .35; stage.add_child(fill)
	var packed: PackedScene
	var model: Node3D
	if blockout:
		var document := GLTFDocument.new(); var state := GLTFState.new()
		check(document.append_from_file(path,state) == OK,"parse blockout glTF")
		model = document.generate_scene(state)
	else:
		var assets = load("res://presentation/asset_catalog.gd").new()
		packed = assets.model("model.prop.wooden-crate")
		check(packed == assets.model("model.prop.wooden-crate"),"stable AssetId returns cached scene")
		check(packed != null,"standard Godot import resolves PackedScene")
		if packed == null: quit(1); return
		model = packed.instantiate()
	stage.add_child(model)
	check(model.find_child("CrateBody",true,false) != null and model.find_child("CrateLid",true,false) != null,"separate body and lid in Godot")
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 1.75; stage.add_child(camera)
	for item in [["front",Vector3(3,2.4,4)],["back",Vector3(-3,2.4,-4)],["top",Vector3(.01,5,.01)],["bottom",Vector3(2,-3,3)]]:
		camera.position = item[1]; camera.look_at(Vector3(0,.39,0),Vector3.UP)
		await capture(("blockout-" if blockout else "")+item[0])
	stage.queue_free(); await process_frame
	if not blockout:
		root.size = Vector2i(1600,900)
		var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
		app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
		var saved = app.session.snapshot()
		var crate: Node3D = packed.instantiate()
		app.world_view.cells.get_node("cell-2").add_child(crate); crate.position.y = .17
		app.world_view.motion = false; app.world_view._time = 3; app.world_view._process(0)
		await capture("raft-fixture-1600")
		root.size = Vector2i(1280,720); await capture("raft-fixture-1280")
		check(app.session.snapshot() == saved,"crate is only a visual fixture, no invented equipment/storage")
		app.queue_free(); await process_frame
	print("CRATE GLTF GPU: PASS" if failures == 0 else "CRATE GLTF GPU: FAIL"); quit(failures)
