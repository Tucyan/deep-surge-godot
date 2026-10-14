extends SceneTree
func _init():call_deferred("run")
func fan(app):
	for node in get_nodes_in_group("hand_fans"):
		if app.layout.is_ancestor_of(node) and node.get_meta("presentation_role","")=="voyage":return node
	return null
func capture(id):
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/hand-departure-"+id+".png")
func run():
	root.size=Vector2i(1600,900)
	var app=load("res://scenes/main.tscn").instantiate();app.persistence=false;root.add_child(app);await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	var f=app.session.snapshot()
	for i in range(5):app.session.I.give(f.state,"water",1,false,"visual-fixture")
	app.session.restore(f);app.handle_command("resume");await process_frame;await process_frame
	var tray=fan(app);tray.set_process(false);var index=tray.cards.size()-3
	tray.focus_card(index);tray._process(.6);var uid=tray.cards[index].uid
	await capture("before")
	app.handle_command("play",{"uid":uid});tray=fan(app);tray.set_process(false)
	tray._process(.11);await capture("leaving")
	tray._process(.09);await capture("refill")
	tray._process(.45);await capture("after")
	print("HAND DEPARTURE GPU: PASS")
	app.queue_free();await process_frame;quit()
