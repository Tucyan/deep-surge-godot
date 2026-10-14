extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func _init() -> void: call_deferred("run")
func run() -> void:
	check(FileAccess.file_exists("res://presentation/toon_ocean.gd"),"需要风格化夜海组件")
	if failures: quit(1); return
	var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await process_frame
	var ocean = app.world_view.toon_ocean
	check(ocean != null and app.world_view.ocean == ocean,"默认航行使用风格化夜海")
	check(app.world_view.model_ocean == null,"夜海成功时不再加载原GLB海面")
	check(not app.world_view.texture_ocean.sea.visible,"纹理回退平面隐藏")
	check(app.world_view.get_material() is ShaderMaterial,"航行视口使用冷夜调色")
	check(ocean.material.get_shader_parameter("cell_count") == 6,"接触环按四个在位筏格和两个装饰筏根生成")
	var saved: Dictionary = app.session.snapshot()
	for time in [0.0,0.7,1.9,3.3,5.0,7.5,11.2,0.0001]:
		app.world_view._time = time; app.world_view.motion = false; app.world_view._process(0)
		# Shader/GDScript parity: forward vertex displacement must match the inverse height query.
		for g in [Vector2(7,2),Vector2(-9,4.5),Vector2(3,-11),Vector2(12.5,9),Vector2(-4,-6)]:
			var point: Vector3 = ocean.surface_point(g)
			check(absf(ocean.height_at(point.x,point.z)-point.y) < .01,"浮动采样与顶点位移一致 t=%s g=%s" % [time,g])
		for tile in app.world_view.cells.get_children():
			for corner in [Vector3(-1.1,-0.25,-1.0),Vector3(1.1,-0.25,-1.0),Vector3(-1.1,-0.25,1.0),Vector3(1.1,-0.25,1.0)]:
				var point: Vector3 = tile.to_global(corner)
				check(point.y-ocean.height_at(point.x,point.z) < -0.1,"各格筏底持续浸水，不悬空")
		for edge in app.world_view.texture_ocean.contact_edges:
			var a: Vector3 = edge.a
			check(absf(ocean.height_at(a.x,a.z)-ocean.plane_at(a.x,a.z)) < .005,"泡沫边与船边实际水面一致")
		check(absf(app.world_view.raft.rotation.x) < .026 and absf(app.world_view.raft.rotation.z) < .026,"木筏倾斜不过量")
	var far_height: float = ocean.height_at(40,0)
	check(absf(far_height) < .0001,"远景振幅衰减到平面，与远景平面衔接")
	var view: Dictionary = app.session.view().duplicate(true); view.cells[0].status = "detached"
	app.world_view.sync(view)
	check(ocean.material.get_shader_parameter("cell_count") == 5,"脱落后接触环保留装饰筏根并移除脱落格")
	app.world_view.sync(app.session.view())
	check(app.session.snapshot() == saved,"夜海播放/水线/泡沫不改变规则与随机")
	app.queue_free(); await process_frame
	print("TOON OCEAN: %s" % ("PASS" if failures == 0 else "FAIL")); quit(0 if failures == 0 else 1)
