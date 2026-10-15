extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures += 1; printerr(message)
func run():
	var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
	app.hand_layout.stack_resources=false; app.hand_layout.auto_sort=false
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	var fixture = app.session.snapshot()
	for i in range(18): app.session.I.give(fixture.state,"wood",1,false,"hand-ui-fixture")
	app.session.restore(fixture); app.handle_command("resume"); await process_frame; await process_frame
	var trays = get_nodes_in_group("hand_fans")
	check(trays.size() == 1,"All hand cards require one continuous fan")
	if not trays.is_empty():
		var tray = trays[0]; var saved = app.session.snapshot()
		check(tray.cards.size() == app.session.view().hand.size(),"No hand pagination")
		# Regression: hovering only moves a few nearby cards.
		var start: Vector2 = tray.tiles[1].position
		tray.focus_card(1)
		var target: Vector2 = tray.target_positions[1]
		check(tray.tiles[1].position == start,"Hover must not teleport card")
		for i in range(4,tray.cards.size()):
			check(is_equal_approx(tray.target_positions[i].x,tray.base_x[i]),"Distant cards remain anchored")
		var spacing: float = tray.base_x[1]-tray.base_x[0]
		check(absf(tray.target_positions[0].x-tray.base_x[0])<=maxf(0,tray.card_width-spacing)+.1,"Neighbour only clears actual overlap")
		if spacing*2 >= tray.card_width:
			check(is_equal_approx(tray.target_positions[3].x,tray.base_x[3]),"Unobstructing second neighbour remains still")
		tray._process(.04)
		check(tray.tiles[1].position != start and tray.tiles[1].position != target,"Card passes through intermediate animation position")
		tray._process(.6)
		check(tray.tiles[1].position.distance_to(target)<.2,"Movement settles at layout target")
		var raised: Vector2 = tray.tiles[1].position
		tray.focus_card(-1)
		check(tray.tiles[1].position == raised,"Return also animates without teleport")
		tray._process(.6)
		for resolution in [Vector2i(1600,900),Vector2i(1280,720)]:
			root.size = resolution; await process_frame; await process_frame
			for index in [0,12,tray.cards.size()-1]:
				tray.focus_card(index); tray.show_description()
				await process_frame
				check(tray.tip.visible and tray.tip_text.text.contains(tray.cards[index].definition.description),"Hover description")
				check(app.get_global_rect().grow(2).encloses(tray.tip.get_global_rect()),"Tooltip in viewport %s %s" % [tray.tip.get_global_rect(),app.get_global_rect()])
				for tile in tray.tiles: check(app.get_global_rect().grow(2).encloses(tile.get_global_rect()),"All cards within viewport")
		var sparse = load("res://presentation/hand_fan.gd").new(); root.add_child(sparse)
		var sparse_view: Dictionary=app.session.view(); sparse_view.hand_layout=app.hand_layout
		sparse.size = Vector2(800,250); sparse.create(app.assets,tray.cards.slice(0,4),sparse_view)
		await process_frame; sparse.focus_card(1)
		for i in range(4): check(is_equal_approx(sparse.target_positions[i].x,sparse.base_x[i]),"Few cards do not shift horizontally")
		check(sparse.target_positions[1].y<sparse.target_positions[0].y,"Sparse hover only raises selected card")
		sparse.queue_free()
		check(app.session.snapshot() == saved,"Hover must not mutate game or RNG")
		var expected: String = tray.cards.back().uid
		var point: Vector2 = tray.tiles.back().global_position+Vector2(30,70)
		var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point
		root.push_input(motion,true); await process_frame
		check(tray.hovered == tray.cards.size()-1,"Real pointer routes to last card")
		var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = point; click.global_position = point
		root.push_input(click,true); await process_frame
		click.pressed=false; root.push_input(click,true); await process_frame
		check(app.ui_state.card == expected,"Click selects correct UID after spreading")
		check(app.session.snapshot() == saved,"Inspect material does not consume it")
	app.queue_free(); await process_frame
	print("HAND FAN: PASS" if failures == 0 else "HAND FAN: FAIL")
	quit(failures)
