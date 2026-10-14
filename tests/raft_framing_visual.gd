extends SceneTree
var app
var failures := 0
func _init(): call_deferred("run")
func capture(id):
	await process_frame; await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/raft-framing-"+id+".png")
	var world = app.world_view
	var lo := Vector2(INF,INF); var hi := Vector2(-INF,-INF)
	for mesh in world.raft.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
		var aabb: AABB = mesh.mesh.get_aabb()
		for i in range(8):
			var pixel: Vector2 = world.camera.unproject_position(mesh.global_transform*aabb.get_endpoint(i))
			lo=lo.min(pixel); hi=hi.max(pixel)
	var wanted: Vector2 = Vector2(world.viewport.size)*world.RAFT_SCREEN_CENTER
	var error := ((lo+hi)*0.5-wanted).length()
	print(id," raft centre=",(lo+hi)*0.5," target=",wanted," error=",error)
	if error > 2.0: failures+=1
func run():
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	app.handle_command("new",{"mode":"story","origin":"fool","seed":22})
	app.world_view.motion=false
	await capture("initial-1280")
	app.session.state.cells.append({"id":"framing-extra","x":0,"y":2,"status":"intact","equipment":{}})
	app.session.state.cells[0].equipment={"id":"filter","level":2,"fuel":0,"progress":0}
	app.session.state.phase="discard"
	for i in range(8): app.session.I.give(app.session.state,"wood",1,false,"framing-fixture")
	app.render()
	await capture("expanded-1280")
	root.size=Vector2i(1600,900); await capture("expanded-1600")
	app.queue_free(); await process_frame
	print("RAFT FRAMING: PASS" if failures==0 else "RAFT FRAMING: FAIL")
	quit(0 if failures==0 else 1)
