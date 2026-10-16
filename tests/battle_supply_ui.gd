extends SceneTree
var failures := 0
var app
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	call_deferred("run"); call_deferred("watchdog")
func watchdog() -> void:
	await create_timer(30).timeout
	printerr("BATTLE SUPPLY UI: timeout"); quit(2)
func settle() -> void:
	await process_frame; await process_frame
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.session.dispatch("new",{"mode":"challenge","origin":"strong","difficulty":"nightmare","seed":22})
	app.session.state.phase="story"; app.session.state.story_step="choice"
	app.session.state.node=app.catalog.entry("nodes","boss"); app.session.state.node.visit_id="battle-supply-ui"
	app.session.state.cells[0].equipment={"id":"fishingNet","level":1,"fuel":0,"progress":0,"boost_cards":[],"production_bonus":0}
	app.handle_command("fight",{}); await settle()
	for resolution in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=resolution; await settle()
		var button=app.find_child("SalvageEntry",true,false)
		check(button!=null and not button.disabled,"battle salvage visible and enabled")
		if button==null: quit(1); return
		check(app.get_global_rect().encloses(button.get_global_rect()),"salvage fits viewport")
		var ap: int=app.session.state.battle.ap; var base_ap: int=app.session.state.ap; var cards: int=app.session.state.hand.size()
		button.pressed.emit(); await settle()
		check(app.session.state.battle.ap==ap-1 and app.session.state.ap==base_ap and app.session.state.hand.size()==cards+2,"real UI dispatches battle salvage")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/salvage-v19-%dx%d.png" % [resolution.x,resolution.y])
	app.session._auto_advancing=true
	app.session.state.battle.ap=0
	app.render(); await settle()
	check(app.find_child("SalvageEntry",true,false).disabled,"zero battle AP disables salvage")
	app.session.state.battle.ap=3
	app.session.state.cells[0].status="damaged"
	app.render(); await settle()
	check(not app.find_child("SalvageEntry",true,false).disabled,"damaged net still allows base salvage")
	app.session.state.cells[0].equipment={}
	app.render(); await settle()
	var base_cards: int=app.session.state.hand.size()
	app.find_child("SalvageEntry",true,false).pressed.emit(); await settle()
	check(app.session.state.hand.size()==base_cards+1 and app.session.state.battle.ap==2,"no net UI grants one base resource")
	app.queue_free(); await process_frame
	print("BATTLE SUPPLY UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
