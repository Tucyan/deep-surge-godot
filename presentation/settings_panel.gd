extends RefCounted
const W = preload("res://presentation/widgets.gd")
const Display = preload("res://presentation/display_settings.gd")

static func build(parent: Node, app: Control, view: Dictionary) -> void:
	var prefs=app.display_settings
	var tabs:=HBoxContainer.new(); parent.add_child(tabs)
	for id in ["display","game"]:
		var tab_id: String=id
		W.button(tabs,"显示" if id=="display" else "游戏",func(): app.settings_tab=tab_id; app.render.call_deferred())
	if app.settings_tab=="display":
		W.text(parent,"显示设置",28,W.GOLD)
		var scale_label:=W.text(parent,"UI 大小 · %d%%" % roundi(prefs.ui_scale*100),20)
		var slider:=HSlider.new(); slider.name="UIScale"; slider.custom_minimum_size.y=44
		slider.min_value=100; slider.max_value=125; slider.step=1; slider.value=prefs.ui_scale*100
		slider.accessibility_name="UI 大小百分比"; parent.add_child(slider)
		slider.drag_started.connect(func(): slider.set_meta("dragging",true))
		slider.value_changed.connect(func(value):
			scale_label.text="UI 大小 · %d%%" % roundi(value)
			if not slider.get_meta("dragging",false):
				prefs.ui_scale=value/100.0; app.apply_display_settings.call_deferred(false))
		slider.drag_ended.connect(func(changed):
			slider.set_meta("dragging",false)
			if changed: prefs.ui_scale=slider.value/100.0; app.apply_display_settings.call_deferred(false))
		W.text(parent,"拖动后松开生效，支持 100%～125% 逐百分比调整。",16,W.MUTED)
		var fps_row:=HBoxContainer.new(); parent.add_child(fps_row)
		W.text(fps_row,"帧率上限",20)
		var fps:=OptionButton.new(); fps.name="FrameRateLimit"; fps.custom_minimum_size.y=44; fps.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		fps.accessibility_name="帧率上限"
		for limit in Display.FRAME_RATES: fps.add_item("无限制" if limit==0 else "%d FPS" % limit)
		fps.select(Display.FRAME_RATES.find(prefs.fps_limit)); fps_row.add_child(fps)
		fps.item_selected.connect(func(index): prefs.fps_limit=Display.FRAME_RATES[index]; app.apply_display_settings.call_deferred(false))
		if prefs.mobile:
			W.text(parent,"清晰度",20)
			var quality:=OptionButton.new(); quality.name="MobileQuality"; quality.custom_minimum_size.y=44
			for label in ["流畅 · 较模糊","均衡","清晰"]: quality.add_item(label)
			quality.select(prefs.quality); parent.add_child(quality)
			quality.item_selected.connect(func(index): prefs.quality=index; app.apply_display_settings.call_deferred(false))
			W.text(parent,"清晰度只影响海面和木筏画面，文字与按钮保持清晰。",18,W.MUTED)
		else:
			W.text(parent,"分辨率",20)
			var resolution:=OptionButton.new(); resolution.name="DesktopResolution"; resolution.custom_minimum_size.y=44
			for value in Display.RESOLUTIONS: resolution.add_item("%d × %d" % [value.x,value.y])
			resolution.select(Display.RESOLUTIONS.find(prefs.resolution)); parent.add_child(resolution)
			resolution.item_selected.connect(func(index): prefs.resolution=Display.RESOLUTIONS[index]; app.apply_display_settings.call_deferred())
			var fullscreen:=CheckButton.new(); fullscreen.name="DesktopFullscreen"; fullscreen.text="全屏"; fullscreen.custom_minimum_size.y=44
			fullscreen.button_pressed=prefs.fullscreen; parent.add_child(fullscreen)
			fullscreen.toggled.connect(func(enabled): prefs.fullscreen=enabled; app.apply_display_settings.call_deferred())
			W.text(parent,"窗口模式调整窗口大小；全屏时调整场景渲染分辨率。",18,W.MUTED)
		W.text(parent,"设置自动保存。",18,W.MUTED)
	else:
		W.text(parent,"游戏设置",28,W.GOLD)
		var toggle:=CheckButton.new(); toggle.text="海面与木筏动态"; toggle.button_pressed=prefs.motion; toggle.custom_minimum_size.y=44
		parent.add_child(toggle); toggle.toggled.connect(func(enabled): prefs.motion=enabled; app.apply_display_settings.call_deferred(false))
		for key in ["auto_sort","stack_resources"]:
			var option_key: String=key
			var option:=CheckButton.new(); option.name=key; option.custom_minimum_size.y=44
			option.text="自动理牌" if key=="auto_sort" else "同类资源合并显示（叠牌）"
			option.button_pressed=app.hand_layout.get(key); parent.add_child(option)
			option.toggled.connect(func(enabled):
				app.hand_layout.set(option_key,enabled)
				if app.persistence and app.hand_layout.save_preferences()!=OK: app.message="手牌设置保存失败"
				app.render.call_deferred())
		W.text(parent,"同种资源达到 4 张时合并；长按卡牌 0.2 秒后可拖动排序，手动排序会关闭自动理牌。",18,W.MUTED)
		if view.active: W.button(parent,"放弃本局",func(): app.confirm_abandon())
	if view.screen=="game": W.button(parent,"返回首页",func(): app.handle_command("home"))
