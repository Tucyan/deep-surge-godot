extends SceneTree
var failures:=0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle():
	await process_frame; await process_frame; await process_frame
func capture(name: String):
	if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/acquisition-layout-"+name+".png")
func run():
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	for i in range(24): app.session.Collectibles.acquire(app.session,["lifeboatTag","rationTin","fittersBadge","spearParcel","borrowedPulse","luckyKnot"][i%6])
	for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=dimensions; await settle()
		app.render(); app.handle_command("panel",{"id":"collectibles"}); await settle()
		var page=app.current_page; var snapshot: Dictionary=app.session.snapshot()
		var visible:=Rect2(Vector2.ZERO,app.size)
		check(visible.grow(1).encloses(page.grid.get_global_rect()),"warehouse grid fits "+str(dimensions))
		check(visible.grow(1).encloses(page.footer.get_global_rect()),"pager fits "+str(dimensions))
		var region=page.find_child("CollectibleDetailImageRegion",true,false)
		check(region.size.y<=page.detail.size.y*.35,"detail image third "+str(dimensions))
		await capture("warehouse-%dx%d" % [dimensions.x,dimensions.y])
		page.footer.get_children().back().pressed.emit(); await settle()
		check(app.session.snapshot()==snapshot,"paging is presentation-only")
		app.handle_command("close"); await settle()
		var items: Array=[]
		for i in range(9): items.append({"id":"wood","uid":"layout-%d" % i,"definition":app.catalog.entry("cards","wood")})
		var overlay=load("res://presentation/acquisition_overlay.gd").new(); app.add_child(overlay)
		overlay.configure({"source":"打捞","kind":"card","items":items},app.assets,app.size*Vector2(.5,.9))
		await create_timer(.25).timeout
		for tile in overlay.tiles: check(visible.grow(1).encloses(tile.get_global_rect()),"acquired card fits "+str(dimensions))
		check(overlay.pagination.get_child_count()==3,"large receipt can page")
		overlay.pagination.get_children().back().pressed.emit(); await settle()
		check(overlay.page_index==1,"receipt page advances")
		await capture("cards-%dx%d" % [dimensions.x,dimensions.y])
		overlay.collect(); await overlay.completed; overlay.queue_free(); await settle()
	app.queue_free(); await process_frame
	print("ACQUISITION LAYOUT: "+("PASS" if failures==0 else "FAIL")); quit(failures)
