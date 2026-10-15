extends "res://tests/raft_interaction_ui.gd"

func capture(id: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/raft-fuel-"+id+".png")

func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	for scale_value in [1.0,1.25]:
		app.display_settings.ui_scale=scale_value; app.apply_display_settings(false)
		if app.session.active(): app.handle_command("abandon"); app.handle_ui("settlement_exit")
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
		for cell in app.session.state.cells: cell.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
		app.session.state.cells[1].equipment={"id":"lamp","level":1,"fuel":0,"progress":0}
		app.session.give("wood",4,false,"fuel-fixture"); app.session.give("corpse",2,false,"fuel-fixture")
		app.render(); app.world_view.motion=false; await create_timer(.8).timeout
		for material in ["wood","corpse"]:
			var fan=get_nodes_in_group("hand_fans").filter(func(f):return app.layout.is_ancestor_of(f))[0]
			var card: Dictionary=fan.cards.filter(func(c):return c.id==material)[0]
			check(fan.raft_draggable(card),"Fuel card supports raft drag")
			var before: Dictionary=app.session.snapshot()
			interaction()._released(card,interaction().surface.screen_point(app.session.state.cells[0])); await settle()
			check(app.session.snapshot()==before,"Dropping fuel on another device spends nothing")
			app.session.state.cells[1].status="damaged"; interaction().policy.refresh(app.session)
			before=app.session.snapshot()
			interaction()._released(card,interaction().surface.screen_point(app.session.state.cells[1])); await settle()
			check(app.session.snapshot()==before,"Damaged lamp rejects fuel")
			app.session.state.cells[1].status="intact"; interaction().policy.refresh(app.session)
			before=app.session.snapshot()
			await drag(card.uid,interaction().surface.screen_point(app.session.state.cells[1]),scale_value>1.0)
			check(app.session.I.count(app.session.state,material)==app.session.I.count(before.state,material)-1,"Drop spends exactly one fuel card, including stacks")
			check(not app.session.state.hand.any(func(c):return c.uid==card.uid),"Drop consumes the dragged UID")
			check(app.session.state.cells[1].equipment.fuel==before.state.cells[1].equipment.fuel+(1 if material=="wood" else 3),"Existing wood/corpse fuel value preserved")
			check(app.session.state.ap==before.state.ap,"Refueling costs no AP")
		await click(interaction().surface.screen_point(app.session.state.cells[1]))
		check(is_instance_valid(interaction().surface.selected),"Lamp cell selects")
		await capture("white-selection-%d" % roundi(scale_value*100))
		await click(interaction().surface.screen_point(app.session.state.cells[1]))
		check(interaction().selected.is_empty() and not is_instance_valid(interaction().popup),"Repeated actual click deselects cell")
	app.queue_free(); await settle()
	print("RAFT FUEL DRAG UI: "+("PASS" if failures==0 else "FAIL")); quit(failures)
