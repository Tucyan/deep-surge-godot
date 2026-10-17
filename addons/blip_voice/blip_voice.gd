@tool
class_name BlipVoice
extends Node
## 对话逐字电子语音音效（逆转裁判那种「哔哔哔」）。
##
## 三种用法，按省事程度排：
##   1. 全局单例（插件启用后自动注册，名字叫 Blips）
##        Blips.speak("异议！这句证词和现场情况完全矛盾！")
##   2. 接你自己的打字机 —— 每显示一个字调一次：
##        Blips.play_char(ch, index, total)
##   3. 让 RichTextLabel 自己响（打字机逻辑一行都不用改）：
##        Blips.watch($RichTextLabel)
##
## 也可以把这个节点直接拖进场景，给每个角色配一份独立参数。
##
## 本文件是插件的全部实现：参数、合成器（内部类 Synth）、
## 编辑器试听面板（内部类 Dock）、插件安装入口（install/uninstall）。

enum Wave { SQUARE, SAW, TRIANGLE, SINE }
enum PitchMode { RANDOM, HASH, FIXED }

const AUTOLOAD_NAME := "Blips"
const AUTOLOAD_PATH := "res://addons/blip_voice/blip_voice.gd"
const PAUSE_CHARS := "，。！？；：、,.!?;:…—～~"
const HARD_PAUSE_CHARS := "。！？.!?…"

## 一整句读完了（speak() 专用）
signal line_finished()

# ============================== 参数 ==============================
# 默认值 = 「逆转裁判 · 对白电子音」。改任何一个都会立刻重新烘焙波形。

@export_group("音高")
## 基础频率。900 左右接近逆转裁判那种偏高的电子音，500 更软，300 更低沉。
@export_range(80.0, 1800.0, 10.0) var base_freq: float = 900.0:
	set(value):
		base_freq = value
		_invalidate()
## 每个字的音高随机范围（半音）。0 = 完全平；8 以上像机器人在嘟囔。
@export_range(0.0, 12.0, 0.1) var pitch_jitter: float = 0.4:
	set(value):
		pitch_jitter = value
		_invalidate()
## 越到句尾音越低（说话语调下垂）。
@export_range(0.0, 12.0, 0.5) var declination: float = 3.0:
	set(value):
		declination = value
		_invalidate()
## 随机 / 同一个字永远同一个音 / 完全一致
@export_enum("随机", "按字固定", "完全一致") var pitch_mode: int = PitchMode.HASH:
	set(value):
		pitch_mode = value
		_invalidate()

@export_group("时值")
## 单个音的长度，30~90ms。调长会变成琴键而不是说话 —— 最大的坑。
@export_range(0.01, 0.2, 0.001) var note_duration: float = 0.038:
	set(value):
		note_duration = value
		_invalidate()
## 字与字的间隔，决定「说话速度」。
@export_range(0.02, 0.4, 0.001) var char_interval: float = 0.052:
	set(value):
		char_interval = value
		_invalidate()
## 标点处的停顿倍率（句号、问号会再额外 ×1.6）。
@export_range(1.0, 6.0, 0.1) var punctuation_pause: float = 2.5:
	set(value):
		punctuation_pause = value
		_invalidate()
## 每秒最多触发几次，防止多个角色同时说话糊成一片。0 = 不限制。
@export_range(0.0, 30.0, 0.5) var max_blips_per_second: float = 0.0:
	set(value):
		max_blips_per_second = value
		_invalidate()

@export_group("音色")
## 方波最像；锯齿波更电子；三角波更软
@export_enum("方波", "锯齿波", "三角波", "正弦波") var wave: int = Wave.SQUARE:
	set(value):
		wave = value
		_invalidate()
## 低通截止频率，越低越闷。纯方波不削高频会刺耳，建议 3k~6k。
@export_range(300.0, 16000.0, 50.0) var lowpass_cutoff: float = 5000.0:
	set(value):
		lowpass_cutoff = value
		_invalidate()
## 音量（线性增益）
@export_range(0.0, 1.0, 0.01) var gain: float = 0.32:
	set(value):
		gain = value
		_invalidate()
## 音内部的下滑比例。一点点就有「嘟↓」的口吻。
@export_range(0.0, 0.4, 0.01) var glide: float = 0.02:
	set(value):
		glide = value
		_invalidate()
## 预烘焙几个音色微变的变体，避免连续同音听起来像机关枪。
@export_range(1, 24, 1) var variants: int = 12:
	set(value):
		variants = value
		_invalidate()
@export var sample_rate: int = 44100:
	set(value):
		sample_rate = value
		_invalidate()

@export_group("播放")
## 播放器池大小。连续触发时轮流用，避免互相打断。
@export_range(1, 16, 1) var player_pool: int = 6:
	set(value):
		player_pool = value
		if _pool_ready:
			_build_pool()
## 输出到哪条音频总线（可以单独给对白做一条总线，方便统一调音量 / 加混响）
@export var bus: StringName = &"Master":
	set(value):
		bus = value
		for p in _players:
			if is_instance_valid(p):
				p.bus = value

var _streams: Array[AudioStreamWAV] = []
var _players: Array[AudioStreamPlayer] = []
var _watched: Array[RichTextLabel] = []
var _seen: Dictionary = {}
var _next: int = 0
var _speaking: bool = false
var _last_blip_ms: int = 0
var _pool_ready: bool = false
var _batched: bool = false


func _ready() -> void:
	set_process(false)
	_build_pool()
	_pool_ready = true
	rebuild()


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	for label in _watched.duplicate():
		if is_instance_valid(label):
			_scan_label(label)


# ============================ 播放接口 ============================

## 敲一声。semitone 是相对基础音高的偏移（可为负）。
func play_blip(semitone: float = 0.0) -> void:
	if _streams.is_empty() or _players.is_empty():
		return
	if not _passes_throttle():
		return
	var stream := _streams[_next % _streams.size()]
	var player := _players[_next % _players.size()]
	_next += 1
	player.stream = stream
	player.pitch_scale = clampf(pow(2.0, semitone / 12.0), 0.06, 4.0)
	player.play()


## 按字符敲一声 —— 接你自己的打字机时最常用的入口。
## 空白和标点会自动跳过（标点的停顿交给你的打字机节奏控制）。
func play_char(ch: String, index: int = 0, total: int = 0) -> void:
	if not speaks(ch):
		return
	play_blip(semitones_for(ch, index, total))


## 自动逐字「说话」。协程，重复调用会打断上一次。
## 需要知道「说完了」就接 line_finished 信号。
func speak(text: String) -> void:
	stop()
	if text.is_empty():
		line_finished.emit()
		return
	_speaking = true
	var total: int = text.length()
	var interval: float = maxf(0.005, char_interval)
	var wait := 0.0

	for i in total:
		if not _speaking:
			return
		var ch: String = text[i]
		if ch == "\n":
			wait += interval * 3.0
			continue
		if not speaks(ch):
			if is_pause(ch):
				wait += interval * punctuation_pause * (1.6 if is_hard_pause(ch) else 1.0)
			else:
				wait += interval
			continue
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
			wait = 0.0
			if not _speaking:
				return
		play_blip(semitones_for(ch, i, total))
		await get_tree().create_timer(interval).timeout

	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	if _speaking:
		_speaking = false
		line_finished.emit()


func stop() -> void:
	_speaking = false
	for p in _players:
		if is_instance_valid(p):
			p.stop()


func is_speaking() -> bool:
	return _speaking


# ====================== 打字机联动（watch） ======================

## 盯住一个 RichTextLabel，之后它每多露出一个字就会自动响一声。
## 用的是 visible_characters + get_parsed_text()，所以 BBCode 标签不会算错位。
func watch(label: RichTextLabel) -> void:
	if label == null or _watched.has(label):
		return
	_watched.append(label)
	_seen[label] = label.visible_characters
	set_process(true)


func unwatch(label: RichTextLabel) -> void:
	_watched.erase(label)
	_seen.erase(label)
	if _watched.is_empty():
		set_process(false)


func unwatch_all() -> void:
	_watched.clear()
	_seen.clear()
	set_process(false)


func _scan_label(label: RichTextLabel) -> void:
	var v := label.visible_characters
	var last: int = _seen.get(label, -1)
	if v < 0:
		_seen[label] = -1
		return
	if last < 0 or v <= last:
		_seen[label] = v
		return
	var parsed := label.get_parsed_text()
	var total := parsed.length()
	var stop_at: int = mini(v, total)
	for i in range(last, stop_at):
		var ch := parsed[i]
		if speaks(ch):
			play_blip(semitones_for(ch, i, total))
	_seen[label] = v


# ============================ 音高计算 ============================

## 某个字符该用多高的音（相对基础音高的半音偏移）。
## 实时播放、离线烘焙、编辑器试听共用这一个函数，三处听感一定一致。
func semitones_for(ch: String, index: int, total: int) -> float:
	var semi := 0.0
	match pitch_mode:
		PitchMode.RANDOM:
			semi = randf_range(-pitch_jitter, pitch_jitter)
		PitchMode.HASH:
			semi = (float(absi(hash(ch)) % 1000) / 1000.0 * 2.0 - 1.0) * pitch_jitter
		_:
			semi = 0.0
	var pos: float = float(index) / float(maxi(1, total - 1))
	return semi - declination * pos


static func is_silent(ch: String) -> bool:
	return ch.strip_edges().is_empty()


static func is_pause(ch: String) -> bool:
	return not ch.is_empty() and PAUSE_CHARS.contains(ch)


static func is_hard_pause(ch: String) -> bool:
	return not ch.is_empty() and HARD_PAUSE_CHARS.contains(ch)


## 这个字符应不应该发出一声 blip
static func speaks(ch: String) -> bool:
	return not is_silent(ch) and not is_pause(ch)


# ============================ 烘焙 / 池 ============================

## 参数改过之后重新烘焙波形。直接改 config 再调它也行。
func rebuild() -> void:
	if _players.is_empty():
		return
	_streams.clear()
	var count: int = maxi(1, variants)
	for i in count:
		_streams.append(Synth.bake(self, 1001 + i * 7919))
	_next = 0


func _invalidate() -> void:
	if _pool_ready and not _batched:
		rebuild()


func _build_pool() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	for i in maxi(1, player_pool):
		var player := AudioStreamPlayer.new()
		player.name = "BlipPlayer%d" % i
		player.bus = bus
		player.set_meta("_edit_internal", true)
		add_child(player)
		_players.append(player)


func _passes_throttle() -> bool:
	if max_blips_per_second <= 0.0:
		return true
	var now := Time.get_ticks_msec()
	var gap: int = int(1000.0 / max_blips_per_second)
	if now - _last_blip_ms < gap:
		return false
	_last_blip_ms = now
	return true


# ============================ 预设音色 ============================

static func preset_ids() -> Array[StringName]:
	return [&"ace_attorney", &"animal_crossing", &"famicom", &"robot", &"chip"]


static func preset_label(id: StringName) -> String:
	match id:
		&"animal_crossing":
			return "动物森友会 · 软糯动物语"
		&"famicom":
			return "红白机 · 复古字音"
		&"robot":
			return "机械腔 · 机器人"
		&"chip":
			return "清脆小萌音"
		_:
			return "逆转裁判 · 对白电子音"


static func preset_values(id: StringName) -> Dictionary:
	match id:
		&"animal_crossing":
			return {
				"base_freq": 520.0, "pitch_jitter": 4.0, "declination": 2.0,
				"note_duration": 0.058, "char_interval": 0.064, "lowpass_cutoff": 3400.0,
				"wave": Wave.SQUARE, "pitch_mode": PitchMode.RANDOM, "gain": 0.30,
			}
		&"famicom":
			return {
				"base_freq": 660.0, "pitch_jitter": 1.2, "declination": 0.0,
				"note_duration": 0.062, "char_interval": 0.072, "lowpass_cutoff": 6500.0,
				"wave": Wave.SQUARE, "pitch_mode": PitchMode.HASH, "gain": 0.30,
			}
		&"robot":
			return {
				"base_freq": 300.0, "pitch_jitter": 8.0, "declination": 6.0,
				"note_duration": 0.085, "char_interval": 0.092, "lowpass_cutoff": 2000.0,
				"wave": Wave.SAW, "pitch_mode": PitchMode.RANDOM, "glide": 0.06, "gain": 0.30,
			}
		&"chip":
			return {
				"base_freq": 760.0, "pitch_jitter": 5.0, "declination": 4.0,
				"note_duration": 0.070, "char_interval": 0.078, "lowpass_cutoff": 3000.0,
				"wave": Wave.TRIANGLE, "pitch_mode": PitchMode.RANDOM, "glide": 0.03, "gain": 0.28,
			}
		_:
			return {
				"base_freq": 900.0, "pitch_jitter": 0.4, "declination": 3.0,
				"note_duration": 0.038, "char_interval": 0.052, "lowpass_cutoff": 5000.0,
				"wave": Wave.SQUARE, "pitch_mode": PitchMode.HASH, "glide": 0.02, "gain": 0.32,
			}


func apply_preset(id: StringName) -> void:
	_batched = true
	var values := preset_values(id)
	for key in values:
		set(key, values[key])
	_batched = false
	rebuild()


## 把整段文本离线烘焙成一整条音频（做语音回放 / 导出成品用，实时打字不需要它）
static func bake_line(voice, text: String) -> AudioStreamWAV:
	var sr: int = maxi(8000, voice.sample_rate)
	var interval: float = maxf(0.005, voice.char_interval)
	var total: int = text.length()
	var cursor := 0.0
	var wait := 0.0
	var placements: Array = []

	for i in total:
		var ch: String = text[i]
		if ch == "\n":
			wait += interval * 3.0
			continue
		if not speaks(ch):
			if is_pause(ch):
				wait += interval * voice.punctuation_pause * (1.6 if is_hard_pause(ch) else 1.0)
			else:
				wait += interval
			continue
		cursor += wait
		wait = 0.0
		placements.append({"at": cursor, "semi": voice.semitones_for(ch, i, total)})
		cursor += interval

	if placements.is_empty():
		return null

	var length: int = int((cursor + maxf(0.01, voice.note_duration)) * sr) + 1
	var acc := PackedFloat32Array()
	acc.resize(length)

	for k in placements.size():
		var p: Dictionary = placements[k]
		var stream: AudioStreamWAV = Synth.bake(voice, 1001 + k * 7919, float(p["semi"]))
		var bytes: PackedByteArray = stream.data
		var count: int = bytes.size() / 2
		var offset: int = int(p["at"] * sr)
		for i in count:
			var idx := offset + i
			if idx >= length:
				break
			acc[idx] += float(bytes.decode_s16(i * 2)) / 32768.0

	var out := PackedByteArray()
	out.resize(length * 2)
	for i in length:
		out.encode_s16(i * 2, int(round(clampf(acc[i], -1.0, 1.0) * 32767.0)))

	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = sr
	result.stereo = false
	result.data = out
	return result


# ========================== 插件安装入口 ==========================
# plugin.gd 只有几行，把这两个函数接到编辑器生命周期上。

## 注意 ep 故意不加类型标注：EditorPlugin 是编辑器专有类，
## 导出的游戏里没有它，一旦写成类型提示，这个文件在发布版里就加载不了。
static func install(ep) -> void:
	# 1) 注册全局单例 Blips
	var key := "autoload/" + AUTOLOAD_NAME
	if not ProjectSettings.has_setting(key):
		ep.add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		print("[Blip Voice] 已注册全局单例 Blips。脚本里直接写 Blips.speak(\"异议！\") 即可。")
	elif str(ProjectSettings.get_setting(key)).replace("*", "") != AUTOLOAD_PATH:
		push_warning("[Blip Voice] 已存在名为 %s 的 Autoload，插件不会覆盖它。" % AUTOLOAD_NAME)

	# 2) 挂上编辑器底部的试听面板
	var dock := Dock.new()
	dock.name = "BlipVoiceDock"
	var voice := BlipVoice.new()
	voice.name = "PreviewVoice"
	dock.add_child(voice)
	var ids := preset_ids()
	var labels: Array = []
	for id in ids:
		labels.append(preset_label(id))
	dock.setup(voice, ids, labels)
	ep.add_control_to_bottom_panel(dock, "Blip Voice")
	ep.set_meta("blip_voice_dock", dock)


static func uninstall(ep) -> void:
	var dock = ep.get_meta("blip_voice_dock", null)
	if dock is Control:
		ep.remove_control_from_bottom_panel(dock)
		dock.queue_free()
	ep.remove_meta("blip_voice_dock")
	# 只删掉「本来就是本插件加的那一个」，不动用户自己配的单例
	var key := "autoload/" + AUTOLOAD_NAME
	if ProjectSettings.has_setting(key):
		if str(ProjectSettings.get_setting(key)).replace("*", "") == AUTOLOAD_PATH:
			ep.remove_autoload_singleton(AUTOLOAD_NAME)


# ============================ 内部类 ============================

## 波形合成器。全部静态函数，不依赖任何外部素材。
class Synth extends RefCounted:
	# 与外面 Wave 枚举的顺序保持一致：方波 / 锯齿 / 三角 / 正弦
	const W_SQUARE := 0
	const W_SAW := 1
	const W_TRIANGLE := 2
	const W_SINE := 3
	const TAU_F := 6.283185307179586

	## 烘焙一个「音」。semitone 是相对基础音高的偏移，seed 决定音色的细微差异。
	static func bake(voice, variant_seed: int, semitone: float = 0.0) -> AudioStreamWAV:
		var sr: int = maxi(8000, voice.sample_rate)
		var note: float = maxf(0.01, voice.note_duration)
		var samples: int = maxi(16, int(sr * note))

		var rng := RandomNumberGenerator.new()
		rng.seed = variant_seed
		# 每个变体在音高、音量、脉冲宽度上各有一点偏差，听感才不呆板
		var freq: float = voice.base_freq * pow(2.0, semitone / 12.0) * rng.randf_range(0.985, 1.015)
		var amp: float = voice.gain * rng.randf_range(0.9, 1.0)
		var pulse: float = rng.randf_range(0.45, 0.55)
		var sustain: float = rng.randf_range(0.88, 1.0)

		var attack: float = clampf(note * 0.12, 0.0006, 0.006)
		var decay_k: float = 3.0 / maxf(0.004, note * 0.45)
		# 一阶低通，alpha 越大越通透
		var alpha: float = 1.0 - exp(-TAU_F * voice.lowpass_cutoff / float(sr))
		var tail_len: float = maxf(0.002, note * 0.2)

		var bytes := PackedByteArray()
		bytes.resize(samples * 2)

		var phase := 0.0
		var lp := 0.0
		for i in samples:
			var t := float(i) / float(sr)

			# 包络：极快起音 + 指数衰减 + 尾巴淡出（不淡出会有爆音）
			var env: float
			if t < attack:
				env = t / attack
			else:
				env = exp(-(t - attack) * decay_k) * sustain
			env *= clampf((note - t) / tail_len, 0.0, 1.0)

			# 音内部的下滑（glide），0 就是平直
			var pitch_now: float = freq * lerpf(1.0, 1.0 - voice.glide, t / note)
			var raw: float = _wave(voice.wave, phase, pulse)
			phase = fmod(phase + TAU_F * pitch_now / float(sr), TAU_F)

			lp += alpha * (raw - lp)
			var v: float = clampf(lp * env * amp, -1.0, 1.0)
			bytes.encode_s16(i * 2, int(round(v * 32767.0)))

		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = sr
		stream.stereo = false
		stream.data = bytes
		return stream

	static func _wave(kind: int, phase: float, pulse: float) -> float:
		if kind == W_SAW:
			return (phase / TAU_F) * 2.0 - 1.0
		if kind == W_TRIANGLE:
			return absf((phase / TAU_F) * 2.0 - 1.0) * 2.0 - 1.0
		if kind == W_SINE:
			return sin(phase)
		return 1.0 if phase < TAU_F * pulse else -1.0


## 编辑器底部的试听面板。选预设 -> 填一句话 -> 试听。
## 它自己不合成也不播放，全部甩给一个隐藏的 BlipVoice 子节点，
## 所以试听和游戏里听到的绝对是同一套代码。
class Dock extends VBoxContainer:
	var _voice
	var _ids: Array = []
	var _labels: Array = []
	var _option: OptionButton
	var _text: LineEdit
	var _status: Label

	func setup(voice, ids: Array, labels: Array) -> void:
		_voice = voice
		_ids = ids
		_labels = labels

	func _ready() -> void:
		add_theme_constant_override("separation", 6)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)

		var caption := Label.new()
		caption.text = "音色预设"
		row.add_child(caption)

		_option = OptionButton.new()
		for text in _labels:
			_option.add_item(str(text))
		_option.item_selected.connect(_on_preset_selected)
		row.add_child(_option)

		var play_btn := Button.new()
		play_btn.text = "试听"
		play_btn.pressed.connect(_audition)
		row.add_child(play_btn)

		var stop_btn := Button.new()
		stop_btn.text = "停止"
		stop_btn.pressed.connect(_stop)
		row.add_child(stop_btn)

		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 8)
		add_child(row2)

		var caption2 := Label.new()
		caption2.text = "测试文本"
		row2.add_child(caption2)

		_text = LineEdit.new()
		_text.text = "异议！这句证词和现场情况完全矛盾！"
		_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_text.text_submitted.connect(func(_t: String) -> void: _audition())
		row2.add_child(_text)

		_status = Label.new()
		_status.add_theme_font_size_override("font_size", 11)
		_status.modulate = Color(1.0, 1.0, 1.0, 0.65)
		add_child(_status)

		if _option.item_count > 0:
			_option.selected = 0
			_on_preset_selected(0)

	func _on_preset_selected(index: int) -> void:
		if _voice == null or index < 0 or index >= _ids.size():
			return
		var id: StringName = _ids[index]
		_voice.apply_preset(id)
		_status.text = "已加载：%s｜运行时用 Blips.apply_preset(&\"%s\") 切换" % [
			str(_labels[index]), id
		]

	func _audition() -> void:
		if _voice == null:
			return
		var text := _text.text
		if text.strip_edges().is_empty():
			text = "异议！这句证词和现场情况完全矛盾！"
		_voice.speak(text)

	func _stop() -> void:
		if _voice != null:
			_voice.stop()
