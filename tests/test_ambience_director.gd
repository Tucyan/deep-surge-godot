extends SceneTree
## Ambience contract: the sea loop loads, loops, keeps playing across music
## cues, honours the local volume/mute preferences and silences during a
## gallery replay. Headless still exercises the real player.
var failures := 0
const Director = preload("res://presentation/ambience_director.gd")
const TRACK := "res://assets/audio/ambience/waves-loop-v1.ogg"

class StubApp:
	var story_replay = null

func _init() -> void: call_deferred("run")

func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + why)

func run() -> void:
	var ambience = Director.new()
	root.add_child(ambience)
	await process_frame
	check(ambience.error.is_empty(), "Ambience configuration loads: " + ambience.error)
	check(ambience.tracks == [TRACK], "The ambience track list points at the sea loop")
	check(ambience.fade_seconds > 0.0, "The ambience fade length is configured")
	check(is_equal_approx(ambience.trim_db, -16.0), "The ambience trim keeps the sea under the music")

	var stream: AudioStream = ambience._stream
	check(stream != null, "The sea loop loads")
	check(stream != null and stream.loop, "The imported sea loop loops")

	ambience.fade_seconds = 0.0
	ambience.apply_preferences(0.6, true)
	await process_frame
	check(ambience.is_playing(), "The sea loop actually plays")
	check(is_equal_approx(ambience.current_db(), linear_to_db(0.6) - 16.0), "The sea uses the configured volume")
	check(ambience.target_db() > Director.SILENT_DB, "A playing sea is above silence")

	ambience.apply_preferences(0.6, false)
	check(ambience.current_db() == Director.SILENT_DB, "Disabling the audio silences the sea")
	ambience.apply_preferences(0.0, true)
	check(ambience.current_db() == Director.SILENT_DB, "Zero volume silences the sea")
	ambience.apply_preferences(0.3, true)
	check(is_equal_approx(ambience.current_db(), linear_to_db(0.3) - 16.0), "Restoring the volume restores the sea")

	ambience.set_suspended(true)
	check(ambience.current_db() == Director.SILENT_DB, "A gallery replay suspends the sea")
	ambience.set_suspended(false)
	check(ambience.current_db() > Director.SILENT_DB, "Closing the replay restores the sea")

	var app = StubApp.new()
	ambience.sync(app)
	check(not ambience.suspended, "An ordinary app keeps the sea playing")
	app.story_replay = Node.new()
	ambience.sync(app)
	check(ambience.suspended, "An open gallery replay silences the sea")
	app.story_replay.free()
	app.story_replay = null
	ambience.sync(app)
	check(not ambience.suspended, "Closing the replay resumes the sea")

	root.remove_child(ambience)
	ambience.free()
	await process_frame
	await create_timer(0.35).timeout
	print("ambience_director: %d failures" % failures)
	quit(1 if failures else 0)
