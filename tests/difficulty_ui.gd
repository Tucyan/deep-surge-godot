extends SceneTree
var app
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void: call_deferred("run")
func settle() -> void:
	await process_frame; await process_frame
func run() -> void:
	root.size=Vector2i(1600,900)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_ui("setup","challenge"); await settle()
	var picker=app.find_child("DifficultyChoice",true,false)
	var next=app.find_child("NewGameNext",true,false)
	check(picker!=null and next!=null,"new game exposes difficulty picker")
	if picker==null or next==null: quit(1); return
	check(next.disabled and picker.selected==0,"explicit choice required")
	for resolution in [Vector2i(1600,900),Vector2i(1280,720)]:
		root.size=resolution
		for index in [1,2,3]:
			picker.select(index); picker.item_selected.emit(index); await settle()
			var description=app.find_child("DifficultyDescription",true,false)
			check(not next.disabled,"choice enables next")
			check(app.get_global_rect().encloses(next.get_global_rect()) and app.get_global_rect().encloses(description.get_global_rect()),"setup fits viewport")
			check("%" not in description.text and "概率" not in description.text,"no exact pressure modifiers")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/difficulty-v13-%dx%d.png" % [resolution.x,resolution.y])
	picker.select(2); picker.item_selected.emit(2); next.pressed.emit(); await settle()
	var start=app.find_child("StartVoyage",true,false)
	check(start!=null,"resources picker reached")
	if start!=null: start.pressed.emit(); await settle()
	check(app.session.state.get("difficulty")=="hard" and app.session.state.player.hp_max==14 and app.session.state.hand.size()==6,"UI starts chosen tier with origin bonus and correct hand")
	# Isolated battle presentation fixture, not a gameplay grant endpoint.
	app.session.state.phase="story"; app.session.state.story_step="choice"
	app.session.state.node=app.catalog.entry("nodes","boss"); app.session.state.node.visit_id="difficulty-ui"
	app.handle_command("fight",{}); await settle()
	var battle=app.find_child("BattleHUDView",true,false)
	check(battle!=null,"battle HUD renders")
	if battle!=null:
		check(battle.monster_hp_label.text=="HP 25/25" and battle.monster_hp_bar.max_value==25,"scaled boss maximum and current HP agree")
		check(app.session.view().battle.enemy_direct_damage==3,"scaled attack projected to HUD")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/difficulty-v13-boss-1280x720.png")
	app.queue_free(); await process_frame
	print("DIFFICULTY UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)

