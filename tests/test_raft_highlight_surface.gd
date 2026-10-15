extends SceneTree
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await process_frame
	app.world_view.motion=false
	var surface=app.find_child("RaftInteraction",true,false).surface
	var before: Dictionary=app.session.snapshot()
	for cell in app.session.state.cells:
		var deck=app.world_view.cells.get_node(NodePath(cell.id+"/Deck"))
		var vertices:=PackedVector3Array()
		for mesh in deck.find_children("*","MeshInstance3D",true,false):
			for vertex in mesh.mesh.get_faces(): vertices.append(mesh.global_transform*vertex)
		for tint in ["white","green"]:
			var highlight=surface._ghost(cell,tint)
			var fill=highlight.get_node("TranslucentFill")
			var furthest: float=0
			for vertex in fill.mesh.get_faces():
				var point: Vector3=fill.global_transform*vertex
				var closest: float=INF
				for source in vertices: closest=minf(closest,point.distance_to(source))
				furthest=maxf(furthest,closest)
			check(furthest<.004,"%s %s highlight hugs actual deck geometry (gap %.4f)" % [cell.id,tint,furthest])
			check(fill.mesh.get_faces().size()>6,"Highlight follows planks instead of a floating quad")
			check(highlight.find_children("*Rim*","MeshInstance3D",true,false).is_empty(),"Surface highlight has no extra outlines")
			highlight.queue_free()
	check(app.session.snapshot()==before,"Surface overlay leaves rules and RNG untouched")
	app.queue_free(); await process_frame
	print("RAFT HIGHLIGHT SURFACE: "+("PASS" if failures==0 else "FAIL")); quit(failures)
