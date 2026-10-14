extends Control
## Explicitly instantiated page. Not registered in the main app's routing.
signal story_completed(result: Dictionary)
const Player = preload("res://story/story_player.gd")
const W = preload("res://presentation/widgets.gd")
const Assets = preload("res://presentation/asset_catalog.gd")
const REFERENCE := Vector2(1600, 900)
const LOG_PAGE_SIZE := 2
var player = Player.new()
var assets = Assets.new()
var composition: Control
var body: Label
var speaker: Label
var description: Label
var title_label: Label
var hint: Label
var skip_button: Button
var log_button: Button
var next_button: Button
var choice_buttons: Array[Button] = []
var choice_root: Control
var log_overlay: Control
var log_close: Button
var log_text: Label
var log_counter: Label
var log_prev: Button
var log_next: Button
var _log_page := 0
var _elapsed := 0.0
var characters_per_second := 32.0

func _ready() -> void:
	theme = W.theme()
	clip_contents = true
	var poster := TextureRect.new()
	poster.texture = assets.texture("texture.title.ocean-poster")
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(poster)
	poster.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.012, 0.028, 0.47)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	composition = Control.new()
	composition.size = REFERENCE
	composition.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(composition)
	title_label = _label(composition, "", Vector2(82, 54), Vector2(940, 60), 35)
	_label(composition, "DEEP SURGE  /  航海叙事", Vector2(86, 110), Vector2(680, 40), 18, Color("abc8ec"))
	skip_button = _button(composition, "SKIP  ▷▷", Vector2(1320, 42), Vector2(220, 72), "toolbar")
	skip_button.tooltip_text = "跳过对白，遇到选项停止"
	skip_button.pressed.connect(skip)
	var desc_box := Panel.new()
	desc_box.position = Vector2(94, 420)
	desc_box.size = Vector2(720, 116)
	desc_box.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.02, 0.05, 0.85)
	style.border_color = Color("0062ff")
	style.border_width_left = 5
	desc_box.add_theme_stylebox_override("panel", style)
	composition.add_child(desc_box)
	description = _label(desc_box, "", Vector2(26, 18), Vector2(654, 84), 23, Color("e0e9f7"))
	choice_root = Control.new()
	choice_root.mouse_filter = MOUSE_FILTER_IGNORE
	composition.add_child(choice_root)
	_texture(composition, "dialogue", Vector2(58, 602), Vector2(1490, 284))
	var name_tag := Panel.new()
	name_tag.position = Vector2(334, 650)
	name_tag.size = Vector2(370, 48)
	name_tag.mouse_filter = MOUSE_FILTER_IGNORE
	var name_style := StyleBoxFlat.new()
	name_style.bg_color = Color("080e1b")
	name_style.border_color = Color("0062ff")
	name_style.border_width_left = 4
	name_tag.add_theme_stylebox_override("panel", name_style)
	composition.add_child(name_tag)
	speaker = _label(name_tag, "", Vector2(16, 5), Vector2(346, 40), 27, Color("82b5ff"))
	body = _label(composition, "", Vector2(350, 706), Vector2(980, 100), 25)
	log_button = _button(composition, "LOG  航海笔记", Vector2(92, 542), Vector2(286, 64), "toolbar")
	log_button.pressed.connect(open_log)
	next_button = _button(composition, "继续  ▷", Vector2(1270, 832), Vector2(232, 58), "toolbar")
	next_button.pressed.connect(advance)
	hint = _label(composition, "点击继续 / Enter · 显示全文，再推进", Vector2(354, 839), Vector2(850, 28), 16, Color("aebbd0"))
	_build_log()
	player.completed.connect(func(result): story_completed.emit(result.duplicate(true)))
	resized.connect(_reflow)
	_reflow()
	_refresh()

func _label(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int, color := Color("fffdf1")) -> Label:
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

func _texture(parent: Node, asset: String, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = assets.texture("ui.story." + asset)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = pos
	image.size = dimensions
	image.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, asset: String) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = dimensions
	button.text = text
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 23)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_hover_color", Color("8abfff"))
	button.add_theme_color_override("font_focus_color", Color("8abfff"))
	parent.add_child(button)
	var image := _texture(button, asset, Vector2.ZERO, dimensions)
	button.move_child(image, 0)
	image.show_behind_parent = true
	button.mouse_entered.connect(func(): image.modulate = Color(1.3, 1.3, 1.3))
	button.mouse_exited.connect(func(): image.modulate = Color.WHITE)
	button.focus_entered.connect(func(): image.modulate = Color(1.3, 1.3, 1.3))
	button.focus_exited.connect(func(): image.modulate = Color.WHITE)
	return button

func _build_log() -> void:
	log_overlay = Control.new()
	log_overlay.size = REFERENCE
	log_overlay.mouse_filter = MOUSE_FILTER_STOP
	composition.add_child(log_overlay)
	var veil := ColorRect.new()
	veil.color = Color(0.0, 0.015, 0.05, 0.94)
	veil.size = REFERENCE
	log_overlay.add_child(veil)
	var sheet := Panel.new()
	sheet.position = Vector2(300, 168)
	sheet.size = Vector2(1080, 630)
	sheet.mouse_filter = MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("070d18")
	paper.border_color = Color("005bff")
	paper.set_border_width_all(2)
	sheet.add_theme_stylebox_override("panel", paper)
	log_overlay.add_child(sheet)
	_texture(log_overlay, "choice", Vector2(280, 132), Vector2(1110, 120))
	_label(log_overlay, "LOG  /  航海笔记", Vector2(450, 174), Vector2(780, 54), 34)
	log_text = _label(log_overlay, "", Vector2(378, 278), Vector2(920, 414), 21)
	log_prev = _button(log_overlay, "◁ 上一页", Vector2(440, 705), Vector2(212, 60), "toolbar")
	log_prev.pressed.connect(func(): _log_page -= 1; _refresh_log())
	log_next = _button(log_overlay, "下一页 ▷", Vector2(860, 705), Vector2(212, 60), "toolbar")
	log_next.pressed.connect(func(): _log_page += 1; _refresh_log())
	log_counter = _label(log_overlay, "", Vector2(698, 723), Vector2(154, 40), 22)
	log_close = _button(log_overlay, "返回剧情 ×", Vector2(1280, 42), Vector2(260, 72), "toolbar")
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
		var button := _button(choice_root, choice.text, Vector2(996, 586 - options.size() * 76 + i * 76), Vector2(538, 70), "choice")
		button.pressed.connect(choose.bind(choice.id))
		choice_buttons.append(button)
	next_button.disabled = view.status != "playing" or not options.is_empty()
	skip_button.disabled = view.status != "playing"
	log_button.disabled = view.log_count == 0
	if view.status == "completed":
		body.visible_characters = -1
		hint.text = "本段剧情已结束 · 可在 LOG 中回看"
	elif not options.is_empty():
		hint.text = "请选择下一步行动"
	else:
		hint.text = "点击继续 / Enter · 显示全文，再推进"
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
	_log_page = maxi(0, ceili(player.get_log().size() / float(LOG_PAGE_SIZE)) - 1)
	_refresh_log()
	log_overlay.show()
	for button in [skip_button, log_button, next_button] + choice_buttons: button.focus_mode = FOCUS_NONE
	log_close.grab_focus()

func close_log() -> void:
	log_overlay.hide()
	for button in [skip_button, log_button, next_button] + choice_buttons: button.focus_mode = FOCUS_ALL
	if not next_button.disabled: next_button.grab_focus()

func _refresh_log() -> void:
	var rows: Array = player.get_log()
	var count := maxi(1, ceili(rows.size() / float(LOG_PAGE_SIZE)))
	_log_page = clampi(_log_page, 0, count - 1)
	var texts: PackedStringArray = []
	for row in rows.slice(_log_page * LOG_PAGE_SIZE, (_log_page + 1) * LOG_PAGE_SIZE):
		var line: String = "【" + row.speaker + "】\n" + row.description + "\n" + row.text
		if not row.choice_text.is_empty(): line += "\n→ " + row.choice_text
		texts.append(line)
	log_text.text = "\n\n".join(texts)
	_fit_text(log_text, 21, 16)
	log_counter.text = "%d / %d" % [_log_page + 1, count]
	log_prev.disabled = _log_page == 0
	log_next.disabled = _log_page == count - 1

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
