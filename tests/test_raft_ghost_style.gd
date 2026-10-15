extends SceneTree
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await process_frame
	var control=app.find_child("RaftInteraction",true,false); var surface=control.surface
	var target: Dictionary=app.session.state.cells[0]
	var before: Dictionary=app.session.snapshot()
	for tint in ["red","blue","white"]:
		var ghost=surface._ghost(target,tint)
		var fill=ghost.get_node_or_null("TranslucentFill")
		if tint=="white":
			check(fill is MeshInstance3D,"White selection uses a translucent fill")
			check(ghost.find_children("*Rim*","MeshInstance3D",true,false).is_empty(),"White selection has no additional outlines")
			if fill!=null:
				var material: StandardMaterial3D=fill.material_override
				check(material.albedo_color.r>.95 and material.albedo_color.g>.95 and material.albedo_color.b>.95 and material.albedo_color.a<.4,"Selected cell is translucent pure white")
		else:
			check(fill is MeshInstance3D,"Red/blue ghost has a translucent fill")
			if fill!=null:
				var material: StandardMaterial3D=fill.material_override
				check(material.albedo_color.a>0.05 and material.albedo_color.a<=.2,"Fill stays highly transparent")
				check(material.albedo_color.r>material.albedo_color.b if tint=="red" else material.albedo_color.b>material.albedo_color.r,"Fill matches outline hue")
		if tint!="white":
			var rim: MeshInstance3D=ghost.find_children("*Rim*","MeshInstance3D",true,false)[0]
			check(maxf(absf(rim.scale.x),absf(rim.scale.z))>1.2,"Red/blue outline gains thickness")
		ghost.queue_free()
	control._press(surface.screen_point(target)); control._release(surface.screen_point(target))
	check(control.selected.get("id","")==target.id,"First cell click selects it")
	control._press(surface.screen_point(target)); control._release(surface.screen_point(target))
	check(control.selected.is_empty() and not is_instance_valid(control.popup) and not is_instance_valid(surface.selected),"Repeated cell click clears highlight and popup")
	check(app.session.snapshot()==before,"Style changes do not mutate rules or RNG")
	app.queue_free(); await process_frame
	print("RAFT GHOST STYLE: "+("PASS" if failures==0 else "FAIL")); quit(failures)
