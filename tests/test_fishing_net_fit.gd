extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func bounds(node: Node, parent_transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var transform := parent_transform
	if node is Node3D: transform *= node.transform
	var result := AABB()
	if node is MeshInstance3D: result = transform * node.mesh.get_aabb()
	for child in node.get_children():
		var child_bounds := bounds(child, transform)
		if child_bounds.size != Vector3.ZERO:
			result = child_bounds if result.size == Vector3.ZERO else result.merge(child_bounds)
	return result
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr("FAIL: " + message)
func run():
	var assets = load("res://presentation/asset_catalog.gd").new()
	var model: Node3D = assets.model("model.raft.module.fishingNet").instantiate()
	var actual := bounds(model)
	var document := GLTFDocument.new(); var state := GLTFState.new()
	check(document.append_from_file("res://assets/models/raft-modules/fishingNet.glb", state) == OK, "parse source GLB")
	var source := document.generate_scene(state)
	var expected := bounds(source)
	print("CACHED ", actual, " SOURCE ", expected)
	check(actual.position.is_equal_approx(expected.position) and actual.size.is_equal_approx(expected.size), "Godot imported model matches current source GLB")
	check(actual.position.x >= -1.175 and actual.end.x <= 1.175 and actual.position.z >= -1.05 and actual.end.z <= 1.05, "runtime fishing net stays inside its own raft cell")
	source.free()
	if "--visual" in OS.get_cmdline_user_args():
		root.size = Vector2i(1000,800)
		var stage := Node3D.new(); root.add_child(stage)
		stage.add_child(assets.model("model.raft.module.deck-intact").instantiate())
		stage.add_child(model)
		var environment := WorldEnvironment.new(); var env := Environment.new()
		env.background_mode = Environment.BG_COLOR; env.background_color = Color("203348")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color.WHITE; env.ambient_light_energy = .65
		environment.environment = env; stage.add_child(environment)
		var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55,-30,0); stage.add_child(light)
		var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 3.5; stage.add_child(camera)
		for view in [["top",Vector3(0,5,.001)],["oblique",Vector3(3,3,4)]]:
			camera.position = view[1]; camera.look_at(Vector3(0,.35,0))
			for i in range(5): await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://evidence/fishing-net-runtime-"+view[0]+".png") == OK,"capture runtime " + view[0])
	else: model.free()
	print("FISHING NET RUNTIME FIT: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
