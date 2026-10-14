extends SceneTree
func _init(): call_deferred("run")
func capture(id):
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/hand-"+id+".png")
func run():
	root.size = Vector2i(1600,900)
	var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.world_view.motion = false
	await capture("normal")
	var fixture = app.session.snapshot()
	for i in range(14): app.session.I.give(fixture.state,"wood",1,false,"hand-visual-fixture")
	app.session.restore(fixture); app.handle_command("resume"); await process_frame; await process_frame
	var tray = get_nodes_in_group("hand_fans")[0]
	await capture("many")
	var motion = InputEventMouseMotion.new(); motion.position = Vector2(tray.size.x*0.5,150); tray._gui_input(motion)
	await create_timer(0.45).timeout
	await capture("hover")
	root.size = Vector2i(1280,720); await process_frame; await process_frame; tray.focus_card(tray.cards.size()-1); tray.show_description()
	await capture("1280")
	# Battle UI fixture: exercise narrow modal and disabled AP interaction.
	app.session.state.phase = "story"; app.session.state.story_step = "choice"; app.session.state.node.monster = "biter"
	app.session.Battle.enter(app.session)
	for i in range(12): app.session.I.give(app.session.state,"punch",1,true,"battle-hand-visual-fixture")
	app.render(); await process_frame; await process_frame
	var battle_tray = get_nodes_in_group("hand_fans").back()
	battle_tray.focus_card(5); battle_tray.show_description()
	await capture("battle-1280")
	app.queue_free(); await process_frame; quit()
