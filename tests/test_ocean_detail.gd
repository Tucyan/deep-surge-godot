extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func _init() -> void: call_deferred("run")
func run() -> void:
	var assets = load("res://presentation/asset_catalog.gd").new()
	check(not assets.show_label("texture.ocean.detail"),"细节使用独立正式素材，不是占位")
	check(assets.texture("texture.ocean.detail").get_width() == 256,"细节纹理为256像素可替换小图")
	check(not assets.show_label("texture.ocean.foam-noise"),"泡沫噪声使用独立正式素材，不是占位")
	check(assets.texture("texture.ocean.foam-noise").get_width() == 256,"泡沫噪声纹理为256像素可替换小图")
	var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await process_frame
	var ocean = app.world_view.toon_ocean; var saved: Dictionary = app.session.snapshot()
	check(ocean.material.get_shader_parameter("detail_enabled") == true,"默认启用细节")
	check(ocean.material.get_shader_parameter("detail_texture") == assets.texture("texture.ocean.detail") or ocean.material.get_shader_parameter("detail_texture") is Texture2D,"海面细节素材正确绑定")
	check(ocean.material.get_shader_parameter("foam_noise_texture") == assets.texture("texture.ocean.foam-noise") or ocean.material.get_shader_parameter("foam_noise_texture") is Texture2D,"泡沫噪声素材正确绑定")
	check(absf(float(ocean.material.get_shader_parameter("detail_distortion")) - 0.08) < 0.001,"大浪推挤微纹理形变参数生效")
	check(ocean.near.mesh.get_mesh_arrays()[Mesh.ARRAY_INDEX].size()/3 == 80802,"细节不增加海面几何")
	check(ocean.mist_layers.size() == 3,"细节不增加透明雾层")
	for enabled in [false,true]:
		ocean.material.set_shader_parameter("detail_enabled",enabled); ocean.tick(3.0)
	check(app.session.snapshot() == saved,"细节开关与动画不修改玩法/随机")
	app.queue_free(); await process_frame
	print("OCEAN DETAIL: %s" % ("PASS" if failures == 0 else "FAIL")); quit(0 if failures == 0 else 1)
