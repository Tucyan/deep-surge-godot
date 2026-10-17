extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/icons/recipes")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512); viewport.transparent_bg = true
	viewport.own_world_3d = true; root.add_child(viewport)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	viewport.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-45,-35,0)
	light.light_energy = 1.4; viewport.add_child(light)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	for id in ["shieldRack","generator","fishingNet","crate"]:
		var path := "res://assets/models/props/storage-crate-module.tscn" if id == "crate" else "res://assets/models/raft-modules/%s.glb" % id
		var model = load(path).instantiate()
		viewport.add_child(model)
		var bounds := AABB()
		var first := true
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box); first = false
		var center := bounds.get_center()
		camera.position = center + Vector3(2.4,2.0,3.0) * maxf(bounds.size.length(),0.1)
		camera.look_at(center)
		camera.size = bounds.size.length() * 1.12
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var used := image.get_used_rect()
		image = image.get_region(used)
		var side := maxi(image.get_width(),image.get_height()) + 24
		var square := Image.create(side,side,false,Image.FORMAT_RGBA8)
		square.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),(Vector2i(side,side)-image.get_size())/2)
		square.resize(512,512,Image.INTERPOLATE_LANCZOS)
		var error := square.save_png("res://assets/icons/recipes/%s.png" % id)
		if error != OK: quit(1); return
		viewport.remove_child(model); model.queue_free()
	print("RECIPE ICONS: rendered four existing models")
	quit()
