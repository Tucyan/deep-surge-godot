extends SceneTree
func _init(): call_deferred("run")
func run():
	root.size=Vector2i(1280,720)
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame; await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.handle_command("enter")
	await create_timer(0.3).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/node-event-embedded.png")
	print("PHASE ",app.session.phase()," ERROR ",app.message)
	app.handle_command("skip")
	await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/node-event-choices.png")
	print("CHOICES ",app.session.state.story_step)
	quit()
