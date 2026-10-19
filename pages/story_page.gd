extends Control
## Explicitly instantiated page. Not registered in the main app's routing.
signal story_completed(result: Dictionary)
const Player = preload("res://story/story_player.gd")
const REFERENCE := Vector2(1600, 900)
var player = Player.new()
var composition: Control
var dialogue_box_rect: TextureRect
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
var _pending_speaker := ""

const KNOWN_CHARACTERS := [
	"塞琳", "主角", "涅德", "柯尔", "老木匠柯尔", "芮安", "哈克",
	"水手甲", "水手乙", "水手 A", "水手", "阿棠", "沈岚", "？？？"
]

static func parse_dialogue_node(raw_text: String, declared_speaker: String = "") -> Dictionary:
	var text := raw_text.strip_edges()
	var spk := declared_speaker.strip_edges()
	var was_explicit_narration := false
	if spk == "旁白" or spk.to_lower() == "narrator":
		spk = ""
		was_explicit_narration = true

	# Standalone narration line
	if text == "旁白：" or text == "旁白:" or text == "旁白":
		return {"speaker": "", "text": "", "is_empty": true, "pending_speaker": ""}

	# Leading 旁白：or 旁白:
	if text.begins_with("旁白：") or text.begins_with("旁白:"):
		text = text.substr(3).strip_edges()
		return {"speaker": spk, "text": text, "is_empty": text.is_empty(), "pending_speaker": ""}

	# If explicitly declared as narration, don't parse arbitrary colons into speakers
	if was_explicit_narration:
		return {"speaker": "", "text": text, "is_empty": text.is_empty(), "pending_speaker": ""}

	# Check for speaker prefix
	var colon_pos := -1
	for sep in ["：", ":"]:
		var p := text.find(sep)
		if p != -1 and (colon_pos == -1 or p < colon_pos):
			colon_pos = p

	if colon_pos > 0 and colon_pos <= 10:
		var prefix := text.substr(0, colon_pos).strip_edges()
		var rest := text.substr(colon_pos + 1).strip_edges()
		if prefix == "旁白":
			return {"speaker": "", "text": rest, "is_empty": rest.is_empty(), "pending_speaker": ""}
		elif prefix in KNOWN_CHARACTERS or (!spk.is_empty() and prefix == spk) or (rest.begins_with("“") or rest.begins_with("\"") or rest.begins_with("（") or rest.begins_with("(")):
			var non_speaker_starts := ["【", "[", "·", "（", "(", "💀", ">", "\"", "“", "'"]
			var has_bad_start := false
			for bad in non_speaker_starts:
				if prefix.begins_with(bad):
					has_bad_start = true
					break
			if not has_bad_start:
				if rest.is_empty():
					return {"speaker": prefix, "text": "", "is_empty": true, "pending_speaker": prefix}
				else:
					return {"speaker": prefix, "text": rest, "is_empty": false, "pending_speaker": ""}

	if not spk.is_empty():
		for sep in ["：", ":"]:
			if text.begins_with(spk + sep):
				text = text.substr(spk.length() + 1).strip_edges()
				break

	return {"speaker": spk, "text": text, "is_empty": text.is_empty(), "pending_speaker": ""}

func _ready() -> void:
	var plain_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	plain_theme.default_font = font
	theme = plain_theme
	clip_contents = true
	var background := ColorRect.new()
	background.color = Color("181a1d")
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	composition = Control.new()
	composition.size = REFERENCE
	composition.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(composition)

	title_label = _label(composition, "", Vector2(82, 50), Vector2(940, 60), 35)
	_label(composition, "DEEP SURGE  /  航海叙事", Vector2(86, 106), Vector2(680, 40), 18, Color("cccccc"))

	# Top toolbar
	log_button = _button(composition, "LOG  航海笔记", Vector2(1040, 42), Vector2(240, 72))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		log_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	log_button.tooltip_text = "查看已读剧情与选项记录"
	log_button.pressed.connect(open_log)

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
	style.bg_color = Color("232b32")
	style.border_color = Color("5c6b75")
	style.set_border_width_all(1)
	desc_box.add_theme_stylebox_override("panel", style)
	composition.add_child(desc_box)
	description = _label(desc_box, "", Vector2(26, 18), Vector2(654, 84), 23, Color("eeeeee"))

	choice_root = Control.new()
	choice_root.mouse_filter = MOUSE_FILTER_IGNORE
	composition.add_child(choice_root)

	# Dialogue box texture asset
	dialogue_box_rect = TextureRect.new()
	dialogue_box_rect.name = "DialogueBoxImage"
	dialogue_box_rect.texture = preload("res://assets/story_ui/dialogue_box.png")
	dialogue_box_rect.position = Vector2(67, 615)
	dialogue_box_rect.size = Vector2(1466, 256)
	dialogue_box_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialogue_box_rect.stretch_mode = TextureRect.STRETCH_SCALE
	dialogue_box_rect.mouse_filter = MOUSE_FILTER_STOP
	dialogue_box_rect.gui_input.connect(_on_box_gui_input)
	composition.add_child(dialogue_box_rect)

	# Speaker nickname label inside the top-left dark ornamental pill
	speaker = _label(composition, "", Vector2(140, 622), Vector2(250, 46), 26, Color("f5f0e6"))
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Dialogue body label on the cream parchment
	body = _label(composition, "", Vector2(150, 700), Vector2(1120, 100), 25, Color("142028"))

	# Next advance button on the lower right of dialogue box
	next_button = _button(composition, "继续  ▷", Vector2(1280, 786), Vector2(200, 50))
	var next_style := StyleBoxFlat.new()
	next_style.bg_color = Color("23313d")
	next_style.border_color = Color("8c7e68")
	next_style.set_border_width_all(1)
	next_style.set_corner_radius_all(6)
	next_button.add_theme_stylebox_override("normal", next_style)
	var next_hover := next_style.duplicate()
	next_hover.bg_color = Color("34495e")
	next_button.add_theme_stylebox_override("hover", next_hover)
	var next_pressed := next_style.duplicate()
	next_pressed.bg_color = Color("1a252f")
	next_button.add_theme_stylebox_override("pressed", next_pressed)
	var next_disabled := next_style.duplicate()
	next_disabled.bg_color = Color("23313d", 0.5)
	next_disabled.border_color = Color("8c7e68", 0.3)
	next_button.add_theme_stylebox_override("disabled", next_disabled)
	next_button.add_theme_color_override("font_color", Color("f0ead6"))
	next_button.add_theme_color_override("font_hover_color", Color("ffffff"))
	next_button.add_theme_color_override("font_disabled_color", Color("888888"))
	next_button.pressed.connect(advance)

	_build_log()
	player.completed.connect(func(result): story_completed.emit(result.duplicate(true)))
	resized.connect(_reflow)
	_reflow()
	_refresh()

func _on_box_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance()

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
	paper.bg_color = Color("232b32")
	paper.border_color = Color("70808c")
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
	_pending_speaker = ""
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
	var declared: String = node.get("speaker", "")
	var raw_text: String = node.get("text", "")
	var parsed: Dictionary = parse_dialogue_node(raw_text, declared)
	if parsed.speaker.is_empty() and not _pending_speaker.is_empty():
		parsed.speaker = _pending_speaker
		_pending_speaker = ""

	# Auto-advance past empty / standalone header nodes so player never sees blank screens
	while parsed.is_empty and view.status == "playing" and view.node.get("choices", []).is_empty():
		if not parsed.pending_speaker.is_empty():
			_pending_speaker = parsed.pending_speaker
		var step: Dictionary = player.advance()
		if not step.get("ok", false):
			break
		view = player.get_view()
		node = view.node
		declared = node.get("speaker", "")
		raw_text = node.get("text", "")
		parsed = parse_dialogue_node(raw_text, declared)
		if parsed.speaker.is_empty() and not _pending_speaker.is_empty():
			parsed.speaker = _pending_speaker
			_pending_speaker = ""

	speaker.text = parsed.speaker
	_fit_text(speaker, 26, 14)

	description.text = node.get("description", "")
	_fit_text(description, 23, 17)
	description.get_parent().visible = not description.text.is_empty()

	body.text = parsed.text
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
		var imported: bool = player._story.get("imported_chapter1", false)
		var button := _button(choice_root, choice.text,
			Vector2(850, 610 - options.size() * 110 + i * 110) if imported else Vector2(996, 586 - options.size() * 76 + i * 76),
			Vector2(684, 104) if imported else Vector2(538, 70))
		if imported:
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size", 20)
		button.disabled = choice.get("disabled", false)
		button.tooltip_text = str(choice.get("disabled_reason", ""))
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
	var prev_spk := ""
	for row in rows:
		var parsed: Dictionary = parse_dialogue_node(row.get("text", ""), row.get("speaker", ""))
		if parsed.is_empty:
			if not parsed.pending_speaker.is_empty():
				prev_spk = parsed.pending_speaker
			continue
		var who: String = parsed.speaker
		if who.is_empty() and not prev_spk.is_empty():
			who = prev_spk
			prev_spk = ""
		var tag: String = "【" + (who if not who.is_empty() else "旁白") + "】"
		var desc: String = str(row.get("description", ""))
		var line: String = tag + "\n" + (desc + "\n" if not desc.is_empty() else "") + parsed.text
		var choice_str: String = str(row.get("choice_text", ""))
		if not choice_str.is_empty():
			line += "\n→ " + choice_str
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
