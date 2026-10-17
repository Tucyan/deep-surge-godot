extends Control
## Local presentation only: never touches the session or its random stream.
signal finished
signal character_revealed(character: String)
const DATA := "res://assets/opening-intro/scenes.json"
const PREFERENCES := "user://opening-intro.cfg"
const Voice = preload("res://addons/blip_voice/blip_voice.gd")
var preference_path := PREFERENCES
var automatic := true
var persist_completion := true
var playback_data: Dictionary = {}
var exit_label := "跳过序章"
var scenes: Array = []
var scene_index := 0
var music: AudioStreamPlayer
var picture: TextureRect
var narration: Label
var canvas: Control
var timer: Timer
var content: Control
var done := false
var elapsed := 0.0
var save_error := OK
var revealed := 0
var voice: Node
var next_character_in := 0.65
const CHARACTER_INTERVAL := 1.0 / 12.0

static func should_play(path: String = PREFERENCES) -> bool:
	var config := ConfigFile.new()
	return config.load(path) != OK or config.get_value("opening", "watched", false) != true

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.mouse_filter = MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var data: Dictionary = playback_data if not playback_data.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(DATA))
	scenes = data.scenes
	canvas = Control.new()
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	content = Control.new()
	content.mouse_filter = MOUSE_FILTER_IGNORE
	canvas.add_child(content)
	picture = TextureRect.new()
	picture.position = Vector2(500, 115)
	picture.size = Vector2(600, 325)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(picture)
	narration = Label.new()
	narration.position = Vector2(500, 510)
	narration.size = Vector2(600, 205)
	narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	narration.add_theme_font_override("font", font)
	narration.add_theme_font_size_override("font_size", 30)
	narration.add_theme_constant_override("line_spacing", 14)
	narration.add_theme_color_override("font_color", Color.WHITE)
	narration.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(narration)
	var next := Button.new()
	next.text = "继续  →"
	next.position = Vector2(970, 790); next.size = Vector2(130, 48)
	next.flat = true
	next.pressed.connect(advance)
	canvas.add_child(next)
	var skip := Button.new()
	skip.text = exit_label
	skip.name = "OpeningExit"
	skip.position = Vector2(500, 790); skip.size = Vector2(130, 48)
	skip.flat = true
	skip.pressed.connect(finish)
	canvas.add_child(skip)
	for button in [next, skip]:
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color("858585"))
	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(advance)
	add_child(timer)
	voice = Voice.new()
	voice.name = "OpeningNarrator"
	# Dedicated narrator keeps this voice independent from future dialogue voices.
	voice.apply_preset(&"animal_crossing")
	voice.pitch_mode = Voice.PitchMode.HASH
	voice.gain = 0.22
	voice.char_interval = CHARACTER_INTERVAL
	add_child(voice)
	music = AudioStreamPlayer.new()
	music.stream = load(data.music)
	music.volume_db = -16
	add_child(music)
	music.finished.connect(func():
		if not done: music.play())
	music.play()
	resized.connect(_layout)
	_layout()
	_show_scene()

func _layout() -> void:
	var factor := minf(size.x / 1600.0, size.y / 900.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - Vector2(1600, 900) * factor) / 2.0

func _process(delta: float) -> void:
	if done or not is_instance_valid(content): return
	elapsed += delta
	if revealed < narration.text.length():
		next_character_in -= delta
		if next_character_in <= 0:
			var character: String = narration.text[revealed]
			_reveal_to(revealed + 1, true)
			next_character_in = CHARACTER_INTERVAL
			if character == "\n": next_character_in *= 3.0
			elif Voice.is_pause(character):
				next_character_in *= voice.punctuation_pause * (1.6 if Voice.is_hard_pause(character) else 1.0)
			if revealed == narration.text.length() and automatic: timer.start(2.8)
	var opacity := clampf(elapsed / 0.65, 0.0, 1.0)
	if automatic and not timer.is_stopped():
		opacity = minf(opacity, clampf(timer.time_left / 0.65, 0.0, 1.0))
	content.modulate.a = opacity

func _show_scene() -> void:
	voice.stop()
	timer.stop()
	var scene: Dictionary = scenes[scene_index]
	if scene.has("texture"):
		picture.texture = scene.texture
	else:
		var texture := AtlasTexture.new()
		texture.atlas = load(scene.image)
		var region: Array = scene.display_region
		texture.region = Rect2(region[0], region[1], region[2], region[3])
		picture.texture = texture
	narration.text = "\n".join(scene.narration)
	narration.visible_characters = 0
	revealed = 0
	next_character_in = 0.65
	elapsed = 0.0
	content.modulate.a = 0.0

func advance() -> void:
	if done: return
	if narration.visible_characters < narration.get_total_character_count():
		voice.stop()
		_reveal_to(narration.get_total_character_count())
		elapsed = maxf(elapsed, 0.65)
		if automatic: timer.start(2.8)
		return
	if scene_index + 1 >= scenes.size(): finish(); return
	scene_index += 1
	_show_scene()

func _reveal_to(count: int, audible: bool = false) -> void:
	narration.visible_characters = count
	for index in range(revealed, count):
		if audible:
			voice.play_char(narration.text[index], index, narration.text.length())
			character_revealed.emit(narration.text[index])
	revealed = maxi(revealed, count)

func finish() -> void:
	if done: return
	done = true
	timer.stop()
	voice.stop()
	music.stop()
	if persist_completion:
		var config := ConfigFile.new()
		config.set_value("opening", "watched", true)
		save_error = config.save(preference_path)
		if save_error != OK: push_warning("序章观看记录保存失败，下次启动将重新播放。")
	finished.emit()

func _exit_tree() -> void:
	if is_instance_valid(voice): voice.stop()
	if is_instance_valid(music): music.stop()

func _input(event: InputEvent) -> void:
	if done: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode not in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_RIGHT]: return
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE: finish()
		else: advance()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event(); advance()
