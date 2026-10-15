extends SceneTree

func settle():
	await process_frame; await process_frame; await process_frame

func _init():
	call_deferred("run")

func run():
	root.size = Vector2i(1600, 900)
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await settle()
	
	print("--- 1. Testing Settings from Home / Title Screen ---")
	var home_settings_btn = app.find_child("HomeSettings", true, false)
	assert(home_settings_btn != null, "HomeSettings button must exist on title screen")
	home_settings_btn.pressed.emit()
	await settle()
	
	assert(app.local_panel == "settings", "Local panel must be 'settings'")
	var tab_bar = app.find_child("SettingsTabBar", true, false)
	assert(tab_bar != null, "SettingsTabBar must exist")
	
	var tab_display: Button = app.find_child("TabDisplay", true, false)
	var tab_game: Button = app.find_child("TabGame", true, false)
	assert(tab_display != null and tab_game != null, "Both TabDisplay and TabGame buttons must exist")
	
	var display_box = app.find_child("DisplayTabContent", true, false)
	var game_box = app.find_child("GameTabContent", true, false)
	assert(display_box.visible == true, "Display tab must be visible by default")
	assert(game_box.visible == false, "Game tab must be hidden by default")
	
	# Verify that in Home screen, VoyageControlPanel does NOT show return home button
	var home_btn = app.find_child("SettingsHomeButton", true, false)
	assert(home_btn == null, "Home screen settings must not show '返回首页'")
	
	await RenderingServer.frame_post_draw
	var img1 = root.get_texture().get_image()
	img1.save_png("res://evidence/settings_redesign_home_display.png")
	print("Saved evidence/settings_redesign_home_display.png")
	
	# Close settings
	var close_btn = app.find_child("ModalSurface", true, false).find_child("CloseX", true, false)
	close_btn.pressed.emit()
	await settle()
	assert(app.local_panel == "", "Settings modal must be closed")
	
	print("\n--- 2. Testing Settings In-Game with Voyage Management ---")
	app.handle_command("new", {"mode":"challenge", "origin":"strong", "seed":42})
	await settle()
	
	app.handle_ui("local_panel", "settings")
	await settle()
	
	tab_display = app.find_child("TabDisplay", true, false)
	tab_game = app.find_child("TabGame", true, false)
	display_box = app.find_child("DisplayTabContent", true, false)
	game_box = app.find_child("GameTabContent", true, false)
	
	# In-game checks
	var voyage_panel = app.find_child("VoyageControlPanel", true, false)
	assert(voyage_panel != null, "VoyageControlPanel must exist when in-game")
	home_btn = app.find_child("SettingsHomeButton", true, false)
	var abandon_btn = app.find_child("SettingsAbandonButton", true, false)
	assert(home_btn != null and home_btn.text == "返回首页", "SettingsHomeButton must exist in-game")
	assert(abandon_btn != null and abandon_btn.text == "放弃本局", "SettingsAbandonButton must exist in-game")
	
	# Assert controls inside Display Tab
	assert(app.find_child("UIScale", true, false) != null, "UIScale slider must exist")
	assert(app.find_child("FrameRateLimit", true, false) != null, "FrameRateLimit must exist")
	assert(app.find_child("DesktopResolution", true, false) != null, "DesktopResolution must exist on desktop")
	assert(app.find_child("DesktopFullscreen", true, false) != null, "DesktopFullscreen must exist on desktop")
	assert(app.find_child("MotionToggle", true, false) != null, "MotionToggle must exist in Display tab")
	
	await RenderingServer.frame_post_draw
	var img2 = root.get_texture().get_image()
	img2.save_png("res://evidence/settings_redesign_ingame_display.png")
	print("Saved evidence/settings_redesign_ingame_display.png")
	
	print("\n--- 3. Testing Instant Tab Switching without Full-App Reload ---")
	var old_modal_id = app.find_child("ModalSurface", true, false).get_instance_id()
	
	# Click TabGame
	tab_game.pressed.emit()
	await settle()
	
	var new_modal_id = app.find_child("ModalSurface", true, false).get_instance_id()
	assert(old_modal_id == new_modal_id, "Tab switching must NOT rebuild modal surface (instant toggle)!")
	assert(display_box.visible == false, "Display tab must now be hidden")
	assert(game_box.visible == true, "Game tab must now be visible")
	assert(app.settings_tab == "game", "app.settings_tab must be updated to 'game'")
	
	# Assert controls inside Game Tab
	assert(app.find_child("auto_sort", true, false) != null, "auto_sort toggle must exist")
	assert(app.find_child("stack_resources", true, false) != null, "stack_resources toggle must exist")
	
	await RenderingServer.frame_post_draw
	var img3 = root.get_texture().get_image()
	img3.save_png("res://evidence/settings_redesign_ingame_game.png")
	print("Saved evidence/settings_redesign_ingame_game.png")
	
	# Switch back to Display tab
	tab_display.pressed.emit()
	await settle()
	assert(display_box.visible == true, "Display tab must be visible again")
	assert(game_box.visible == false, "Game tab must be hidden again")
	assert(app.settings_tab == "display", "app.settings_tab must be updated to 'display'")
	
	print("\nALL SETTINGS MENU REDESIGN VERIFICATIONS PASSED SUCCESSFULLY!")
	quit(0)
