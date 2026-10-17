extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1200,900)
	var stage := Node3D.new()
	root.add_child(stage)
	stage.add_child(load("res://assets/models/raft-modules/root-decor.glb").instantiate())
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("687981")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-30,0)
	light.light_energy = 1.2
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	for view in ["front","back"]:
		camera.size = 1.65
		camera.position = Vector3(1.4,1.1,-3.0) if view == "back" else Vector3(3.1,1.4,2.7)
		camera.look_at(Vector3(0.65,0.45,-0.25))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/root-barrel-v6-"+view+".png")
	print("ROOT BARREL: captured front/back GPU views")
	quit()
