extends "res://tests/raft_interaction_ui.gd"
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.session.state.hand=[]
	for index in range(app.session.state.cells.size()):
		app.session.state.cells[index].equipment={"id":"lamp" if index==0 else "planter" if index==1 else "filter","level":2,"fuel":2,"progress":1}
	var before: Dictionary=app.session.snapshot()
	for scale_value in [1.0,1.25]:
		app.display_settings.ui_scale=scale_value; app.apply_display_settings(false); app.world_view.motion=false
		await create_timer(.8).timeout
		interaction().select_target(interaction().policy.targets().filter(func(c):return c.id==app.session.state.cells[2].id)[0]); await settle()
		for cell in app.session.state.cells:
			var label: Label3D=app.world_view.cells.get_node(NodePath(cell.id+"/StateLabel"))
			check(label.no_depth_test and label.render_priority>0 and label.outline_render_priority>0,"Device annotation and outline stay visible through geometry")
			if cell.equipment.id=="planter": check("成长完" in label.text,"Mature planter description is present")
			if cell.equipment.id=="filter": check("本轮产水" in label.text,"Ready filter description is present")
		var bounds: Rect2=interaction().surface.screen_rect(interaction().selected)
		check(absf(interaction().popup.global_position.x-(bounds.end.x-bounds.size.x*.2))<2,"Popup aligns with selected cell right fifth")
		var frozen_y: float=interaction().popup.position.y
		app.world_view.motion=true
		for _frame in range(45): await process_frame
		check(absf(interaction().popup.position.y-frozen_y)<0.1,"Popup vertical position stays fixed while raft bobs and tilts")
		app.world_view.motion=false
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/raft-annotations-%d.png" % roundi(scale_value*100))
		app.world_view.viewport.get_texture().get_image().save_png("res://evidence/raft-annotations-world-%d.png" % roundi(scale_value*100))
	check(app.session.snapshot()==before,"Annotation styling and popup location preserve rules and RNG")
	app.queue_free(); await settle()
	print("RAFT ANNOTATIONS VISUAL: "+("PASS" if failures==0 else "FAIL")); quit(failures)
