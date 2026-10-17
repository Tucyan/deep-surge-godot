extends RefCounted
## Shared visual components. Labels and controls are separate from image assets.
const INK := Color("e3dfcc")
const MUTED := Color("9baeb1")
const GOLD := Color("c8b17a")
const TextButtonArt = preload("res://presentation/text_button_art.gd")
const UtilityButtonArt = preload("res://presentation/utility_button_art.gd")

static func theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	result.default_font = font
	result.default_font_size = 16
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("73848a"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("18303c") if state == "normal" else Color("254957")
		if state == "disabled":
			box.bg_color = Color("14242c")
		box.border_color = GOLD if state == "focus" else Color("41616c")
		box.set_border_width_all(1)
		box.set_corner_radius_all(1)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 7
		box.content_margin_bottom = 7
		result.set_stylebox(state, "Button", box)
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("separation", "HBoxContainer", 10)
	return result

static func text(parent: Node, value: String, size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

static func button(parent: Node, title: String, callback: Callable, disabled: bool = false, reason: String = "") -> Button:
	var result := Button.new()
	result.text = title
	result.disabled = disabled
	result.tooltip_text = reason
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.pressed.connect(callback)
	parent.add_child(result)
	TextButtonArt.apply(result)
	return result

static func panel(parent: Node, minimum: Vector2 = Vector2.ZERO) -> VBoxContainer:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = minimum
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055,0.11,0.14,0.91)
	style.border_color = Color("536269")
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	outer.add_theme_stylebox_override("panel", style)
	parent.add_child(outer)
	var column := VBoxContainer.new()
	outer.add_child(column)
	return column

static func art(parent: Node, assets: RefCounted, asset_id: String, height: float = 130, caption: bool = true) -> void:
	var image := TextureRect.new()
	image.texture = assets.texture(asset_id)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(0, height)
	parent.add_child(image)
	if not caption or not assets.show_label(asset_id):
		return
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.add_child(center)
	var label := text(center, assets.label(asset_id), 24, GOLD)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF

static func counter(parent: Node, value: String) -> Label:
	var label := text(parent,value,15,MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = 46
	label.size_flags_horizontal = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

static func primary(button: Button) -> void:
	if button.has_node("SurgeTextButtonArt"):
		button.set_meta("surge_primary", true)
		button.queue_redraw()
		return
	var style := StyleBoxFlat.new(); style.bg_color = GOLD; style.border_color = Color("e5d4a2"); style.set_border_width_all(1)
	style.content_margin_left = 12; style.content_margin_right = 12; style.content_margin_top = 10; style.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal",style)
	button.add_theme_color_override("font_color",Color("172c34"))

static func corner_close(parent: Control, callback: Callable) -> Button:
	# Separate overlay avoids container layout stretching X into a full-width row.
	var overlay:=Control.new(); overlay.name="CloseOverlay"; overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var close:=button(overlay,"X",callback); close.name="CloseX"
	close.accessibility_name="关闭"; close.tooltip_text="关闭"
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left=-48; close.offset_right=0; close.offset_top=0; close.offset_bottom=44
	close.custom_minimum_size=Vector2(44,44); close.add_theme_font_size_override("font_size",24)
	UtilityButtonArt.apply(close, "close")
	return close

static func grid(parent: Node, columns: int = 3) -> GridContainer:
	var result := GridContainer.new()
	result.columns = columns
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("h_separation", 18)
	result.add_theme_constant_override("v_separation", 18)
	parent.add_child(result)
	return result
