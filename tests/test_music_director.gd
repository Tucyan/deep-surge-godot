extends SceneTree
## Music contract: cue rules, fallback when a track is missing, volume/mute maths
## and local preference round-trip. Headless still exercises the real players.
var failures := 0
const Director = preload("res://presentation/music_director.gd")
const Display = preload("res://presentation/display_settings.gd")

## Minimal stand-ins so the real director reads the same summary shape as the app.
class StubSession:
	var screen := "game"
	var phase_name := "battle"
	var state := {"node": {"boss": true}}
	func phase() -> String: return phase_name

class StubApp:
	var session = StubSession.new()
	var story_replay = null

func _init() -> void: call_deferred("run")

func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)

func run() -> void:
	check(Director.cue_for("home", "", false) == "home", "Title uses the home cue")
	check(Director.cue_for("game", "finished", false) == "home", "Settlement returns to the home cue")
	check(Director.cue_for("game", "chapterComplete", false) == "home", "Chapter stop returns to the home cue")
	check(Director.cue_for("game", "battle", false) == "voyage", "Ordinary battle keeps the voyage cue")
	check(Director.cue_for("game", "battle", true) == "boss", "Boss battle uses the boss cue")
	check(Director.cue_for("game", "preparation", true) == "boss", "Boss preparation starts the boss cue")
	check(Director.cue_for("game", "navigation", true) == "voyage", "Boss flag alone does not switch the cue")
	check(Director.cue_for("story", "story", false) == "voyage", "Story pages keep the voyage cue")

	check(is_equal_approx(Director.volume_db_for(0.6, true, false, -6.0), linear_to_db(0.6) - 6.0), "Volume maps to linear decibels")
	check(Director.volume_db_for(0.6, false, false, -6.0) == Director.SILENT_DB, "Mute silences the player")
	check(Director.volume_db_for(0.0, true, false, -6.0) == Director.SILENT_DB, "Zero volume silences the player")
	check(Director.volume_db_for(0.6, true, true, -6.0) == Director.SILENT_DB, "Suspension silences the player")

	var music = Director.new()
	root.add_child(music)
	await process_frame
	check(music.error.is_empty(), "Music configuration loads: " + music.error)
	music.fade_seconds = 0.0
	var aria := "res://assets/music/daily-arsnova-bwv82-aria-v1.mp3"
	var fuga := "res://assets/music/daily-arsnova-bwv578-fuga-v1.mp3"
	var home_tracks: Array = music.resolve_tracks("home")
	var voyage_tracks: Array = music.resolve_tracks("voyage")
	check(home_tracks == [aria], "Home cue resolves the aria")
	check(voyage_tracks == [fuga], "Voyage cue resolves the fuga")
	check(music.resolve_tracks("boss") == [fuga], "Missing boss track falls back to the voyage cue")
	check(music.resolve_tracks("unknown").is_empty(), "Unknown cue resolves nothing")
	check(music.stream_for(aria) != null and music.stream_for(aria).loop, "Imported stream loops")

	music.apply_preferences(0.6, true)
	music.play_cue("home")
	check(music.cue == "home" and music.active_path() == aria, "Home cue starts the aria")
	check(music.is_playing(), "Home cue actually plays")
	check(is_equal_approx(music.current_db(), linear_to_db(0.6) - 6.0), "Home cue uses the configured volume")
	music.play_cue("voyage")
	check(music.active_path() == fuga, "Voyage cue crossfades to the fuga")
	music.play_cue("boss")
	check(music.cue == "boss" and music.active_path() == fuga, "Boss cue keeps the fallback track")
	music.set_suspended(true)
	check(music.current_db() == Director.SILENT_DB, "Gallery replay suspends the director")
	music.set_suspended(false)
	check(music.current_db() > Director.SILENT_DB, "Leaving replay restores the volume")
	music.apply_preferences(0.3, false)
	check(music.current_db() == Director.SILENT_DB, "Disabled music stays silent")
	music.apply_preferences(0.3, true)
	check(is_equal_approx(music.current_db(), linear_to_db(0.3) - 6.0), "Re-enabling restores the saved volume")

	var app = StubApp.new()
	music.sync(app)
	check(music.cue == "boss", "A boss battle node selects the boss cue in sync")
	app.session.state = {"node": {"id": "driftwood"}}
	music.sync(app)
	check(music.cue == "voyage", "An ordinary battle node keeps the voyage cue")
	app.session.phase_name = "finished"
	music.sync(app)
	check(music.cue == "home", "Settlement selects the home cue")
	app.session.screen = "home"
	music.sync(app)
	check(music.cue == "home", "The title screen selects the home cue")
	app.story_replay = Node.new()
	music.sync(app)
	check(music.suspended, "An open gallery replay suspends the director")
	app.story_replay.free()
	app.story_replay = null
	music.sync(app)
	check(not music.suspended, "Closing the replay resumes the director")

	var path := "user://music-preferences-test.cfg"
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var prefs = Display.new(false)
	prefs.path = path
	prefs.music_volume = 0.25
	prefs.music_enabled = false
	check(prefs.save_preferences() == OK, "Audio preferences save")
	var restored = Display.new(false)
	restored.path = path
	restored.load_preferences()
	check(is_equal_approx(restored.music_volume, 0.25), "Music volume round-trips")
	check(not restored.music_enabled, "Music mute round-trips")
	restored.music_volume = 2.5
	restored.save_preferences()
	var clamped = Display.new(false)
	clamped.path = path
	clamped.load_preferences()
	check(clamped.music_volume <= 1.0, "Out-of-range volume is clamped on load")
	DirAccess.remove_absolute(path)

	root.remove_child(music)
	music.free()
	await process_frame
	await create_timer(0.35).timeout
	print("music_director: %d failures" % failures)
	quit(1 if failures else 0)
