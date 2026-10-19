extends "res://adapters/narrative_store.gd"
var reads := 0
func _read_json(path: String) -> Variant:
	reads += 1
	return super._read_json(path)
