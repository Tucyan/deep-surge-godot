extends "res://tests/raft_interaction_ui.gd"
func capture(id: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/raft-upgrade-panel-"+id+".png")
func open_cell() -> void:
	app.render(); app.world_view.motion=false; await create_timer(.75).timeout
	await click(interaction().surface.screen_point(app.session.state.cells[1]))
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	for scale_value in [1.0,1.25]:
		app.display_settings.ui_scale=scale_value; app.apply_display_settings(false)
		if app.session.active(): app.handle_command("abandon"); app.handle_ui("settlement_exit")
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
		app.session.state.hand=[]; app.session.state.ap=3
		app.session.state.cells[1].equipment={"id":"filter","level":1,"fuel":0,"progress":0}
		await open_cell()
		var upgrade=app.find_child("RaftAction_upgrade",true,false)
		var reason=app.find_child("RaftHint_upgrade",true,false)
		var shortcut=app.find_child("RaftAction_craft_upgrade",true,false)
		check(upgrade!=null and upgrade.disabled,"No donor still renders disabled upgrade action")
		check(reason!=null and reason.is_visible_in_tree() and "缺少" in reason.text,"Missing donor reason is visible without hovering")
		check(shortcut!=null and shortcut.disabled,"Missing recipe materials disable shortcut")
		var selected_anchor_y: float=interaction().surface.screen_point(app.session.state.cells[1]).y+12
		check(absf(interaction().popup.global_position.y-selected_anchor_y)<1,"Popup follows the selected cell Y without HUD occlusion clamping")
		var selected_right: float=-INF
		var selected_left: float=INF
		var tile=app.world_view.cells.get_node(NodePath(app.session.state.cells[1].id))
		for mesh in tile.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh==null or not mesh.is_visible_in_tree(): continue
			for corner in range(8):
				var pixel: Vector2=app.world_view.camera.unproject_position(mesh.global_transform*mesh.mesh.get_aabb().get_endpoint(corner))
				var point: Vector2=app.world_view.get_global_transform()*(pixel/Vector2(app.world_view.viewport.size)*app.world_view.size)
				selected_right=maxf(selected_right,point.x)
				selected_left=minf(selected_left,point.x)
		check(absf(interaction().popup.global_position.x-(selected_right-(selected_right-selected_left)*.2))<2,"Cell popup starts at selected cell right fifth")
		await capture("missing-%d" % roundi(scale_value*100))
		app.session.give("wood",1,false,"shortcut-fixture"); app.session.give("plastic",2,false,"shortcut-fixture")
		app.session.state.ap=1; await open_cell()
		shortcut=app.find_child("RaftAction_craft_upgrade",true,false)
		reason=app.find_child("RaftHint_craft_upgrade",true,false)
		check(shortcut.disabled and "共2 AP" in reason.text,"Craft shortcut explains total AP shortage")
		app.session.state.ap=3; await open_cell()
		shortcut=app.find_child("RaftAction_craft_upgrade",true,false)
		reason=app.find_child("RaftHint_craft_upgrade",true,false)
		check(not shortcut.disabled and "AP2" in shortcut.text and "×2" in reason.text,"Shortcut displays full recipe and AP price")
		selected_anchor_y=interaction().surface.screen_point(app.session.state.cells[1]).y+12
		check(absf(interaction().popup.global_position.y-selected_anchor_y)<1,"Expanded popup keeps the selected cell Y even when viewport space is limited")
		await capture("ready-%d" % roundi(scale_value*100))
		var before: Dictionary=app.session.snapshot()
		var point: Vector2=shortcut.get_global_rect().get_center()
		if scale_value>1.0:
			for pressed in [true,false]:
				var event:=InputEventScreenTouch.new(); event.index=0; event.pressed=pressed; event.position=root.get_final_transform()*point
				Input.parse_input_event(event); await process_frame
			await settle()
		else: await click(point)
		check(app.session.state.cells[1].equipment.level==2 and app.session.state.ap==before.state.ap-2,"Actual shortcut button completes upgrade and AP debit once")
		check(app.session.I.count(app.session.state,"wood")==0 and app.session.I.count(app.session.state,"plastic")==0,"Actual shortcut button consumes recipe materials")
		await open_cell()
		reason=app.find_child("RaftHint_upgrade",true,false)
		check(reason!=null and "2级" in reason.text,"Level two explains equal-level equipment requirement")
		app.session.state.cells[1].equipment.level=3; await open_cell()
		reason=app.find_child("RaftHint_upgrade",true,false)
		check(reason!=null and "最高等级" in reason.text,"Maximum level still displays upgrade explanation")
		await capture("max-%d" % roundi(scale_value*100))
		for cell in interaction().policy.targets().filter(func(c):return c.kind=="cell"):
			interaction().select_target(cell); await settle()
			var cell_rect: Rect2=interaction().surface.screen_rect(cell)
			var popup_rect: Rect2=interaction().popup.get_global_rect()
			var exposed:=Rect2(cell_rect.position,Vector2(cell_rect.size.x*.8,cell_rect.size.y))
			check(not popup_rect.intersects(exposed.grow(-1)),"Popup leaves selected cell left four fifths exposed: "+cell.id)
			check(absf(popup_rect.position.x-(cell_rect.end.x-cell_rect.size.x*.2))<2,"Popup overlaps only the selected cell right fifth")
		interaction().select_target({})
	app.queue_free(); await settle()
	print("RAFT UPGRADE PANEL UI: "+("PASS" if failures==0 else "FAIL")); quit(failures)
