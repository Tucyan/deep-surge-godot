extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func _init(): call_deferred("run")
func run():
	var app = load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await process_frame
	var world=app.world_view
	var before: Dictionary=app.session.snapshot()
	for id in ["lamp","filter","planter","generator","fishingNet","crate","crossbow","spearRack","shieldRack"]:
		for level in [1,2,3]:
			var cell: Dictionary=app.session.state.cells[0].duplicate(true)
			cell.equipment={"id":id,"level":level,"fuel":2,"progress":1,"boost_cards":[]}
			var unchanged: Dictionary=cell.duplicate(true)
			var tile=world.raft_models.build(world,cell,world._font)
			var label: Label3D=tile.get_node("StateLabel")
			check(label.text=="3 · "+world.raft_models.NAMES[id]+" %d级" % level,"compact label "+id+str(level))
			var bar=tile.get_node_or_null("ProductionProgress")
			var expected: bool=id in ["filter","planter","generator"] and level==1
			check((bar!=null)==expected,"only multi-round production has a bar "+id+str(level))
			if bar!=null:
				check(is_equal_approx(bar.get_meta("ratio"),.5),"real production progress is half")
			check(cell==unchanged,"projection preserves equipment state")
			tile.free()
	for progress in [0,1,2,99]:
		var cell: Dictionary=app.session.state.cells[0].duplicate(true)
		cell.status="damaged"
		cell.equipment={"id":"generator","level":1,"fuel":0,"progress":progress,"boost_cards":[]}
		var tile=world.raft_models.build(world,cell,world._font)
		check(is_equal_approx(tile.get_node("ProductionProgress").get_meta("ratio"),clampf(float(progress)/2,0,1)),"paused progress stays bounded and does not advance")
		check(tile.get_node("StateLabel").text=="3 · 发电机 1级","damaged equipment also has one compact line")
		tile.free()
	check(app.session.snapshot()==before,"labels preserve game and RNG")
	if "--capture" in OS.get_cmdline_user_args():
		root.size=Vector2i(1280,720); world.motion=false
		for fixture in ["net","progress"]:
			for i in range(4):
				app.session.state.cells[i].equipment={}
			if fixture=="net":
				app.session.state.cells[0].equipment={"id":"fishingNet","level":1,"fuel":0,"progress":0,"boost_cards":[]}
			else:
				for i in range(4):
					app.session.state.cells[i].equipment={"id":["filter","planter","generator","fishingNet"][i],"level":1,"fuel":2,"progress":1 if i<3 else 0,"boost_cards":[]}
			app.render()
			await create_timer(.6).timeout
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://evidence/raft-labels-"+fixture+".png")==OK,"capture "+fixture)
	app.queue_free(); await process_frame
	print("COMPACT RAFT LABELS: "+("PASS" if failures==0 else "FAIL")); quit(failures)

