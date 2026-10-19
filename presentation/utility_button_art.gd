extends Control
## Small utility glyphs use geometry so X/reset stay sharp at every UI scale.
var kind := "close"
var icon_only := true

static func apply(button: Button, glyph: String, only_icon: bool = true) -> void:
	var art = load("res://presentation/utility_button_art.gd").new()
	art.name = "UtilityButtonArt"
	art.kind = glyph; art.icon_only = only_icon
	button.icon = null
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("0d202c")
		style.border_color = Color("78898d")
		style.set_border_width_all(1)
		style.set_corner_radius_all(28 if glyph in ["reset","view"] and only_icon else 8)
		style.content_margin_left = 0 if only_icon else 34
		style.content_margin_right = 0 if only_icon else 12
		style.content_margin_top = 7; style.content_margin_bottom = 7
		if state == "hover":
			style.bg_color = Color("1e3b48"); style.border_color = Color("e6d3a4")
		elif state in ["pressed", "hover_pressed"]:
			style.bg_color = Color("284c59"); style.border_color = Color("fff0c9")
		elif state == "disabled":
			style.bg_color = Color("101c25"); style.border_color = Color("40505a")
		elif state == "focus":
			style.bg_color = Color.TRANSPARENT; style.border_color = Color("e6d3a4")
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color", "font_focus_color"]:
		var color := Color("f1e6cd")
		if key == "font_disabled_color": color = Color("73818a")
		button.add_theme_color_override(key, Color.TRANSPARENT if only_icon else color)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.draw.connect(art.queue_redraw)
	button.resized.connect(art.queue_redraw)

func _draw() -> void:
	if kind=="view": return
	var button := get_parent() as Button
	if button == null: return
	var color := Color("e5dbc6")
	if button.disabled: color = Color("73818a")
	elif preload("res://presentation/text_button_art.gd").pointer_hovered(button) or button.has_focus(): color = Color("fff1d2")
	var center := size * 0.5 if icon_only else Vector2(18, size.y * 0.5)
	var factor := clampf(minf(size.x, size.y) / 44.0, 0.8, 1.25) if icon_only else 0.85
	if button.is_pressed(): factor *= 0.92
	draw_set_transform(center, 0, Vector2.ONE * factor)
	if kind == "close":
		# No font-dependent serif, optical offset or stretched enclosing frame.
		for sign in [-1.0, 1.0]:
			var start := Vector2(-6.5, -6.5 * sign)
			var end := -start
			draw_line(start, end, color, 2, true)
			draw_circle(start, 1, color); draw_circle(end, 1, color)
	else:
		var angle := deg_to_rad(-140)
		var radius := 9.5
		draw_arc(Vector2.ZERO, radius, angle, deg_to_rad(140), 48, color, 2, true)
		var tip := Vector2(cos(angle), sin(angle)) * radius
		var direction := Vector2(sin(angle), -cos(angle))
		var side := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([tip + direction * 1.5, tip - direction * 4.2 + side * 3, tip - direction * 4.2 - side * 3]), color)
