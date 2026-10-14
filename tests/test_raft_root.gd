extends SceneTree
func _init(): call_deferred("run")
func run():
	var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await process_frame
	var world = app.world_view
	var base = world.raft.get_node_or_null("DecorativeRoot")
	var ok: bool = base != null and world.cells.get_child_count() == 4 and app.session.state.cells.size() == 4
	if base != null: ok = ok and base.has_meta("blender_source") and world.raft_models.root_cells().size() == 2
	if world.toon_ocean != null: ok = ok and world.toon_ocean.material.get_shader_parameter("cell_count") == 6
	print("RAFT ROOT: PASS" if ok else "RAFT ROOT: FAIL (expected 4 playable + 2 decorative cells with matching water contact)")
	app.queue_free(); await process_frame; quit(0 if ok else 1)
