extends SceneTree
## Reads imported music streams so duration and loop flags are recorded, not guessed.
func _init() -> void:
	for path in ["res://assets/music/daily-arsnova-bwv82-aria-v1.mp3", "res://assets/music/daily-arsnova-bwv578-fuga-v1.mp3"]:
		var stream: AudioStream = load(path)
		if stream == null:
			printerr("MISSING " + path)
			continue
		print("%s length=%.3f loop=%s bpm=%s" % [path, stream.get_length(), str(stream.loop) if "loop" in stream else "n/a", str(stream.bpm) if "bpm" in stream else "n/a"])
	quit(0)
