extends SceneTree
var failures:=0
func _init(): call_deferred("run")
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func run():
	var assets=preload("res://presentation/asset_catalog.gd").new()
	check(assets.has_method("warm_textures"),"bounded asynchronous texture warmup exists")
	if failures: quit(1); return
	var catalog=preload("res://content/catalog.gd").new(); catalog.load_catalog()
	var session=preload("res://core/game_session.gd").new(catalog)
	session.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	var before: Dictionary=session.snapshot(); var frame:=Engine.get_process_frames()
	await assets.warm_textures(["card.filter","card.lamp","missing.warmup"],root)
	check(Engine.get_process_frames()>frame,"warmup yields instead of loading all textures in one input frame")
	for id in ["card.filter","card.lamp"]:
		check(assets._cache.has(id),"warmup populates shared texture cache "+id)
		var texture: Texture2D=assets.texture(id)
		check(texture==assets._cache[id] and texture.get_width()>64,"normal texture requests reuse valid warmed resource")
	check(not assets._cache.has("missing.warmup"),"unknown warmup IDs are ignored")
	check(session.snapshot()==before,"background art does not change rules, revision or RNG")
	var canceled=preload("res://presentation/asset_catalog.gd").new()
	var owner:=Node.new(); root.add_child(owner)
	canceled.warm_textures(["card.planter"],owner); owner.queue_free()
	for i in range(30): await process_frame
	check(not canceled._cache.has("card.planter"),"removed owner does not retain warmed UI art")
	print("ASSET WARMUP: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
