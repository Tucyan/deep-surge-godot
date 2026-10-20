extends SceneTree
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+text)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var assets = load("res://presentation/asset_catalog.gd").new()
	for id in ["wood","iron","plastic","rope","cloth","food","water","calm","punch","arrow","spear","lamp","filter","planter","medkit","crossbow","spearRack","repair","dismantle","corpse","coin"]:
		check(not assets.show_label("card."+id),"实际PNG载入，隐藏占位叠字："+id)
		check(assets.texture("card."+id).get_size().x > 64,"图片源尺寸保留："+id)
	check(not assets.show_label("ui.unavailable"),"禁用工具图标接入")
	check(assets.texture("ui.card.front").get_size() == Vector2(654,1004),"原UI前面通过图集区域独立绑定")
	check(assets.texture("ui.card.back").get_size() == Vector2(610,1000),"原UI背面通过图集区域独立绑定")
	for id in ["combat","survival","material"]: check(not assets.show_label("ui.card.type."+id),"类别徽章："+id)
	var model: PackedScene = assets.model("model.ocean")
	check(model != null,"用户水面转换为独立可加载3D素材")
	if model != null:
		var ocean = load("res://presentation/supplied_ocean.gd").new()
		root.add_child(ocean); check(ocean.create(assets),"海面实例/数据/材质绑定完整")
		check(ocean.meshes.size() == 9,"九个周期拼接海面")
		check(ocean.meshes[0].mesh.get_blend_shape_count() == 15,"16采样姿态在Godot导入15个形变")
		check(ocean.meshes[0].mesh == ocean.meshes[-1].mesh,"共享网格缓存，实例控制权重")
		var arrays: Array = ocean.meshes[0].mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_TEX_UV].size() > 0,"泡沫使用导入UV")
		var mesh_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var first: Vector3 = ocean.vertex(0)
		check(mesh_vertices.find(first) >= 0,"采样二进制和GLB基准坐标一致")
		var initial: float = ocean.height_at(0,0)
		ocean.tick(3.1); check(absf(initial-ocean.height_at(0,0)) > 0.001,"波形和浮动采样随时间变化")
		var period: float = float(ocean.config.frames)*float(ocean.config.frame_seconds)
		ocean.tick(period-0.0001); var tail: float = ocean.height_at(0,0)
		ocean.tick(0.0001); check(absf(tail-ocean.height_at(0,0)) < 0.01,"循环边界高度连续")
		ocean.queue_free(); await process_frame
	print("SUPPLIED ASSETS ENTRY: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
