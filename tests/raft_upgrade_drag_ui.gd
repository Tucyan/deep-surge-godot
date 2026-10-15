extends "res://tests/raft_interaction_ui.gd"
func capture(id: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/raft-upgrade-"+id+".png")
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	for scale_value in [1.0,1.25]:
		app.display_settings.ui_scale=scale_value; app.apply_display_settings(false)
		if app.session.active(): app.handle_command("abandon"); app.handle_ui("settlement_exit")
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
		app.session.state.cells[1].equipment={"id":"filter","level":1,"fuel":0,"progress":0}
		app.session.give("filter",2,false,"merge-fixture"); app.render(); app.world_view.motion=false; await create_timer(.8).timeout
		var fan=get_nodes_in_group("hand_fans").filter(func(f):return app.layout.is_ancestor_of(f))[0]
		var card: Dictionary=fan.cards.filter(func(c):return c.id=="filter")[0]
		var point: Vector2=interaction().surface.screen_point(app.session.state.cells[1])
		var before: Dictionary=app.session.snapshot()
		interaction()._dragged(card,point)
		check(is_instance_valid(interaction().surface.drop),"Matching equipment previews merge")
		if is_instance_valid(interaction().surface.drop):
			check(interaction().surface.drop.find_children("*Rim*","MeshInstance3D",true,false).is_empty(),"Green merge highlight has no extra lines")
			check(interaction().surface.drop.find_children("*","MeshInstance3D",true,false).size()==1,"Green merge shows only one fill mesh")
			var fill=interaction().surface.drop.get_node_or_null("TranslucentFill")
			check(fill!=null,"Green merge has a fill")
			if fill!=null: check(fill.material_override.albedo_color.g>fill.material_override.albedo_color.r and fill.material_override.albedo_color.g>fill.material_override.albedo_color.b and fill.material_override.albedo_color.a<.4,"Allowed merge preview is translucent green")
		check(app.session.snapshot()==before,"Merge preview never consumes resources")
		await drag(card.uid,point,scale_value>1.0)
		check(app.session.state.cells[1].equipment.level==2,"Hand equipment drop upgrades level one")
		check(app.session.state.ap==before.state.ap-1 and not app.session.state.hand.any(func(c):return c.uid==card.uid),"Merge spends one AP and the dragged card")
		fan=get_nodes_in_group("hand_fans").filter(func(f):return app.layout.is_ancestor_of(f))[0]
		card=fan.cards.filter(func(c):return c.id=="filter")[0]
		before=app.session.snapshot()
		interaction()._released(card,interaction().surface.screen_point(app.session.state.cells[1])); await settle()
		check(app.session.snapshot()==before,"Level-one hand card cannot merge into level-two equipment")
	app.queue_free(); await settle()
	print("RAFT UPGRADE DRAG UI: "+("PASS" if failures==0 else "FAIL")); quit(failures)
