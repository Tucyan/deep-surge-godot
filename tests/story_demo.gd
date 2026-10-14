extends "res://pages/story_page.gd"
func _ready() -> void:
	super._ready()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://story/demo_story.json"))
	var result := load_story(data)
	if not result.ok: push_error(result.error)
	story_completed.connect(func(outcome): print("STORY DEMO COMPLETE: ", JSON.stringify(outcome)))
