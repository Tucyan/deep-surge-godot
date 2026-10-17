extends "res://flow_app.gd"
const Intro = preload("res://presentation/opening_intro.gd")
@export var preference_path := Intro.PREFERENCES

func _ready() -> void:
	if persistence:
		display_settings.load_preferences()
		display_settings.apply_window(get_window())
	if persistence and Intro.should_play(preference_path):
		var intro := Intro.new()
		intro.preference_path = preference_path
		add_child(intro)
		await intro.finished
		remove_child(intro)
		intro.queue_free()
	super._ready()
