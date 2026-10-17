extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void: call_deferred("run")
func settle() -> void:
	await process_frame; await process_frame
func make_app(unlocked_all: bool, last: String) -> Control:
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.meta.data={"version":1,"tutorial_done":true,"cleared":({"standard":true,"hard":true} if unlocked_all else {}),"last_difficulty":last}
	return app
func run() -> void:
	root.size=Vector2i(1600,900)
	# 1. Inherit the previous pick and start it.
	var app=await make_app(true,"hard")
	app.handle_ui("setup","challenge"); await settle()
	var picker=app.find_child("DifficultyChoice",true,false)
	var next=app.find_child("NewGameNext",true,false)
	check(picker!=null and next!=null,"new game exposes difficulty picker")
	if picker==null or next==null: quit(1); return
	check(not next.disabled and picker.selected==3,"last chosen difficulty is inherited")
	check(picker.get_item_text(1).begins_with("新手教程") and picker.get_item_text(2).begins_with("简单"),"tutorial and easy lead the list")
	for resolution in [Vector2i(1600,900),Vector2i(1280,720)]:
		root.size=resolution
		for index in [2,3,4]:
			picker=app.find_child("DifficultyChoice",true,false)
			picker.select(index); picker.item_selected.emit(index); await settle()
			next=app.find_child("NewGameNext",true,false)
			var description=app.find_child("DifficultyDescription",true,false)
			check(not next.disabled,"choice enables next")
			check(app.get_global_rect().encloses(next.get_global_rect()) and app.get_global_rect().encloses(description.get_global_rect()),"setup fits viewport")
			check("%" not in description.text and "概率" not in description.text,"no exact pressure modifiers")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/difficulty-repair-%dx%d.png" % [resolution.x,resolution.y])
	picker=app.find_child("DifficultyChoice",true,false)
	picker.select(3); picker.item_selected.emit(3); await settle()
	app.find_child("NewGameNext",true,false).pressed.emit(); await settle()
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
		check(battle.monster_hp_label.text.contains("25/25") and battle.monster_hp_bar.max_value==25,"scaled boss maximum and current HP agree")
		check(app.session.view().battle.enemy_direct_damage==3,"scaled attack projected to HUD")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/difficulty-repair-boss-1280x720.png")
	app.queue_free(); await process_frame
	root.size=Vector2i(1600,900)
	# 2. Locked tiers stay visible, disabled and explain their prerequisite.
	var locked=await make_app(false,"standard")
	locked.handle_ui("setup","challenge"); await settle()
	picker=locked.find_child("DifficultyChoice",true,false)
	check(picker.is_item_disabled(3) and picker.is_item_disabled(4) and not picker.is_item_disabled(1) and not picker.is_item_disabled(2),"locked difficulties are disabled")
	check(picker.get_item_text(3).contains("通关简单") and picker.get_item_text(4).contains("通关困难"),"lock reason names the prerequisite")
	locked.queue_free(); await process_frame
	# 3. First-timers enter the tutorial through starting-card selection.
	var fresh=await make_app(false,"")
	fresh.meta.data={"version":1,"tutorial_done":false,"cleared":{},"last_difficulty":""}
	fresh.handle_ui("setup","challenge"); await settle()
	var fresh_picker=fresh.find_child("DifficultyChoice",true,false)
	var fresh_next=fresh.find_child("NewGameNext",true,false)
	check(fresh_picker.selected==1 and not fresh_next.disabled,"first-timer defaults to the tutorial")
	check(fresh_next.text=="选择初始卡牌","tutorial begins with card selection")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/tutorial-repair-setup-1600x900.png")
	fresh_next.pressed.emit(); await settle()
	check(fresh.current_page.picking and fresh.session.state.is_empty(),"card selection precedes tutorial start")
	for id in ["wood","wood","plastic","plastic","rope","rope","iron","cloth"]:
		fresh.find_child("ResourcePlus_"+id,true,false).pressed.emit(); await settle()
	fresh.find_child("StartVoyage",true,false).pressed.emit(); await settle()
	check(fresh.session.state.mode=="tutorial" and fresh.session.state.difficulty=="tutorial" and fresh.session.state.hand.size()==10,"tutorial starts with its fixed ten-card hand")
	check(fresh.find_child("TutorialBanner",true,false)!=null,"tutorial guidance banner is visible")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/tutorial-repair-start-1600x900.png")
	fresh.queue_free(); await process_frame
	print("DIFFICULTY UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
