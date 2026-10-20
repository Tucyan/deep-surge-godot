extends SceneTree

var failures := 0

func _init(): call_deferred("run")

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + why)

func touch(position: Vector2, pressed: bool, index: int = 0, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	event.index = index
	event.canceled = canceled
	root.push_input(event,true)

func drag(position: Vector2, relative: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = position
	event.relative = relative
	event.index = index
	root.push_input(event,true)

func run() -> void:
	root.size = Vector2i(1280,720)
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	app.display_settings.mobile = true
	root.add_child(app)
	await process_frame
	await process_frame
	# Added after the initial render, like lazy settings tabs and modal details.
	var scroll := ScrollContainer.new()
	scroll.z_index = 100
	scroll.position = Vector2(20,20)
	scroll.size = Vector2(340,220)
	scroll.scale = Vector2(1.25,1.25)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	app.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var clicks := []
	for i in range(20):
		var button := Button.new()
		button.text = "条目 %d" % i
		button.custom_minimum_size.y = 60
		button.pressed.connect(func(): clicks.append(true))
		column.add_child(button)
	await process_frame
	await process_frame
	await process_frame
	check(not scroll.get_v_scroll_bar().visible,"mobile overflow scrollbar is hidden")
	check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,"overflow keeps a usable scroll range")
	check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,"disabled axes remain disabled")
	var start: Vector2 = column.get_child(0).get_global_rect().get_center()
	touch(start,true)
	await process_frame
	drag(start-Vector2(0,35),Vector2(0,-35))
	await process_frame
	drag(start-Vector2(0,90),Vector2(0,-55))
	await process_frame
	touch(start-Vector2(0,90),false)
	await process_frame
	check(scroll.scroll_vertical > 0,"swiping over a button scrolls content")
	check(scroll.scroll_vertical == 72,"drag distance follows 125 percent UI scaling")
	check(clicks.is_empty(),"scrolling does not activate a button")
	scroll.scroll_vertical = 0
	await process_frame
	start = column.get_child(0).get_global_rect().get_center()
	touch(start,true)
	await process_frame
	touch(start,false)
	await process_frame
	check(clicks.size() == 1,"a tap still activates the button once")
	start = column.get_child(0).get_global_rect().get_center()
	touch(start,true)
	await process_frame
	drag(start-Vector2(0,70),Vector2(0,-70),1)
	await process_frame
	check(scroll.scroll_vertical == 0,"another finger cannot move the active scroll")
	drag(start-Vector2(0,70),Vector2(0,-70))
	await process_frame
	touch(start-Vector2(0,70),false,0,true)
	await process_frame
	check(clicks.size() == 1,"a canceled swipe never activates content")
	scroll.scroll_vertical = 0
	await process_frame
	drag(start,Vector2(0,-90))
	await process_frame
	check(scroll.scroll_vertical == 0,"cancellation releases gesture ownership")
	# The same policy supports horizontal content without enabling disabled axes.
	var sideways := ScrollContainer.new()
	sideways.z_index = 100
	sideways.position = Vector2(400,20)
	sideways.size = Vector2(200,120)
	sideways.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	app.add_child(sideways)
	var wide := Control.new()
	wide.custom_minimum_size = Vector2(800,100)
	sideways.add_child(wide)
	await process_frame
	await process_frame
	check(not sideways.get_h_scroll_bar().visible,"horizontal mobile scrollbar is hidden")
	var side_start := sideways.get_global_rect().get_center()
	touch(side_start,true)
	await process_frame
	drag(side_start-Vector2(80,0),Vector2(-80,0))
	await process_frame
	touch(side_start-Vector2(80,0),false)
	await process_frame
	check(sideways.scroll_horizontal > 0 and sideways.scroll_vertical == 0,"horizontal swipe respects the disabled vertical axis")
	sideways.free()
	scroll.free()
	app.settings_tab = "game"
	app.handle_ui("local_panel","settings")
	await process_frame
	await process_frame
	var settings_scroll = app.find_child("MobileSettingsScroll",true,false)
	check(settings_scroll != null and not settings_scroll.get_v_scroll_bar().visible,"real settings page applies the mobile policy")
	var lazy_button = app.find_child("TabDisplay",true,false)
	lazy_button.pressed.emit()
	await process_frame
	await process_frame
	for item in app.find_children("*","ScrollContainer",true,false):
		check(not item.get_v_scroll_bar().visible and not item.get_h_scroll_bar().visible,"lazy modal content hides both scrollbars")
	app.display_settings.mobile = false
	var desktop := ScrollContainer.new()
	desktop.z_index = 100
	desktop.position = Vector2(400,20)
	desktop.size = Vector2(200,120)
	app.add_child(desktop)
	var content := Control.new()
	content.custom_minimum_size = Vector2(500,500)
	desktop.add_child(content)
	await process_frame
	await process_frame
	check(desktop.get_v_scroll_bar().visible and desktop.get_h_scroll_bar().visible,"desktop scrollbars remain visible")
	var wheel := InputEventMouseButton.new()
	wheel.position = desktop.get_global_rect().get_center()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel,true)
	await process_frame
	check(desktop.scroll_vertical > 0,"desktop wheel scrolling still works")
	app.free()
	print("MOBILE SCROLL: " + ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(1 if failures else 0)
