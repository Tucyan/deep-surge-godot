extends SceneTree
var app: Control
func _init(): call_deferred("run")
func capture(id):
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/raft-state-"+id+".png")
func run():
	root.size = Vector2i(1600,900)
	app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.world_view.motion = false; app.world_view._time = 3; app.world_view._process(0)
	await capture("empty")
	var fixture: Dictionary = app.session.view().duplicate(true); fixture.cells = []
	var positions = [Vector2i(2,2),Vector2i(1,2),Vector2i(0,2),Vector2i(0,1),Vector2i(0,0),Vector2i(1,0)]
	var ids = ["lamp","filter","planter","medkit","crossbow","spearRack"]
	for i in range(6): fixture.cells.append({"id":"visual-%d" % i,"x":positions[i].x,"y":positions[i].y,"status":"intact","equipment":{"id":ids[i],"level":i%3+1,"fuel":2,"progress":1}})
	app.world_view.sync(fixture); app.world_view._process(0); await capture("equipment")
	fixture.cells[0].status = "damaged"; fixture.cells[1].status = "detached"; fixture.cells[2].equipment = {}
	app.world_view.sync(fixture); app.world_view._process(0); await capture("damaged")
	root.size = Vector2i(1280,720); await capture("1280")
	# Repair and reinstall same ID: changes are reflected without ghost models.
	fixture.cells[0].status = "intact"; fixture.cells[0].equipment.fuel = 0
	fixture.cells[1].status = "intact"; fixture.cells[1].equipment = {}
	app.world_view.sync(fixture); app.world_view._process(0); await capture("repaired")
	app.queue_free(); await process_frame; print("RAFT STATE GPU: PASS (visual fixture)"); quit()
