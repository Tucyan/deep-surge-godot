extends RefCounted
static func create(tree: SceneTree, directory: String):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var config := ConfigFile.new()
	config.set_value("opening", "watched", true)
	config.save(directory + "/opening.cfg")
	var app = load("res://scenes/main.tscn").instantiate()
	app.preference_path = directory + "/opening.cfg"
	app.store.path = directory + "/profile.json"
	app.meta.path = directory + "/meta.json"
	tree.root.add_child(app)
	app.narrative_store = load("res://adapters/narrative_store.gd").new(directory + "/narrative")
	return app
