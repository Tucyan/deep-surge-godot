extends RefCounted
const W = preload("res://presentation/widgets.gd")
const Display = preload("res://presentation/display_settings.gd")
const NarrativeMenu = preload("res://pages/narrative_menu.gd")

static func build(parent: Node, app: Control, view: Dictionary) -> void:
	var prefs = app.display_settings
	var compact := app.size.y<780
	if compact: parent.add_theme_constant_override("separation",6)
	var current_tab: String = app.settings_tab if app.settings_tab in ["display", "game", "narrative"] else "display"

	# Subtitle / context description
	var subtitle := Label.new()
	subtitle.text = "D E E P   S U R G E  ·  系统选项与运行偏好"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("8ca1b0"))
	parent.add_child(subtitle)

	# 1. Tab Navigation Bar (Segmented Control with Highlight)
	var tab_bar := HBoxContainer.new()
	tab_bar.name = "SettingsTabBar"
	tab_bar.add_theme_constant_override("separation", 8)
	parent.add_child(tab_bar)

	var tab_display := Button.new()
	tab_display.name = "TabDisplay"
	tab_display.text = "画面显示"
	tab_display.custom_minimum_size = Vector2(0, 36)
	tab_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.add_child(tab_display)
	W.TextButtonArt.apply(tab_display)

	var tab_game := Button.new()
	tab_game.name = "TabGame"
	tab_game.text = "游戏偏好"
	tab_game.custom_minimum_size = Vector2(0, 36)
	tab_game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.add_child(tab_game)
	W.TextButtonArt.apply(tab_game)

	var tab_narrative := Button.new()
	tab_narrative.name = "TabNarrative"
	tab_narrative.text = "剧情"
	tab_narrative.custom_minimum_size = Vector2(0, 36)
	tab_narrative.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.add_child(tab_narrative)
	W.TextButtonArt.apply(tab_narrative)

	# 2. Tab Content Containers
	var content_area := VBoxContainer.new()
	content_area.name = "SettingsContentArea"
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.add_theme_constant_override("separation", 6)
	parent.add_child(content_area)

	var display_box := VBoxContainer.new()
	display_box.name = "DisplayTabContent"
	display_box.add_theme_constant_override("separation", 6)
	content_area.add_child(display_box)

	var game_box := VBoxContainer.new()
	game_box.name = "GameTabContent"
	game_box.add_theme_constant_override("separation", 4 if compact else 6)
	content_area.add_child(game_box)

	var narrative_box := VBoxContainer.new()
	narrative_box.name = "NarrativeTabContent"
	narrative_box.add_theme_constant_override("separation", 4 if compact else 6)
	content_area.add_child(narrative_box)
	NarrativeMenu.build_settings(narrative_box, app)

	# --- TAB 1: 画面显示 ---
	# Row 1: UI 缩放
	var scale_row := HBoxContainer.new()
	scale_row.alignment = BoxContainer.ALIGNMENT_END
	scale_row.add_theme_constant_override("separation", 8)

	var scale_label := Label.new()
	scale_label.name = "UIScaleValue"
	scale_label.text = "%d%%" % roundi(prefs.ui_scale * 100)
	scale_label.custom_minimum_size.x = 44
	scale_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scale_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scale_label.add_theme_font_size_override("font_size", 14)
	scale_label.add_theme_color_override("font_color", W.GOLD)
	scale_row.add_child(scale_label)

	var slider := HSlider.new()
	slider.name = "UIScale"
	slider.custom_minimum_size = Vector2(140, 32)
	slider.min_value = 100; slider.max_value = 125; slider.step = 1; slider.value = prefs.ui_scale * 100
	slider.accessibility_name = "UI 大小百分比"
	slider.drag_started.connect(func(): slider.set_meta("dragging", true))
	slider.value_changed.connect(func(val):
		scale_label.text = "%d%%" % roundi(val)
		if not slider.get_meta("dragging", false):
			prefs.ui_scale = val / 100.0
			app.apply_display_settings.call_deferred(false)
	)
	slider.drag_ended.connect(func(changed):
		slider.set_meta("dragging", false)
		if changed:
			prefs.ui_scale = slider.value / 100.0
			app.apply_display_settings.call_deferred(false)
	)
	scale_row.add_child(slider)
	display_box.add_child(make_row("界面缩放 (UI Scale)", "调整文字、卡牌与界面大小（100% ~ 125%）", scale_row, 195))

	# Row 2: 帧率限制
	var fps := OptionButton.new()
	fps.name = "FrameRateLimit"
	fps.custom_minimum_size = Vector2(160, 32)
	fps.accessibility_name = "帧率上限"
	for limit in Display.FRAME_RATES:
		fps.add_item("无限制" if limit == 0 else "%d FPS" % limit)
	fps.select(Display.FRAME_RATES.find(prefs.fps_limit))
	fps.item_selected.connect(func(idx):
		prefs.fps_limit = Display.FRAME_RATES[idx]
		app.apply_display_settings.call_deferred(false)
	)
	display_box.add_child(make_row("帧率限制 (FPS Cap)", "限制游戏最大渲染帧率，降低功耗与发热", fps, 160))

	# 比例和清晰度分别控制画布与渲染精度。
	var aspect := OptionButton.new()
	aspect.name="AspectRatio"
	aspect.add_item("16:9")
	aspect.add_item("自由比例")
	aspect.select(1 if prefs.free_aspect else 0)
	aspect.item_selected.connect(func(idx):
		prefs.free_aspect=idx==1
		app.apply_display_settings.call_deferred(false))
	display_box.add_child(make_row("画面比例", "自由比例跟随横屏窗口或屏幕（3:2～21:9）", aspect, 160))
	# Row 3: 分辨率 (桌面) / 画面质量 (移动端)
	if prefs.mobile:
		var quality := OptionButton.new()
		quality.name = "MobileQuality"
		quality.custom_minimum_size = Vector2(160, 32)
		for label in Display.CLARITY_NAMES: quality.add_item(label)
		quality.select(prefs.quality)
		quality.item_selected.connect(func(idx):
			prefs.quality = idx
			app.apply_display_settings.call_deferred(false)
		)
		display_box.add_child(make_row("画面清晰度 (Quality)", "调整海面与场景渲染质量，文字与UI保持清晰", quality, 160))
	else:
		var resolution := OptionButton.new()
		resolution.name = "DesktopResolution"
		resolution.custom_minimum_size = Vector2(160, 32)
		for label in Display.CLARITY_NAMES:
			resolution.add_item(label)
		resolution.select(Display.RESOLUTIONS.find(prefs.resolution))
		resolution.item_selected.connect(func(idx):
			prefs.resolution = Display.RESOLUTIONS[idx]
			app.apply_display_settings.call_deferred()
		)
		display_box.add_child(make_row("分辨率 (Resolution)", "固定比例调整窗口大小；自由比例与全屏调整场景精度", resolution, 160))

		# Row 4: 全屏显示 (桌面)
		var fullscreen := CheckButton.new()
		fullscreen.name = "DesktopFullscreen"
		fullscreen.text = "开启全屏"
		fullscreen.button_pressed = prefs.fullscreen
		fullscreen.toggled.connect(func(enabled):
			prefs.fullscreen = enabled
			app.apply_display_settings.call_deferred()
		)
		display_box.add_child(make_row("全屏显示 (Fullscreen)", "在全屏模式与窗口化模式之间切换", fullscreen, 130))

	# Row 5: 海面与木筏动态 (归类到画面显示)
	var toggle := CheckButton.new()
	toggle.name = "MotionToggle"
	toggle.text = "波浪起伏"
	toggle.button_pressed = prefs.motion
	toggle.toggled.connect(func(enabled):
		prefs.motion = enabled
		app.apply_display_settings.call_deferred(false)
	)
	display_box.add_child(make_row("海面与木筏动效 (Motion)", "开启后海面波浪与木筏随潮晃动；关闭可提升性能", toggle, 130))
	var camera_row:=HBoxContainer.new()
	var view_lock:=CheckButton.new(); view_lock.name="ViewLockToggle"; view_lock.text="锁定视角"
	view_lock.button_pressed=prefs.view_locked; camera_row.add_child(view_lock)
	view_lock.toggled.connect(func(enabled):
		prefs.view_locked=enabled; app.apply_display_settings.call_deferred(false))
	var camera_reset:=W.button(camera_row,"复位",func():app.world_view.reset_camera_view())
	camera_reset.name="SettingsResetRaftView"
	W.UtilityButtonArt.apply(camera_reset, "reset", false)
	game_box.add_child(make_row("视角锁定",prefs.camera_help(),camera_row,210))
	var mouse_bindings:=HBoxContainer.new()
	for action in ["orbit","pan"]:
		var column:=VBoxContainer.new(); mouse_bindings.add_child(column)
		W.text(column,"旋转" if action=="orbit" else "平移",12,W.MUTED)
		var picker:=OptionButton.new(); column.add_child(picker)
		picker.name="CameraOrbitBinding" if action=="orbit" else "CameraPanBinding"
		for button in Display.CAMERA_MOUSE_BUTTONS: picker.add_item(Display.mouse_button_name(button),button)
		picker.select(Display.CAMERA_MOUSE_BUTTONS.find(prefs.camera_orbit_button if action=="orbit" else prefs.camera_pan_button))
		picker.item_selected.connect(func(index):
			prefs.set_camera_mouse_binding(action,Display.CAMERA_MOUSE_BUTTONS[index]); app.apply_display_settings.call_deferred(false))
	game_box.add_child(make_row("视角鼠标按键","同键自动互换；左键单击仍可操作筏格",mouse_bindings,210))
	var reset_keys:=HBoxContainer.new()
	var reset_key:=W.button(reset_keys,OS.get_keycode_string(prefs.camera_reset_key),func():
		app.camera_binding_capture=true
		var button=app.find_child("CameraResetBinding",true,false)
		if button!=null: button.text="按下新键…")
	reset_key.name="CameraResetBinding"; reset_key.custom_minimum_size.x=110
	var defaults:=W.button(reset_keys,"恢复默认",func():
		prefs.reset_camera_bindings(); app.apply_display_settings.call_deferred(false))
	defaults.name="CameraBindingDefaults"
	game_box.add_child(make_row("视角复位快捷键","点击后按字母、数字或F键；Esc取消",reset_keys,210))

	# --- TAB 2: 游戏偏好 ---
	# Row 1: 自动理牌
	var opt_sort := CheckButton.new()
	opt_sort.name = "auto_sort"
	opt_sort.text = "自动理牌"
	opt_sort.button_pressed = app.hand_layout.auto_sort
	opt_sort.toggled.connect(func(enabled):
		app.hand_layout.auto_sort = enabled
		if enabled:
			app.hand_layout.order.clear()
		if app.persistence and app.hand_layout.save_preferences() != OK:
			app.message = "手牌设置保存失败"
		app.render.call_deferred()
	)
	game_box.add_child(make_row("自动理牌 (Auto-Sort)", "抽牌与整理时按卡牌类型与稀有度自动排序手牌", opt_sort, 130))

	# Row 2: 资源叠牌
	var opt_stack := CheckButton.new()
	opt_stack.name = "stack_resources"
	opt_stack.text = "叠牌合并"
	opt_stack.button_pressed = app.hand_layout.stack_resources
	opt_stack.toggled.connect(func(enabled):
		app.hand_layout.stack_resources = enabled
		if app.persistence and app.hand_layout.save_preferences() != OK:
			app.message = "手牌设置保存失败"
		app.render.call_deferred()
	)
	game_box.add_child(make_row("资源合并显示 (叠牌)", "同种基础资源达到 4 张时自动合并为单格显示，减少拥挤", opt_stack, 130))

	var hover_picker := OptionButton.new(); hover_picker.name="HandHoverMode"
	hover_picker.add_item("排开遮挡"); hover_picker.add_item("图层上浮")
	hover_picker.select(app.hand_layout.HOVER_MODES.find(app.hand_layout.hover_mode))
	hover_picker.item_selected.connect(func(index):
		app.hand_layout.hover_mode=app.hand_layout.HOVER_MODES[index]
		if app.persistence and app.hand_layout.save_preferences()!=OK: app.message="手牌设置保存失败"
		app.render.call_deferred())
	game_box.add_child(make_row("手牌悬停方式","排开遮挡：让右侧牌让位；图层上浮：仅将主卡显示到上层",hover_picker,150))

	# Row 3: 游戏操作与手势提示卡片
	var tip_card := PanelContainer.new()
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.02, 0.045, 0.075, 0.7)
	tip_style.border_color = Color(0.3, 0.42, 0.52, 0.35)
	tip_style.set_border_width_all(1)
	tip_style.set_corner_radius_all(4)
	tip_style.content_margin_left = 14; tip_style.content_margin_right = 14
	tip_style.content_margin_top = 8; tip_style.content_margin_bottom = 8
	tip_card.add_theme_stylebox_override("panel", tip_style)

	var tip_vbox := VBoxContainer.new()
	tip_vbox.add_theme_constant_override("separation", 3)
	tip_card.add_child(tip_vbox)

	var tip_title := Label.new()
	tip_title.text = "💡 操作与手势提示"
	tip_title.add_theme_font_size_override("font_size", 14)
	tip_title.add_theme_color_override("font_color", W.GOLD)
	tip_vbox.add_child(tip_title)

	var tip_body := Label.new()
	tip_body.text = "· 手牌长按 0.2 秒后可自由拖动排序；调整后将保存用户排序，新抽卡牌仍按自动理牌归类。\n· 双击手牌中的装备卡可自动安装到木筏空格，合并升级需 1 AP。\n· 战斗中双击最右侧的「攻击」或「防御」卡牌可直接以当前组合快速迎击。"
	tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_body.add_theme_font_size_override("font_size", 12)
	tip_body.add_theme_color_override("font_color", Color("9ab0be"))
	tip_vbox.add_child(tip_body)
	game_box.add_child(tip_card)
	if compact:
		for row in game_box.get_children():
			if not row is PanelContainer: continue
			var style: StyleBoxFlat=row.get_theme_stylebox("panel").duplicate()
			style.content_margin_top=maxf(4,style.content_margin_top-2)
			style.content_margin_bottom=maxf(4,style.content_margin_bottom-2)
			row.add_theme_stylebox_override("panel",style)

	# --- Tab Switching Behavior (Instant, No Full Screen Reload) ---
	var update_tabs = func(target: String):
		app.settings_tab = target
		display_box.visible = (target == "display")
		game_box.visible = (target == "game")
		narrative_box.visible = (target == "narrative")

		tab_display.set_meta("surge_primary", target == "display")
		tab_game.set_meta("surge_primary", target == "game")
		tab_narrative.set_meta("surge_primary", target == "narrative")
		tab_display.queue_redraw(); tab_game.queue_redraw(); tab_narrative.queue_redraw()
		tab_display.add_theme_color_override("font_color", Color("fff8e9") if target == "display" else Color("8ca1b0"))
		tab_game.add_theme_color_override("font_color", Color("fff8e9") if target == "game" else Color("8ca1b0"))
		tab_narrative.add_theme_color_override("font_color", Color("fff8e9") if target == "narrative" else Color("8ca1b0"))

	tab_display.pressed.connect(func(): update_tabs.call("display"))
	tab_game.pressed.connect(func(): update_tabs.call("game"))
	tab_narrative.pressed.connect(func(): update_tabs.call("narrative"))
	update_tabs.call(current_tab)

	# --- Bottom Section: 航程管理 (Voyage Actions) ---
	if view.screen == "game" or view.active:
		var voyage_panel := PanelContainer.new()
		voyage_panel.name = "VoyageControlPanel"
		voyage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vp_style := StyleBoxFlat.new()
		vp_style.bg_color = Color(0.02, 0.04, 0.065, 0.8)
		vp_style.border_color = Color(0.55, 0.45, 0.3, 0.45)
		vp_style.set_border_width_all(1)
		vp_style.set_corner_radius_all(4)
		vp_style.content_margin_left = 12; vp_style.content_margin_right = 12
		vp_style.content_margin_top = 8; vp_style.content_margin_bottom = 8
		voyage_panel.add_theme_stylebox_override("panel", vp_style)
		parent.add_child(voyage_panel)

		var vp_vbox := VBoxContainer.new()
		vp_vbox.add_theme_constant_override("separation", 6)
		voyage_panel.add_child(vp_vbox)

		var vp_header := HBoxContainer.new()
		vp_vbox.add_child(vp_header)
		var vp_title := Label.new()
		vp_title.text = "◆ 航程管理 ◆"
		vp_title.add_theme_font_size_override("font_size", 13)
		vp_title.add_theme_color_override("font_color", W.GOLD)
		vp_header.add_child(vp_title)

		var vp_hint := Label.new()
		vp_hint.text = "当前航行中，可安全暂停返回主页，或放弃航程结算"
		vp_hint.add_theme_font_size_override("font_size", 12)
		vp_hint.add_theme_color_override("font_color", Color("8ca1b0"))
		vp_header.add_child(vp_hint)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 10)
		vp_vbox.add_child(btn_row)

		if view.screen == "game":
			var home_btn := Button.new()
			home_btn.text = "返回首页"
			home_btn.name = "SettingsHomeButton"
			home_btn.tooltip_text = "安全保存当前航程进度，返回游戏主菜单"
			home_btn.custom_minimum_size.y = 36
			home_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			home_btn.pressed.connect(func(): app.handle_command("home"))
			btn_row.add_child(home_btn)
			W.TextButtonArt.apply(home_btn)

		if view.active:
			var abandon_btn := Button.new()
			abandon_btn.text = "放弃本局"
			abandon_btn.name = "SettingsAbandonButton"
			abandon_btn.tooltip_text = "放弃当前航行并按已完成节点进行结算"
			abandon_btn.custom_minimum_size.y = 36
			abandon_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			abandon_btn.pressed.connect(func(): app.confirm_abandon())
			btn_row.add_child(abandon_btn)
			W.TextButtonArt.apply(abandon_btn)
			abandon_btn.set_meta("surge_danger", true)
			abandon_btn.add_theme_color_override("font_color", Color("f09d92"))

static func make_row(title_text: String, hint_text: String, control: Control, control_width: float = 160.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.02, 0.045, 0.07, 0.65)
	p_style.border_color = Color(0.22, 0.32, 0.42, 0.35)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(3)
	p_style.content_margin_left = 12
	p_style.content_margin_right = 12
	p_style.content_margin_top = 6
	p_style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", p_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(left_vbox)

	var t_lbl := Label.new()
	t_lbl.text = title_text
	t_lbl.add_theme_font_size_override("font_size", 15)
	t_lbl.add_theme_color_override("font_color", Color("eee3cd"))
	left_vbox.add_child(t_lbl)

	if hint_text != "":
		var h_lbl := Label.new()
		h_lbl.text = hint_text
		h_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h_lbl.add_theme_font_size_override("font_size", 12)
		h_lbl.add_theme_color_override("font_color", Color("8ca1b0"))
		left_vbox.add_child(h_lbl)

	if control != null:
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if control_width > 0:
			control.custom_minimum_size.x = control_width
		hbox.add_child(control)

	return panel
