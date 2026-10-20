extends SceneTree
const IDS=preload("res://tests/test_relic_expedition.gd").IDS
var failures:=0
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init(): call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var assets=load("res://presentation/asset_catalog.gd").new()
	var art=load("res://presentation/collectible_art.gd").new()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json")).assets
	var paths: Array=[]
	for id in IDS:
		var d: Dictionary=manifest.get("relic."+id,{})
		check(d.get("path","").begins_with("res://assets/collectibles/"),"独立图片注册："+id)
		if not d.get("path","").begins_with("res://assets/collectibles/"): continue
		check(d.path not in paths,"图片不复用："+id); paths.append(d.path)
		check(d.get("dimensions",[]).size()==2 and int(d.dimensions[0])==512 and int(d.dimensions[1])==512 and d.has("sha256") and d.has("source_sha256"),"尺寸与来源hash："+id)
		art.configure(id,assets)
		check(art.texture==assets.texture("relic."+id),"获取/仓库使用对应缓存："+id)
		var im: Image=art.texture.get_image()
		check(im.get_pixel(0,0).a==0.0,"保留透明背景："+id)
	art.configure("unknown-test-id",assets)
	check(art.texture==assets.texture(art.ASSET_ID),"未知ID保持占位回退")
	art.free()
	var catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	var s=load("res://core/game_session.gd").new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"new")
	for id in IDS:
		s.Collectibles.acquire(s,id); s.profile.discovered.append("relic."+id)
	var before: Dictionary=s.snapshot()
	var page=load("res://pages/collectibles_page.gd").new(); root.add_child(page)
	page.size=Vector2(1280,720); page.theme=load("res://presentation/widgets.gd").theme()
	page.setup(s.view(),catalog,null)
	await process_frame; await process_frame
	check(page.grid.get_child_count()==20,"仓库列出20件独立实例")
	check(page.find_children("CollectiblePlaceholder","TextureRect",true,false).size()>=20,"格子和详情应用图片")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://evidence/survival-departure-20261021/art-warehouse.png") == OK,"save current survival UI evidence")
	check(s.snapshot()==before,"仓库浏览不改规则或随机")
	page.free()
	var mobile_view: Dictionary=s.view(); mobile_view.mobile=true
	root.size=Vector2i(1600,720)
	page=load("res://pages/collectibles_page.gd").new(); root.add_child(page)
	page.size=Vector2(root.size); page.theme=load("res://presentation/widgets.gd").theme()
	page.setup(mobile_view,catalog,assets)
	await process_frame; await process_frame
	check(page.grid.columns==3 and page.grid.get_child_count()==20,"手机三列可滚动显示全套藏品")
	check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(page.grid_scroll.get_global_rect()),"手机网格视口不越界")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://evidence/survival-departure-20261021/art-mobile.png") == OK,"save current survival UI evidence")
	page.free()
	# The current event contract keeps desktop art intact and covers the mobile panel.
	for mobile in [false,true]:
		for node_id in preload("res://tests/test_relic_expedition.gd").NODES:
			s.state.node=catalog.entry("nodes",node_id); s.state.node.visit_id="art-fixture"
			s.state.phase="story"; s.state.story_step="choice"; s.Encounter.arrived(s)
			var view: Dictionary=s.view(); view.mobile=mobile
			var event=load("res://pages/flow_story.gd").new(); root.add_child(event)
			event.size=Vector2(1488,560); event.position=Vector2(56,124); event.theme=load("res://presentation/widgets.gd").theme()
			event.setup(view,catalog,assets)
			await process_frame; await process_frame
			check(event.art_view.texture==assets.texture(s.state.node.art),"新节点使用主题藏品图片："+node_id)
			var expected_stretch: int=TextureRect.STRETCH_KEEP_ASPECT_COVERED if mobile else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			check(event.art_view.stretch_mode==expected_stretch,("手机合并面板铺满底图：" if mobile else "桌面立绘完整显示不裁切：")+node_id)
			check(event.entries.size()==3,"两个奖励选项和退出："+node_id)
			if not mobile and node_id=="riggersCache" and DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png("res://evidence/survival-departure-20261021/art-node.png") == OK,"save current survival UI evidence")
			event.free()
	s.panel="encyclopedia"
	var encyclopedia_view: Dictionary=s.view(); encyclopedia_view.ui_state={"category":"relics","list_page":3,"selected_id":"sailorsKnot","encyclopedia_tab":"story"}
	page=load("res://pages/paged_reference.gd").new(); root.add_child(page)
	page.size=Vector2(root.size); page.theme=load("res://presentation/widgets.gd").theme()
	page.setup(encyclopedia_view,catalog,assets)
	await process_frame; await process_frame
	check(page.find_child("DetailCopy",true,false).text==catalog.entry("relics","sailorsKnot").story,"图鉴显示新案故事")
	check(page.find_child("DetailImage",true,false).texture==assets.texture("relic.sailorsKnot"),"图鉴使用同一藏品原图")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://evidence/survival-departure-20261021/art-encyclopedia.png") == OK,"save current survival UI evidence")
	page.free()
	print("RELIC ART: %s" % ["PASS" if failures==0 else "FAIL"]); quit(failures)
