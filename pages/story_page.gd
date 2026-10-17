extends Control
## Explicitly instantiated page. Not registered in the main app's routing.
signal story_completed(result: Dictionary)
const Player = preload("res://story/story_player.gd")
const REFERENCE := Vector2(1600, 900)
var player = Player.new()
var composition: Control
var body: Label
var speaker: Label
var description: Label
var title_label: Label
var skip_button: Button
var log_button: Button
var next_button: Button
var choice_buttons: Array[Button] = []
var choice_root: Control
var log_overlay: Control
var log_close: Button
var log_text: Label
var log_scroll: ScrollContainer
var _elapsed := 0.0
var characters_per_second := 32.0

func _ready() -> void:
	var plain_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	plain_theme.default_font = font
	theme = plain_theme
	clip_contents = true
	var background := ColorRect.new()
	background.color = Color("202020")
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	composition = Control.new()
	composition.size = REFERENCE
	composition.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(composition)
	title_label = _label(composition, "", Vector2(82, 54), Vector2(940, 60), 35)
	_label(composition, "DEEP SURGE  /  航海叙事", Vector2(86, 110), Vector2(680, 40), 18, Color("eeeeee"))
	skip_button = _button(composition, "SKIP  ▷▷", Vector2(1320, 42), Vector2(220, 72))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		skip_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	skip_button.tooltip_text = "跳过对白，遇到选项停止"
	skip_button.pressed.connect(skip)
	var desc_box := Panel.new()
	desc_box.position = Vector2(94, 420)
	desc_box.size = Vector2(720, 116)
	desc_box.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("303030")
	style.border_color = Color("707070")
	style.set_border_width_all(1)
	desc_box.add_theme_stylebox_override("panel", style)
	composition.add_child(desc_box)
	description = _label(desc_box, "", Vector2(26, 18), Vector2(654, 84), 23, Color("eeeeee"))
	choice_root = Control.new()
	choice_root.mouse_filter = MOUSE_FILTER_IGNORE
	composition.add_child(choice_root)
	_panel(composition, Vector2(82, 630), Vector2(1452, 196))
	var name_tag := Panel.new()
	name_tag.position = Vector2(110, 642)
	name_tag.size = Vector2(370, 48)
	name_tag.mouse_filter = MOUSE_FILTER_IGNORE
	var name_style := StyleBoxFlat.new()
	name_style.bg_color = Color("303030")
	name_style.border_color = Color("707070")
	name_style.set_border_width_all(0)
	name_tag.add_theme_stylebox_override("panel", name_style)
	composition.add_child(name_tag)
	speaker = _label(name_tag, "", Vector2(16, 5), Vector2(346, 40), 27, Color("eeeeee"))
	body = _label(composition, "", Vector2(110, 706), Vector2(980, 100), 25)
	log_button = _button(composition, "LOG  航海笔记", Vector2(92, 832), Vector2(286, 58))
	log_button.pressed.connect(open_log)
	next_button = _button(composition, "继续  ▷", Vector2(1270, 832), Vector2(232, 58))
	next_button.pressed.connect(advance)
	_build_log()
	player.completed.connect(func(result): story_completed.emit(result.duplicate(true)))
	resized.connect(_reflow)
	_reflow()
	_refresh()

func _label(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int, color := Color("eeeeee")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.set_meta("text_box_size", dimensions)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _fit_text(label: Label, maximum: int, minimum: int) -> void:
	var font_size := maximum
	var bounds: Vector2 = label.get_meta("text_box_size")
	var font: Font = label.get_theme_font("font")
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	while font_size > minimum and font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, bounds.x, font_size, -1, flags).y > bounds.y:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	label.size = bounds

func _panel(parent: Node, pos: Vector2, dimensions: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = dimensions
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("303030")
	style.border_color = Color("707070")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _button(parent: Node, text: String, pos: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = dimensions
	button.text = text
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 23)
	parent.add_child(button)
	return button

func _build_log() -> void:
	log_overlay = Control.new()
	log_overlay.size = REFERENCE
	log_overlay.mouse_filter = MOUSE_FILTER_STOP
	composition.add_child(log_overlay)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.85)
	veil.size = REFERENCE
	log_overlay.add_child(veil)
	var sheet := Panel.new()
	sheet.position = Vector2(300, 168)
	sheet.size = Vector2(1080, 630)
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("303030")
	paper.border_color = Color("707070")
	paper.set_border_width_all(2)
	sheet.add_theme_stylebox_override("panel", paper)
	log_overlay.add_child(sheet)

	_label(log_overlay, "LOG  /  航海笔记", Vector2(450, 174), Vector2(780, 54), 34)
	log_scroll = ScrollContainer.new()
	log_scroll.position = Vector2(378, 260)
	log_scroll.size = Vector2(920, 500)
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_overlay.add_child(log_scroll)
	log_text = Label.new()
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_text.mouse_filter = MOUSE_FILTER_IGNORE
	log_text.add_theme_font_size_override("font_size", 21)
	log_text.add_theme_color_override("font_color", Color("eeeeee"))
	log_scroll.add_child(log_text)
	log_close = _button(log_overlay, "X", Vector2(1468, 42), Vector2(72, 72))
	log_close.pressed.connect(close_log)
	log_overlay.hide()

func _reflow() -> void:
	if composition == null: return
	var fit := minf(size.x / REFERENCE.x, size.y / REFERENCE.y)
	composition.scale = Vector2.ONE * fit
	composition.position = (size - REFERENCE * fit) * 0.5

func load_story(data: Variant) -> Dictionary:
	var result: Dictionary = player.load_story(data)
	if result.ok and is_node_ready():
		close_log()
		_refresh()
	return result

func _refresh() -> void:
	var view: Dictionary = player.get_view()
	title_label.text = view.title
	_fit_text(title_label, 35, 23)
	var node: Dictionary = view.node
	speaker.text = node.get("speaker", "旁白")
	_fit_text(speaker, 27, 14)
	description.text = node.get("description", "")
	_fit_text(description, 23, 17)
	description.get_parent().visible = not description.text.is_empty()
	body.text = node.get("text", "")
	_fit_text(body, 25, 18)
	body.visible_characters = 0
	_elapsed = 0.0
	for button in choice_buttons:
		button.get_parent().remove_child(button)
		button.queue_free()
	choice_buttons.clear()
	var options: Array = node.get("choices", [])
	for i in range(options.size()):
		var choice: Dictionary = options[i]
		var button := _button(choice_root, choice.text, Vector2(996, 586 - options.size() * 76 + i * 76), Vector2(538, 70))
		button.pressed.connect(choose.bind(choice.id))
		choice_buttons.append(button)
	next_button.disabled = view.status != "playing" or not options.is_empty()
	skip_button.disabled = view.status != "playing"
	log_button.disabled = view.log_count == 0
	if view.status == "completed":
		body.visible_characters = -1
	_update_choice_visibility()

func _process(delta: float) -> void:
	if body == null or log_overlay.visible or body.visible_characters == -1: return
	_elapsed += delta * characters_per_second
	body.visible_characters = mini(int(_elapsed), body.text.length())
	if body.visible_characters >= body.text.length(): body.visible_characters = -1
	_update_choice_visibility()

func _update_choice_visibility() -> void:
	for button in choice_buttons: button.visible = body.visible_characters == -1

func advance() -> void:
	if log_overlay.visible: return
	if body.visible_characters != -1:
		body.visible_characters = -1
		_update_choice_visibility()
		return
	if player.advance().ok: _refresh()

func choose(id: String) -> void:
	if log_overlay.visible or body.visible_characters != -1: return
	if player.choose(id).ok: _refresh()

func skip() -> void:
	if log_overlay.visible: return
	if player.skip().ok:
		_refresh()
		body.visible_characters = -1
		_update_choice_visibility()

func open_log() -> void:
	if player.get_log().is_empty(): return
	_refresh_log()
	log_overlay.show()
	for button in [skip_button, log_button, next_button] + choice_buttons: button.focus_mode = FOCUS_NONE
	log_close.grab_focus()
	_scroll_log_to_latest()

func close_log() -> void:
	log_overlay.hide()
	for button in [skip_button, log_button, next_button] + choice_buttons: button.focus_mode = FOCUS_ALL
	if not next_button.disabled: next_button.grab_focus()

func _refresh_log() -> void:
	var rows: Array = player.get_log()
	var texts: PackedStringArray = []
	for row in rows:
		var line: String = "【" + row.speaker + "】\n" + row.description + "\n" + row.text
		if not row.choice_text.is_empty(): line += "\n→ " + row.choice_text
		texts.append(line)
	log_text.text = "\n\n".join(texts)

func _scroll_log_to_latest() -> void:
	# Wait for the container to measure wrapped text before setting the scrollbar.
	await get_tree().process_frame
	await get_tree().process_frame
	if not log_overlay.visible: return
	var bar := log_scroll.get_v_scroll_bar()
	log_scroll.scroll_vertical = int(ceilf(bar.max_value))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event is InputEventKey:
		match event.keycode:
			KEY_ESCAPE:
				if log_overlay.visible: close_log()
			KEY_L:
				if log_overlay.visible: close_log()
				else: open_log()
			KEY_ENTER, KEY_SPACE:
				advance()
			_:
				return
		get_viewport().set_input_as_handled()
