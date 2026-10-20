extends Node
## Continuous sea ambience. Local presentation only: it never writes the
## session, never touches the rules random stream and never picks a cue.
## The loop keeps running while the music cue changes underneath it.

const CONFIG_PATH := "res://assets/audio/ambience.json"
const SILENT_DB := -80.0

var volume := 0.6
var enabled := true
var suspended := false
var trim_db := -16.0
var fade_seconds := 2.0
var error := ""
var tracks: Array = []
var _player: AudioStreamPlayer
var _stream: AudioStream
var _tween: Tween

func _ready() -> void:
	name = "AmbienceDirector"
	load_config()
	_player = AudioStreamPlayer.new()
	_player.name = "AmbienceTrack"
	_player.volume_db = SILENT_DB
	add_child(_player)
	_start()

func load_config() -> void:
	tracks = []
	error = ""
	if not FileAccess.file_exists(CONFIG_PATH):
		error = "环境音配置缺失：" + CONFIG_PATH
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary:
		error = "环境音配置格式错误：" + CONFIG_PATH
		return
	var listed: Variant = parsed.get("tracks", [])
	if listed is Array: tracks = listed
	trim_db = float(parsed.get("trim_db", trim_db))
	fade_seconds = maxf(0.0, float(parsed.get("fade_seconds", fade_seconds)))

## Volume and mute come from the same local audio preferences as the music.
func apply_preferences(value: float, on: bool) -> void:
	volume = clampf(value, 0.0, 1.0)
	enabled = on
	_refresh()

func set_suspended(value: bool) -> void:
	if suspended == value: return
	suspended = value
	_refresh()

## The app is only read here: an open gallery replay keeps the sea quiet.
func sync(app: Object) -> void:
	set_suspended(is_instance_valid(app) and is_instance_valid(app.get("story_replay")))

func is_playing() -> bool:
	return _player != null and _player.playing and _player.stream != null

func current_db() -> float:
	return SILENT_DB if _player == null else _player.volume_db

## Linear volume to bus decibels; muted, silenced and zero-volume all go silent.
func target_db() -> float:
	if not enabled or suspended or volume <= 0.0: return SILENT_DB
	return linear_to_db(clampf(volume, 0.0, 1.0)) + trim_db

func _start() -> void:
	if tracks.is_empty() or _player == null: return
	var path := str(tracks[0])
	if not ResourceLoader.exists(path):
		error = "环境音文件缺失：" + path
		return
	var loaded: Resource = load(path)
	if not loaded is AudioStream:
		error = "环境音格式不受支持：" + path
		return
	_stream = loaded
	# OGG importers keep loop off by default; looping is a runtime contract.
	if "loop" in _stream: _stream.loop = true
	_player.stream = _stream
	_player.play()
	_refresh()

func _refresh() -> void:
	if _player == null: return
	_ramp(target_db(), minf(fade_seconds, 0.3))

func _ramp(db: float, seconds: float) -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	if seconds <= 0.0 or not is_inside_tree():
		_player.volume_db = db
		return
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", db, seconds)

func _on_track_finished() -> void:
	# Looping streams never emit; this only recovers a stream without loop support.
	if _player != null and _player.stream != null: _player.play()

func _exit_tree() -> void:
	if _player != null:
		_player.stop()
		_player.stream = null
