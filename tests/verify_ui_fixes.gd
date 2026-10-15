extends SceneTree
func _init(): call_deferred("run")
func settle():
	await process_frame; await process_frame
func run():
	root.size = Vector2i(1600, 900)
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await settle()
	
	# Start a challenge mode game to get cards and raft
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":22})
	for id in ["wood","wood","wood","wood","plastic","plastic","plastic","cloth","cloth","iron","iron","rope"]:
		app.session.give(id, 1, false, "fixture")
	app.render()
	await settle()
	
	# Scene 1: Hand tray with badge紧贴
	await RenderingServer.frame_post_draw
	var img1 = root.get_texture().get_image()
	img1.save_png("res://evidence/verify_badge_tight.png")
	print("Saved verify_badge_tight.png")
	
	# Scene 2: Click a card (e.g. plastic), ensure right panel does NOT show card details
	var tray_fan = get_nodes_in_group("hand_fans")[0]
	var plastic_card = tray_fan.cards.filter(func(c): return c.id == "plastic")[0]
	tray_fan.activated.emit(plastic_card)
	await settle()
	await RenderingServer.frame_post_draw
	var img2 = root.get_texture().get_image()
	img2.save_png("res://evidence/verify_card_clicked_no_frame.png")
	print("Saved verify_card_clicked_no_frame.png")
	
	# Scene 3: Click a raft cell to show popup without close X button
	var raft_interaction = app.find_child("RaftInteraction", true, false)
	# Target cell 2,2 (cell-3 or target corresponding to 2,2)
	var target_cell = raft_interaction.policy.targets().filter(func(t): return t.get("x", -1) == 1 and t.get("y", -1) == 1)[0]
	raft_interaction.select_target(target_cell)
	await settle()
	await RenderingServer.frame_post_draw
	var img3 = root.get_texture().get_image()
	img3.save_png("res://evidence/verify_cell_popup_no_close.png")
	print("Saved verify_cell_popup_no_close.png")
	
	# Verify assertions
	var badge = app.find_child("HandCapacityBadge", true, false)
	var topbar = app.find_child("VoyageHandTopBar", true, false)
	assert(topbar != null, "Hand area topbar should exist")
	assert(badge != null and badge.get_parent() == topbar, "Badge should be inside topbar")
	
	# Check right frame does not contain card name
	var frame = app.find_child("VoyageOperationFrame", true, false)
	var labels = frame.find_children("*", "Label", true, false)
	var has_card_title = labels.any(func(l): return l.text == "塑料")
	print("Right frame has card title: ", has_card_title)
	assert(not has_card_title, "Right frame must not show card title")
	
	# Check cell popup has no CloseX
	var cell_popup = raft_interaction.popup
	assert(cell_popup != null, "Cell popup should be open")
	var close_button = cell_popup.find_child("CloseX", true, false)
	print("Cell popup has CloseX: ", close_button != null)
	assert(close_button == null, "Cell popup must not have CloseX button")
	
	print("ALL THREE VERIFICATIONS PASSED!")
	app.queue_free()
	quit(0)
