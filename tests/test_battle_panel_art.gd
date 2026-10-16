extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _init() -> void:
	call_deferred("run")
	call_deferred("watchdog")
func watchdog() -> void:
	await create_timer(30).timeout
	quit(2)
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await process_frame
	app.session.dispatch("new", {"mode":"challenge", "origin":"strong", "seed":42})
	app.session.state.node = app.catalog.entry("nodes", "battle")
	app.session.state.node.visit_id = "battle-panel-art-fixture"
	app.session.state.phase = "battle"
	app.session.state.battle = {"id":"biter", "hp":6, "turn":1, "ap":3, "entry_hp":40, "shields":[], "raft_target_cell":"cell-0", "intent":{"type":"biter_bite", "target_cell":"cell-0"}}
	app.session.state.cells[0].equipment = {"id":"generator", "level":1, "fuel":2, "progress":0, "boost_cards":[{"uid":"panel-boost", "id":"barrier"}], "production_bonus":0}
	app.render()
	for config in [Vector3(1280,720,1), Vector3(1600,900,1), Vector3(1920,1080,1), Vector3(1920,900,1), Vector3(1280,720,1.25), Vector3(1920,900,1.25)]:
		var resolution := Vector2i(config.x,config.y)
		root.size = resolution
		app.display_settings.free_aspect = true
		app.display_settings.ui_scale = config.z
		app.apply_display_settings(false)
		app.render()
		await process_frame
		await process_frame
		var view = app.find_child("BattleHUDView",true,false)
		var panels: Array[Rect2] = []
		for id in ["MonsterPanel", "EnemyIntentPanel", "ActionPreviewPanel", "CombatLogPanel"]:
			var panel = view.find_child(id,true,false)
			check(panel != null, id + " exists")
			if panel == null: continue
			var art = panel.get_node_or_null("PanelArt")
			check(art is TextureRect and art.texture != null, id + " uses supplied art")
			if art is TextureRect and art.texture != null:
				check(absf(panel.size.aspect() - art.texture.get_size().aspect()) < 0.01, id + " preserves source aspect")
			panels.append(panel.get_global_rect())
			check(app.get_global_rect().encloses(panel.get_global_rect()), id + " fits screen")
			for child in panel.find_children("*", "Control", true, false):
				if child is Label or child is Button:
					check(panel.get_global_rect().grow(1).encloses(child.get_global_rect()), id + " contains " + str(child.name))
			var tray = app.find_child("VoyageHandTopBar",true,false)
			check(panel.get_global_rect().end.y <= tray.get_global_rect().position.y, id + " clears hand tray")
		for i in range(panels.size()):
			for j in range(i+1,panels.size()):
				check(not panels[i].intersects(panels[j]), "four panels do not overlap")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var suffix := "-125" if config.z > 1 else ""
			root.get_texture().get_image().save_png("res://evidence/battle-panels-%dx%d%s.png" % [resolution.x,resolution.y,suffix])
	app.queue_free()
	await process_frame
	print("BATTLE PANEL ART: %s" % ("PASS" if failures==0 else "FAIL"))
	quit(1 if failures else 0)
