extends SceneTree
var camera: Camera3D
var failures := 0
var user_wood_v2 := false
var raft_wood := false
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr("FAIL: "+message)
func capture(id: String):
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var prefix := "equipment-raft-wood-" if raft_wood else "equipment-user-wood-v2-" if user_wood_v2 else "equipment-v1-"
	check(root.get_texture().get_image().save_png("res://evidence/"+prefix+id+".png") == OK,"capture "+id)
func direct_model(key: String) -> Node3D:
	var path := "res://assets/models/props/wooden-crate.glb" if key == "crate" else "res://assets/models/raft-modules/"+key+".glb"
	var document := GLTFDocument.new(); var state := GLTFState.new()
	check(document.append_from_file(path,state) == OK,"parse "+key)
	return document.generate_scene(state)
func run():
	var args := OS.get_cmdline_user_args()
	user_wood_v2 = "--user-wood-v2" in args
	raft_wood = "--raft-wood" in args or not user_wood_v2
	var keys := ["shieldRack","generator","fishingNet","crate"]
	if "--asset" in args: keys = [args[args.find("--asset")+1]]
	root.size = Vector2i(1100,800); root.msaa_3d = Viewport.MSAA_4X
	for key in keys:
		var stage := Node3D.new(); root.add_child(stage)
		var environment := WorldEnvironment.new(); var env := Environment.new()
		env.background_mode = Environment.BG_COLOR; env.background_color = Color("303c43"); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("ccd8dd"); env.ambient_light_energy = .50
		environment.environment = env; stage.add_child(environment)
		var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-48,-35,0); light.light_energy = 1.3; light.shadow_enabled = true; stage.add_child(light)
		var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-25,130,0); fill.light_energy = .35; stage.add_child(fill)
		stage.add_child(direct_model(key))
		camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 2.15 if key == "fishingNet" else 1.75; stage.add_child(camera)
		var target := Vector3(0,.65,.45) if key == "fishingNet" else Vector3(0,.65,0)
		for item in [["front",Vector3(3,2.4,4)],["back",Vector3(-3,2.4,-4)],["top",Vector3(.01,5,.01)],["bottom",Vector3(2,-3,3)]]:
			camera.position = target+item[1]; camera.look_at(target,Vector3.UP); await capture(key+"-"+item[0])
		stage.queue_free(); await process_frame
	if "--fixture" in args:
		root.size = Vector2i(1600,900)
		var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
		app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
		var saved = app.session.snapshot()
		var assets = load("res://presentation/asset_catalog.gd").new()
		for i in range(4):
			var key: String = ["generator","shieldRack","crate","fishingNet"][i]
			var packed: PackedScene = assets.model("model.raft.module."+key)
			check(packed != null and packed == assets.model("model.raft.module."+key),"cached native Godot import "+key)
			if packed == null: quit(1); return
			var model = packed.instantiate(); var cell = app.world_view.cells.get_node("cell-"+str(i)); cell.add_child(model)
			for child in cell.get_children():
				if child is Label3D: child.visible = false
		for child in app.world_view.raft.get_children():
			if child.name == "DecorativeRoot":
				for label in child.get_children():
					if label is Label3D: label.visible = false
		app.world_view.motion = false; app.world_view._time = 3; app.world_view._process(0)
		await capture("raft-fixture-1600")
		root.size = Vector2i(1280,720); await capture("raft-fixture-1280")
		check(app.session.snapshot() == saved,"fixture does not alter rules, inventory, equipment or cards")
		app.queue_free(); await process_frame
	print("EQUIPMENT MODELS GPU: PASS" if failures == 0 else "EQUIPMENT MODELS GPU: FAIL"); quit(failures)
