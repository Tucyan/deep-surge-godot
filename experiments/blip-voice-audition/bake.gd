extends SceneTree
## 审核用音频烘焙器（不属于游戏运行时）。
##
## 用 addons/blip_voice 的合成器产出两类试听素材，全部落盘为 WAV：
##   1) 界面/战斗音效（cue）：同一个 Synth 合成器按时间轴叠音，
##      所以音色和游戏里的对白 blip 完全同源，不是另外找的素材。
##   2) 对白音色（profile）：直接用 BlipVoice.bake_line 烘一句真实文案。
##
## 运行：
##   Godot_v4.7.2-stable_win64.exe --headless --path . \
##     --script res://experiments/blip-voice-audition/bake.gd

const Voice = preload("res://addons/blip_voice/blip_voice.gd")
const OUT_DIR := "res://experiments/blip-voice-audition/output"
const SR := 44100

# 波形常量与插件 Wave 枚举一致：0 方波 / 1 锯齿 / 2 三角 / 3 正弦
const SQ := 0
const SAW := 1
const TRI := 2
const SINE := 3

## 音效走 AudioStreamPlayer 以 0 dB 播放，所以烘到接近满刻度才有正常响度；
## 对白音色则保持和 opening_intro.gd 现有旁白同一电平（增益链在插件里），两者不归一化。
const SFX_TRIM := 2.9
const VOICE_TRIM := 1.0

# ---------------------------------------------------------------------------
# 音效：notes = [[起点秒, 半音偏移, 音量倍率, 单音时长(可选)]]
# ---------------------------------------------------------------------------
const CUES := [
	{
		"id": "ui_tap", "label": "界面轻点", "group": "界面反馈",
		"desc": "最小的一次点击确认，方波短促，几乎不占听觉注意力。",
		"freq": 1050.0, "wave": SQ, "cutoff": 4200.0, "glide": 0.0, "gain": 0.18,
		"notes": [[0.0, 0.0, 1.0, 0.026]],
	},
	{
		"id": "ui_tap_soft", "label": "界面轻点 · 柔和", "group": "界面反馈",
		"desc": "三角波版本，用于高频重复操作（翻页、滚动）时避免刺耳。",
		"freq": 780.0, "wave": TRI, "cutoff": 3200.0, "glide": 0.0, "gain": 0.14,
		"notes": [[0.0, 0.0, 1.0, 0.03]],
	},
	{
		"id": "ui_confirm", "label": "确认 / 提交", "group": "界面反馈",
		"desc": "上行五度两音，表示「这一步生效了」。对应选项二次点击提交。",
		"freq": 900.0, "wave": TRI, "cutoff": 5200.0, "glide": 0.0, "gain": 0.26,
		"notes": [[0.0, 0.0, 1.0, 0.05], [0.055, 5.0, 1.0, 0.055]],
	},
	{
		"id": "ui_cancel", "label": "取消 / 退出预选", "group": "界面反馈",
		"desc": "下行四度两音，和确认形成明确的反向轮廓。",
		"freq": 820.0, "wave": SQ, "cutoff": 3400.0, "glide": 0.0, "gain": 0.22,
		"notes": [[0.0, 0.0, 1.0, 0.045], [0.05, -4.0, 1.0, 0.05]],
	},
	{
		"id": "ui_blocked", "label": "不可用 / 条件不足", "group": "界面反馈",
		"desc": "同音重复两下的闷响，只表示「没生效」，不带失败感。",
		"freq": 700.0, "wave": SAW, "cutoff": 2500.0, "glide": 0.0, "gain": 0.16,
		"notes": [[0.0, -7.0, 1.0, 0.04], [0.045, -7.0, 1.0, 0.04]],
	},
	{
		"id": "choice_preselect", "label": "选项预选", "group": "事件节点",
		"desc": "单音轻微上滑，一步动作之前的「括号提示」音，不打断阅读。",
		"freq": 880.0, "wave": SQ, "cutoff": 4600.0, "glide": 0.05, "gain": 0.22,
		"notes": [[0.0, 2.0, 1.0, 0.055]],
	},
	{
		"id": "ap_spend", "label": "消耗行动点", "group": "事件节点",
		"desc": "三连下行，短促收束，用于 AP 扣除。",
		"freq": 860.0, "wave": SQ, "cutoff": 3800.0, "glide": 0.0, "gain": 0.22,
		"notes": [[0.0, 0.0, 1.0, 0.038], [0.05, -2.0, 0.95, 0.038], [0.1, -5.0, 0.9, 0.04]],
	},
	{
		"id": "card_draw", "label": "抽牌 / 入袋", "group": "事件节点",
		"desc": "两音上行，纸牌轻挑的手感。",
		"freq": 900.0, "wave": TRI, "cutoff": 4400.0, "glide": 0.03, "gain": 0.22,
		"notes": [[0.0, 3.0, 1.0, 0.05], [0.045, 7.0, 1.0, 0.06]],
	},
	{
		"id": "relic_found", "label": "拾得遗物", "group": "事件节点",
		"desc": "四音上行琶音，最后一个音拉长，给「捡到东西」一点仪式感。",
		"freq": 760.0, "wave": TRI, "cutoff": 5000.0, "glide": 0.02, "gain": 0.26,
		"notes": [[0.0, 0.0, 1.0, 0.08], [0.07, 4.0, 0.95, 0.08], [0.14, 7.0, 0.9, 0.09], [0.23, 12.0, 0.85, 0.2]],
	},
	{
		"id": "danger_warning", "label": "危险预警", "group": "环境与战斗",
		"desc": "两次低音下滑，锯齿波、截止点压低，只提示不惊吓。",
		"freq": 320.0, "wave": SAW, "cutoff": 1800.0, "glide": 0.1, "gain": 0.28,
		"notes": [[0.0, -12.0, 1.0, 0.13], [0.18, -12.0, 0.95, 0.14]],
	},
	{
		"id": "monster_appear", "label": "遭遇怪物", "group": "环境与战斗",
		"desc": "极低频长下滑 + 上层五度短音，压出来的体积感。",
		"freq": 120.0, "wave": SAW, "cutoff": 900.0, "glide": 0.25, "gain": 0.3,
		"notes": [[0.0, 0.0, 1.0, 0.5], [0.02, 7.0, 0.45, 0.16]],
	},
	{
		"id": "battle_hit", "label": "战斗命中", "group": "环境与战斗",
		"desc": "低音短促下滑，可当作一次攻击结算的落点。",
		"freq": 220.0, "wave": SAW, "cutoff": 1600.0, "glide": 0.18, "gain": 0.3,
		"notes": [[0.0, 0.0, 1.0, 0.085], [0.01, 12.0, 0.4, 0.05]],
	},
	{
		"id": "result_good", "label": "结果 · 成功", "group": "结果结算",
		"desc": "三音上行，比确认更长，用于节点结果正向结算。",
		"freq": 820.0, "wave": TRI, "cutoff": 5200.0, "glide": 0.02, "gain": 0.26,
		"notes": [[0.0, 0.0, 1.0, 0.08], [0.07, 5.0, 0.95, 0.08], [0.14, 9.0, 0.9, 0.16]],
	},
	{
		"id": "result_bad", "label": "结果 · 失败", "group": "结果结算",
		"desc": "三音下行并压低截止点，闷而不刺，避免玩家烦躁。",
		"freq": 780.0, "wave": SQ, "cutoff": 2600.0, "glide": 0.04, "gain": 0.24,
		"notes": [[0.0, 0.0, 1.0, 0.09], [0.08, -3.0, 0.9, 0.09], [0.17, -7.0, 0.85, 0.16]],
	},
	{
		"id": "voyage_start", "label": "起航 / 进入航行", "group": "流程",
		"desc": "四音上扫，从低沉爬到开阔，用作一段流程的开头。",
		"freq": 300.0, "wave": SAW, "cutoff": 2400.0, "glide": 0.15, "gain": 0.24,
		"notes": [[0.0, -12.0, 1.0, 0.1], [0.1, -7.0, 0.95, 0.1], [0.2, -2.0, 0.9, 0.1], [0.3, 5.0, 0.85, 0.2]],
	},
	{
		"id": "victory", "label": "战斗胜利", "group": "流程",
		"desc": "大三和弦上行并收在长音上，是整套里最长的一条。",
		"freq": 700.0, "wave": TRI, "cutoff": 5400.0, "glide": 0.02, "gain": 0.28,
		"notes": [[0.0, 0.0, 1.0, 0.1], [0.09, 4.0, 0.95, 0.1], [0.18, 7.0, 0.9, 0.1], [0.3, 12.0, 0.85, 0.32]],
	},
]

# ---------------------------------------------------------------------------
# 对白音色：preset 只用来起个底，params 覆盖具体参数
# ---------------------------------------------------------------------------
const PROFILE_SAMPLES := {
	"narrator": "最初，人们以为那只是一场海啸。",
	"relic": "潮水从未退去。它把名字留在了甲板上。",
	"entity": "……你听见了吗。海面之下有人在数你的心跳。",
	"trader": "远航鱼罐，换你剩下的半瓶淡水。要,还是不要？",
	"system": "获得时饱食上限 +10，本件仅结算一次。",
	"captain": "把绳子收紧。这一点风浪还推不动我们。",
}

const PROFILES := [
	{
		"id": "narrator", "label": "旁白（序章现用，作对照）", "preset": "animal_crossing",
		"params": {"pitch_mode": Voice.PitchMode.HASH, "gain": 0.22, "char_interval": 1.0 / 12.0},
		"desc": "opening_intro.gd 第 90-93 行的现有配置，作为其余音色的音量与语速基准。",
	},
	{
		"id": "relic", "label": "遗物低语", "preset": "animal_crossing",
		"params": {
			"wave": SINE, "base_freq": 430.0, "pitch_jitter": 6.0, "declination": 5.0,
			"note_duration": 0.06, "char_interval": 0.085, "lowpass_cutoff": 1600.0,
			"glide": 0.08, "gain": 0.26, "pitch_mode": Voice.PitchMode.RANDOM,
		},
		"desc": "正弦波 + 低截止 + 大抖动，像贴着耳朵的耳语，不抢文本注意力。",
	},
	{
		"id": "entity", "label": "深海存在 / 怪物", "preset": "robot",
		"params": {
			"wave": SAW, "base_freq": 190.0, "pitch_jitter": 9.0, "declination": 8.0,
			"note_duration": 0.095, "char_interval": 0.105, "lowpass_cutoff": 1100.0,
			"glide": 0.1, "gain": 0.28, "pitch_mode": Voice.PitchMode.RANDOM,
		},
		"desc": "低频锯齿 + 明显下滑，慢而沉，用于非人说话者。",
	},
	{
		"id": "trader", "label": "商人", "preset": "chip",
		"params": {
			"wave": TRI, "base_freq": 640.0, "pitch_jitter": 2.2, "declination": 2.0,
			"note_duration": 0.05, "char_interval": 0.058, "lowpass_cutoff": 4200.0,
			"glide": 0.02, "gain": 0.26, "pitch_mode": Voice.PitchMode.HASH,
		},
		"desc": "中频三角波、语速偏快，听起来像在兜售东西。",
	},
	{
		"id": "system", "label": "系统提示", "preset": "famicom",
		"params": {
			"wave": SQ, "base_freq": 720.0, "pitch_jitter": 0.0, "declination": 0.0,
			"note_duration": 0.045, "char_interval": 0.05, "lowpass_cutoff": 6000.0,
			"glide": 0.0, "gain": 0.2, "pitch_mode": Voice.PitchMode.FIXED,
		},
		"desc": "零抖动、零降调，机械地播报规则文本；音高固定所以不会像谁在说话。",
	},
	{
		"id": "captain", "label": "船长 / 主角", "preset": "ace_attorney",
		"params": {
			"wave": SQ, "base_freq": 540.0, "pitch_jitter": 1.6, "declination": 4.0,
			"note_duration": 0.042, "char_interval": 0.056, "lowpass_cutoff": 3200.0,
			"glide": 0.02, "gain": 0.24, "pitch_mode": Voice.PitchMode.HASH,
		},
		"desc": "逆转裁判底子降到 540Hz，比旁白低一档，两个声音同屏能分开。",
	},
]

var manifest: Array = []
var peak_warn: Array = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for spec in CUES:
		_bake_cue(spec)
	for profile in PROFILES:
		_bake_profile(profile)
	_write_manifest()
	print("BAKE_DONE cues=%d profiles=%d" % [CUES.size(), PROFILES.size()])
	if not peak_warn.is_empty():
		print("PEAK_WARN ", ", ".join(peak_warn))
	quit()


func _voice_for(spec: Dictionary, note: float) -> Node:
	var voice := Voice.new()
	voice.sample_rate = SR
	voice.base_freq = float(spec["freq"])
	voice.gain = float(spec["gain"])
	voice.lowpass_cutoff = float(spec["cutoff"])
	voice.glide = float(spec["glide"])
	voice.wave = int(spec["wave"])
	voice.note_duration = note
	return voice


func _bake_cue(spec: Dictionary) -> void:
	var acc := PackedFloat32Array()
	var note_max := 0.0
	var placements: Array = []
	for entry in spec["notes"]:
		var at := float(entry[0])
		var semi := float(entry[1])
		var amp := float(entry[2])
		var note := float(entry[3]) if entry.size() > 3 else 0.04
		note_max = maxf(note_max, note)
		placements.append({"at": at, "semi": semi, "amp": amp, "note": note})
	var total := 0.0
	for p in placements:
		total = maxf(total, float(p["at"]) + float(p["note"]))
	var length: int = int((total + 0.06) * SR) + 1
	acc.resize(length)

	for index in placements.size():
		var p: Dictionary = placements[index]
		var voice := _voice_for(spec, float(p["note"]))
		var stream: AudioStreamWAV = Voice.Synth.bake(voice, 7919 + index * 131, float(p["semi"]))
		var bytes: PackedByteArray = stream.data
		var count: int = bytes.size() / 2
		var offset: int = int(float(p["at"]) * SR)
		var amp := float(p["amp"]) * SFX_TRIM
		for i in count:
			var idx := offset + i
			if idx >= length:
				break
			acc[idx] += float(bytes.decode_s16(i * 2)) / 32768.0 * amp
		voice.free()

	_save(acc, "sfx_" + str(spec["id"]), {
		"id": spec["id"], "kind": "sfx", "label": spec["label"],
		"group": spec["group"], "desc": spec["desc"],
		"params": {
			"base_freq": spec["freq"], "wave": spec["wave"],
			"lowpass_cutoff": spec["cutoff"], "glide": spec["glide"], "gain": spec["gain"],
		},
	})


func _bake_profile(profile: Dictionary) -> void:
	var voice := Voice.new()
	voice.sample_rate = SR
	voice.apply_preset(StringName(profile["preset"]))
	for key in profile["params"]:
		voice.set(key, profile["params"][key])
	var text: String = PROFILE_SAMPLES[profile["id"]]
	var stream: AudioStreamWAV = Voice.bake_line(voice, text)
	var bytes: PackedByteArray = stream.data
	var count: int = bytes.size() / 2
	var acc := PackedFloat32Array()
	acc.resize(count)
	for i in count:
		acc[i] = float(bytes.decode_s16(i * 2)) / 32768.0 * VOICE_TRIM
	var params := {}
	for key in profile["params"]:
		params[key] = profile["params"][key]
	_save(acc, "voice_" + str(profile["id"]), {
		"id": profile["id"], "kind": "voice", "label": profile["label"],
		"group": "对白音色", "desc": profile["desc"], "sample": text,
		"preset": profile["preset"], "params": params,
		"char_interval": voice.char_interval,
	})
	voice.free()


func _save(acc: PackedFloat32Array, file_stem: String, meta: Dictionary) -> void:
	# 结尾 6ms 淡出，避免截断成爆音
	var fade: int = mini(int(0.006 * SR), acc.size())
	for i in fade:
		acc[acc.size() - 1 - i] *= float(i) / float(fade)

	var peak := 0.0
	for v in acc:
		peak = maxf(peak, absf(v))
	var scale := 1.0
	if peak > 0.98:
		scale = 0.98 / peak
		peak_warn.append(file_stem)

	var out := PackedByteArray()
	out.resize(acc.size() * 2)
	for i in acc.size():
		out.encode_s16(i * 2, int(round(clampf(acc[i] * scale, -1.0, 1.0) * 32767.0)))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SR
	stream.stereo = false
	stream.data = out
	var path := ProjectSettings.globalize_path(OUT_DIR.path_join(file_stem + ".wav"))
	var error := stream.save_to_wav(path)
	if error != OK:
		push_error("保存失败 %s (%d)" % [path, error])
		return

	var entry := meta.duplicate(true)
	entry["file"] = "output/" + file_stem + ".wav"
	entry["duration"] = snappedf(float(acc.size()) / float(SR), 0.001)
	entry["peak"] = snappedf(peak * scale, 0.001)
	manifest.append(entry)


func _write_manifest() -> void:
	var payload := {
		"generated_by": "experiments/blip-voice-audition/bake.gd",
		"plugin": "addons/blip_voice",
		"sample_rate": SR,
		"cues": CUES.size(),
		"profiles": PROFILES.size(),
		"items": manifest,
	}
	var path := ProjectSettings.globalize_path(OUT_DIR.path_join("manifest.json"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("manifest 写入失败")
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
