extends SceneTree
var app
var failures:=0
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void: call_deferred("run")
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func interaction(): return app.find_child("RaftInteraction",true,false)
func capture(id: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/raft-interaction-"+id+".png")
func mouse(pressed: bool,point: Vector2) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
	event.position=root.get_final_transform()*point; event.global_position=event.position
	Input.parse_input_event(event); await process_frame
func click(point: Vector2) -> void:
	await mouse(true,point); await mouse(false,point); await settle()
func drag(uid: String,target: Vector2,touch: bool) -> void:
	var fan=get_nodes_in_group("hand_fans").filter(func(f):return app.layout.is_ancestor_of(f))[0]
	var index: int=fan.cards.find(fan.cards.filter(func(c):return c.uid==uid)[0])
	fan.focus_card(index); await settle()
	var start: Vector2=fan.tiles[index].global_position+Vector2(35,75)
	if touch:
		var down:=InputEventScreenTouch.new(); down.index=0; down.pressed=true; down.position=root.get_final_transform()*start
		Input.parse_input_event(down); await process_frame
	else: await mouse(true,start)
	await create_timer(.25).timeout
	check(fan.dragging,"Long press enters drag")
	if touch:
		var move:=InputEventScreenDrag.new(); move.index=0; move.position=root.get_final_transform()*target
		Input.parse_input_event(move)
	else:
		var move:=InputEventMouseMotion.new(); move.position=root.get_final_transform()*target; move.global_position=move.position; move.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(move)
	await settle()
	check(is_instance_valid(interaction().surface.drop),"Hover empty slot displays equipment ghost")
	await capture("drop-%s-%d" % ["touch" if touch else "mouse",roundi(app.display_settings.ui_scale*100)])
	if touch:
		var up:=InputEventScreenTouch.new(); up.index=0; up.pressed=false; up.position=root.get_final_transform()*target
		Input.parse_input_event(up); await process_frame
	else: await mouse(false,target)
	await settle()
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	for scale_value in [1.0,1.25]:
		app.display_settings.ui_scale=scale_value; app.apply_display_settings(false)
		if app.session.active(): app.handle_command("abandon"); app.handle_ui("settlement_exit")
		app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
		app.session.give("filter",1,false,"drag-fixture"); app.render(); app.world_view.motion=false; await settle()
		var cell: Dictionary=app.session.state.cells[1]
		var uid: String=app.session.state.hand.filter(func(c):return c.id=="filter")[0].uid
		var before: Dictionary=app.session.snapshot(); var ap: int=app.session.state.ap
		var target: Vector2=interaction().surface.screen_point(cell)
		check(interaction().surface.pick(target,interaction().policy.targets()).id==cell.id,"Projection picks real cell through canvas scaling")
		await drag(uid,target,scale_value>1.0)
		check(app.session.state.cells[1].equipment.get("id","")=="filter","Drop installs selected UID into selected cell")
		check(app.session.state.ap==ap-1 and not app.session.state.hand.any(func(c):return c.uid==uid),"Installation spends one AP and exact card")
		await click(interaction().surface.screen_point(app.session.state.cells[1]))
		check(is_instance_valid(interaction().popup),"Actual cell click opens micro panel")
		check(is_instance_valid(interaction().surface.selected),"Cell selection has 3D outline")
		await capture("selected-%d" % roundi(scale_value*100))
		# Full-raft fixture only changes occupancy; real expansion still uses rule commands.
		for c in app.session.state.cells: c.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
		app.session.give("wood",2,false,"expand-fixture"); app.render(); await settle()
		var ghosts: Array=interaction().policy.expansions(); check(ghosts.size()==1,"Full raft displays only one expansion ghost")
		var models: Array=interaction().surface.get_children().filter(func(n):return n.name.begins_with("Expansion_"))
		check(models.size()==1 and models[0].global_position.distance_to(interaction().surface.sea_position(ghosts[0]))<.002,"Single blue/red ghost follows local sea level")
		var ghost: Dictionary=ghosts[0]; before=app.session.snapshot()
		await capture("blue-expansion-%d" % roundi(scale_value*100))
		await click(interaction().surface.screen_point(ghost))
		check(app.session.snapshot()==before,"First expansion click only opens cost confirmation")
		var confirm=app.find_child("ConfirmRaftExpansion",true,false)
		check(confirm!=null and not confirm.disabled,"Confirmation offers affordable construction")
		if confirm!=null: await click(confirm.get_global_rect().get_center())
		check(app.session.state.cells.size()==before.state.cells.size()+1,"Second click constructs one real cell")
		check(app.session.I.count(app.session.state,"wood")==app.session.I.count(before.state,"wood")-2 and app.session.state.ap==before.state.ap-1,"Confirmed construction spends wood2/AP1 once")
		for c in app.session.state.cells: c.equipment={"id":"filter","level":1,"fuel":0,"progress":0}
		app.session.state.hand=app.session.state.hand.filter(func(c):return c.id!="wood"); app.render(); await settle()
		await capture("red-expansion-%d" % roundi(scale_value*100))
		ghosts=interaction().policy.expansions()
		if not ghosts.is_empty():
			await click(interaction().surface.screen_point(ghosts[0]))
			confirm=app.find_child("ConfirmRaftExpansion",true,false)
			check(confirm!=null and confirm.disabled,"Unaffordable expansion cannot confirm")
	app.handle_command("abandon"); app.handle_ui("settlement_exit")
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.session.give("filter",2,false,"popup-fixture"); app.session.give("wood",2,false,"popup-fixture"); app.render(); await settle()
	var target_cell: Dictionary=app.session.state.cells[1]
	await click(interaction().surface.screen_point(target_cell))
	var install=app.find_child("RaftAction_install",true,false)
	check(install!=null and not install.disabled,"Empty-cell micro panel offers install")
	check(interaction().popup.size.y<=160,"Single-operation panel stays compact")
	await capture("micro-install")
	if install!=null: await click(install.get_global_rect().get_center())
	check(app.session.state.cells[1].equipment.get("id","")=="filter" and app.session.state.ap==2,"Micro panel installs with real AP/card charge")
	await click(interaction().surface.screen_point(app.session.state.cells[1]))
	var upgrade=app.find_child("RaftAction_upgrade",true,false)
	check(upgrade!=null and not upgrade.disabled,"Installed equipment offers matching upgrade")
	await capture("micro-upgrade")
	if upgrade!=null: await click(upgrade.get_global_rect().get_center())
	check(app.session.state.cells[1].equipment.level==2 and app.session.state.ap==1,"Micro panel upgrade consumes matching equipment/AP")
	app.session.state.cells[1].status="damaged"; app.render(); await settle()
	await click(interaction().surface.screen_point(app.session.state.cells[1]))
	var repair=app.find_child("RaftAction_repair",true,false)
	check(repair!=null and not repair.disabled,"Damaged cell offers repair")
	await capture("micro-repair")
	var wood_before: int=app.session.I.count(app.session.state,"wood")
	if repair!=null: await click(repair.get_global_rect().get_center())
	check(app.session.state.cells[1].status=="intact" and app.session.I.count(app.session.state,"wood")==wood_before-1,"Micro panel repair consumes wood and restores cell")
	app.queue_free(); await settle()
	print("RAFT INTERACTION UI: "+("PASS" if failures==0 else "FAIL")); quit(failures)
