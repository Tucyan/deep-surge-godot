extends Node
## Non-diegetic background music.
##
## Reads only the public run summary needed to pick a cue (screen, phase and the
## boss flag of the current node); it never writes session state, never touches
## the rules random stream and never replays a resolved outcome. Missing tracks
## fall back along the cue table instead of failing the game.
signal cue_changed(cue: String)

const CONFIG_PATH := "res://assets/music/music.json"
const SILENT_DB := -80.0
const MAX_FALLBACK_DEPTH := 4
const SUSPENSION_POLL := 0.25

var cues: Dictionary = {}
var fade_seconds := 1.5
var trim_db := -6.0
var cue := ""
var volume := 0.6
var enabled := true
var suspended := false
var error := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _active_path := ""
var _streams: Dictionary = {}
var _ramps: Dictionary = {}   # player instance id -> running crossfade
var _app: Object
var _poll := 0.0

func _ready() -> void:
	name = "MusicDirector"
	load_config()
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicTrackA" if index == 0 else "MusicTrackB"
		player.volume_db = SILENT_DB
		player.finished.connect(_on_track_finished.bind(index))
		add_child(player)
		_players.append(player)
	set_process(true)

func load_config() -> void:
	cues = {}
	if not FileAccess.file_exists(CONFIG_PATH):
		error = "音乐配置缺失：" + CONFIG_PATH
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary or not parsed.get("cues") is Dictionary:
		error = "音乐配置格式错误：" + CONFIG_PATH
		return
	error = ""
	cues = parsed.cues
	fade_seconds = maxf(0.0, float(parsed.get("fade_seconds", fade_seconds)))
	trim_db = float(parsed.get("trim_db", trim_db))

## Cue rules are pure so layout, rules and tests share one definition.
static func cue_for(screen: String, phase: String, boss: bool) -> String:
	if screen == "home" or phase in ["finished", "chapterComplete"]: return "home"
	if boss and phase in ["preparation", "battle"]: return "boss"
	return "voyage"

## Linear volume to bus decibels; muted, silenced and zero-volume all go silent.
static func volume_db_for(value: float, on: bool, quiet: bool, trim: float = 0.0) -> float:
	if not on or quiet or value <= 0.0: return SILENT_DB
	return linear_to_db(clampf(value, 0.0, 1.0)) + trim

func apply_preferences(value: float, on: bool) -> void:
	volume = clampf(value, 0.0, 1.0)
	enabled = on
	_refresh_volume()

func set_suspended(value: bool) -> void:
	if suspended == value: return
	suspended = value
	_refresh_volume()

## The app is only read here: one projection-free summary, then a cue decision.
func sync(app: Object) -> void:
	_app = app
	var screen := "home"
	var phase := ""
	var boss := false
	var session: Variant = app.get("session") if is_instance_valid(app) else null
	if is_instance_valid(session):
		screen = str(session.screen)
		phase = str(session.phase())
		var node: Variant = session.state.get("node", {})
		if node is Dictionary: boss = bool(node.get("boss", false))
	set_suspended(is_instance_valid(app) and is_instance_valid(app.get("story_replay")))
	play_cue(cue_for(screen, phase, boss))

func resolve_tracks(cue_name: String, depth: int = 0) -> Array:
	if depth > MAX_FALLBACK_DEPTH or not cues.has(cue_name): return []
	var entry: Variant = cues[cue_name]
	if not entry is Dictionary: return []
	var tracks: Array = []
	for path in entry.get("tracks", []):
		if path is String and stream_for(path) != null: tracks.append(path)
	if not tracks.is_empty(): return tracks
	var fallback := str(entry.get("fallback", ""))
	if fallback == "" or fallback == cue_name: return []
	return resolve_tracks(fallback, depth + 1)

func play_cue(target: String) -> void:
	var tracks := resolve_tracks(target)
	if tracks.is_empty():
		if cue != "": cue = ""; _active_path = ""; _fade_out_all()
		return
	var path := str(tracks[0])
	if target == cue and path == _active_path and is_playing(): return
	cue = target
	_switch(path)

func stream_for(path: String) -> AudioStream:
	if _streams.has(path): return _streams[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is AudioStream: stream = loaded
	# MP3/OGG importers keep loop off by default; looping is a runtime contract.
	if stream != null and "loop" in stream: stream.loop = true
	_streams[path] = stream
	return stream

func active_path() -> String:
	return _active_path

func is_playing() -> bool:
	return not _players.is_empty() and _players[_active].playing and _players[_active].stream != null

func current_db() -> float:
	return SILENT_DB if _players.is_empty() else _players[_active].volume_db

func _switch(path: String) -> void:
	var stream := stream_for(path)
	if stream == null or _players.size() < 2: return
	var incoming := 1 - _active
	if _players[incoming].stream != stream: _players[incoming].stream = stream
	_players[incoming].play()
	_active = incoming
	_active_path = path
	for index in range(_players.size()):
		_ramp(_players[index], _target_db() if index == _active else SILENT_DB, fade_seconds)
	cue_changed.emit(cue)

func _refresh_volume() -> void:
	if _players.is_empty(): return
	_ramp(_players[_active], _target_db(), minf(fade_seconds, 0.3))

func _fade_out_all() -> void:
	for player in _players: _ramp(player, SILENT_DB, fade_seconds)

func _target_db() -> float:
	return volume_db_for(volume, enabled, suspended, trim_db)

func _ramp(player: AudioStreamPlayer, db: float, seconds: float) -> void:
	var key := player.get_instance_id()
	if _ramps.has(key):
		var running: Variant = _ramps[key]
		if running is Tween and running.is_valid(): running.kill()
		_ramps.erase(key)
	if seconds <= 0.0 or not is_inside_tree():
		player.volume_db = db
		return
	var tween := create_tween()
	_ramps[key] = tween
	tween.tween_property(player, "volume_db", db, seconds)

func _on_track_finished(index: int) -> void:
	# Looping streams never emit; this only recovers a stream without loop support.
	if index == _active and _active_path != "": _players[index].play()

func _process(delta: float) -> void:
	# Gallery replays open without a layout render; keep the director honest.
	if not is_instance_valid(_app): return
	_poll += delta
	if _poll < SUSPENSION_POLL: return
	_poll = 0.0
	set_suspended(is_instance_valid(_app.get("story_replay")))

func _exit_tree() -> void:
	# Releasing live playbacks keeps shutdown clean: MP3 decoders hold references.
	for player in _players:
		player.stop()
		player.stream = null
	_streams.clear()
	_ramps.clear()
