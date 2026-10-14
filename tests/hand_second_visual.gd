extends SceneTree
func _init():call_deferred("run")
func run():
	var app=load("res://scenes/main.tscn").instantiate();app.persistence=false;root.add_child(app);await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	var f=app.session.snapshot()
	for i in range(7):app.session.I.give(f.state,"wood",1,false,"fixture")
	app.session.restore(f);app.handle_command("resume");await process_frame;await process_frame
	var tray=get_nodes_in_group("hand_fans")[0];tray.focus_card(1);await create_timer(.5).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/hand-second-after.png")
	print('TILE',tray.tiles[1].size,' FRAME ',tray.tiles[1].get_child(0).size)
	quit()
