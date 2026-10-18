extends Control
## Source-sized nine-slice drawing behind a native Button. No input or game state.
const TEXTURES := {
	"normal": preload("res://assets/ui/buttons/normal.png"),
	"hover": preload("res://assets/ui/buttons/hover.png"),
	"pressed": preload("res://assets/ui/buttons/pressed.png"),
	"disabled": preload("res://assets/ui/buttons/disabled.png"),
}
const COMPASS = preload("res://assets/ui/buttons/compass.png")
const SYMBOLS := ["", "X", "×", "✕", "+", "-", "−", "＋", "－", "◀", "▶", "◁", "▷"]
var content_style: StyleBoxEmpty
var compact := false
var frames: Dictionary = {}
var focus_style: StyleBoxFlat
var colors := {
	"font_color": Color("f5eddf"), "font_hover_color": Color("fff9ed"),
	"font_focus_color": Color("fff9ed"), "font_pressed_color": Color("122138"),
	"font_hover_pressed_color": Color("122138"), "font_disabled_color": Color("788596"),
}

static func uses_touch_ui(node: Node) -> bool:
	var current := node
	while current != null:
		if current.has_meta("mobile_ui"): return bool(current.get_meta("mobile_ui"))
		current = current.get_parent()
	return OS.has_feature("mobile")

static func apply(button: Button) -> void:
	var art = load("res://presentation/text_button_art.gd").new()
	art.name = "SurgeTextButtonArt"
	art.compact = button.text.strip_edges() in SYMBOLS
	art.content_style = StyleBoxEmpty.new()
	art.content_style.content_margin_left = 12 if art.compact else 28
	art.content_style.content_margin_right = art.content_style.content_margin_left
	# Intrinsic padding survives callers' old 34/40/44px minimum overrides.
	# Dedicated icon/card skins remove this style and keep their own metrics.
	var touch := uses_touch_ui(button)
	art.content_style.content_margin_top = 18 if touch else 7
	art.content_style.content_margin_bottom = 18 if touch else 7
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, art.content_style)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("c8b17a")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	art.focus_style = focus
	button.add_theme_stylebox_override("focus", focus)
	for key in art.colors:
		button.add_theme_color_override(key, art.colors[key])
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.show_behind_parent = true
	button.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.resized.connect(art.layout_art)
	button.draw.connect(art.queue_redraw)
	button.theme_changed.connect(art.release_if_replaced)
	art.layout_art()

func release_if_replaced() -> void:
	var button := get_parent() as Button
	if button.get_theme_stylebox("normal") == content_style:
		return
	# A caller supplies a dedicated card/icon/action skin after W.button().
	# Restore native fallback states and leave that caller's overrides intact.
	button.theme_changed.disconnect(release_if_replaced)
	button.resized.disconnect(layout_art)
	button.draw.disconnect(queue_redraw)
	for state in ["hover", "pressed", "hover_pressed", "disabled"]:
		if button.get_theme_stylebox(state) == content_style:
			button.remove_theme_stylebox_override(state)
	if button.get_theme_stylebox("focus") == focus_style:
		button.remove_theme_stylebox_override("focus")
	for key in colors:
		if button.get_theme_color(key) == colors[key]:
			button.remove_theme_color_override(key)
	queue_free()

func layout_art() -> void:
	var button := get_parent() as Button
	# Existing card, icon, craft and nautical skins replace the normal StyleBox.
	if button.get_theme_stylebox("normal") != content_style:
		queue_redraw()
		return
	if not compact:
		var padding := maxf(28, ceilf(75 * minf(button.size.y / 104.0, 1.0)))
		if content_style.content_margin_left != padding:
			content_style.content_margin_left = padding
			content_style.content_margin_right = padding
	queue_redraw()

func _draw() -> void:
	var button := get_parent() as Button
	if button == null or button.get_theme_stylebox("normal") != content_style or size.x <= 0 or size.y <= 0:
		return
	var state := "normal"
	if button.disabled:
		state = "disabled"
	elif button.is_pressed():
		state = "pressed"
	elif button.is_hovered() or button.get_meta("surge_primary", false):
		state = "hover"
	if not frames.has(state):
		var frame := StyleBoxTexture.new()
		frame.texture = TEXTURES[state]
		frame.texture_margin_left = 82
		frame.texture_margin_right = 82
		frame.texture_margin_top = 27
		frame.texture_margin_bottom = 27
		frames[state] = frame
	frames[state].modulate_color = Color(1, 0.65, 0.65) if button.get_meta("surge_danger", false) else Color.WHITE
	# Scale the drawing coordinates so source corners also fit 36px-high rows.
	# Texture files remain unchanged. Width grows only through the nine-slice.
	var factor := minf(size.y / 104.0, size.x / 180.0)
	var vertical_factor := size.y / 104.0 if compact else factor
	draw_set_transform(Vector2(0, (size.y - 104 * vertical_factor) * 0.5), 0, Vector2(factor, vertical_factor))
	draw_style_box(frames[state], Rect2(Vector2.ZERO, Vector2(size.x / factor, 104)))
	if not compact:
		var tint := Color("788596") if button.disabled else Color.WHITE
		for x in [19.0, size.x / factor - 63.0]:
			draw_texture_rect(COMPASS, Rect2(x, 30, 44, 44), false, tint)
