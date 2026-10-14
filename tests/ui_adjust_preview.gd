extends SceneTree
var app
func _init(): call_deferred("run")
func settle():
	await process_frame; await process_frame
func run():
	root.size = Vector2i(1600,900)
	app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await settle()
	app.handle_command("new",{"mode":"story","origin":"fool","seed":22})
	await settle()
	var fixture: Dictionary = app.session.snapshot()
	for i in range(8):
		app.session.I.give(fixture.state,"wood",1,false,"fixture")
	fixture.state.phase = "discard"
	app.session.restore(fixture)
	app.handle_command("resume")
	await settle(); await RenderingServer.frame_post_draw
	var img_discard_1600 = root.get_texture().get_image()
	img_discard_1600.save_png("res://evidence/ui-adjust-discard-1600.png")

	root.size = Vector2i(1280,720); await settle(); await RenderingServer.frame_post_draw
	var img_discard_1280 = root.get_texture().get_image()
	img_discard_1280.save_png("res://evidence/ui-adjust-discard-1280.png")

	root.size = Vector2i(1600,900); await settle()
	app.queue_free(); await process_frame
	app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app); await settle()
	app.handle_command("new",{"mode":"story","origin":"fool","seed":22}); await settle()
	await settle(); await RenderingServer.frame_post_draw
	var img_nav = root.get_texture().get_image()
	img_nav.save_png("res://evidence/ui-adjust-navigation-1600.png")

	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id}); await settle()
	# Now in preparation phase
	await settle(); await RenderingServer.frame_post_draw
	var img_prep = root.get_texture().get_image()
	img_prep.save_png("res://evidence/ui-adjust-preparation-1600.png")

	print("ALL PREVIEWS SAVED SUCCESSFULLY")
	quit(0)
