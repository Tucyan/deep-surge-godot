extends SceneTree
## Interface-level check: the banner follows the fixed lesson and the HUD only
## enables the prompted entry.
var app
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void: call_deferred("run")
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/tutorial-enchantment-"+id+".png")
func card_click(id: String, double_click: bool = false) -> void:
	var fan=app.find_child("hand_fan",true,false); fan._process(1.0)
	var index: int=fan.cards.find(fan.cards.filter(func(c):return c.id==id)[0])
	var point: Vector2=root.get_final_transform()*(fan.tiles[index].global_position+Vector2(40,140))
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		event.double_click=double_click and pressed
		Input.parse_input_event(event); await process_frame
	await settle()
func click(button: Button) -> void:
	var point: Vector2=root.get_final_transform()*button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point
		Input.parse_input_event(event); await process_frame
	await settle()
func banner_text() -> String:
	var banner=app.find_child("TutorialBanner",true,false)
	if banner==null: return ""
	var labels: Array = banner.find_children("*","Label",true,false)
	return " ".join(labels.map(func(label): return label.text))
func uid(id: String) -> String:
	for card in app.session.state.hand:
		if card.id==id: return str(card.uid)
	return ""
func command(name: String, args: Dictionary = {}) -> void:
	app.handle_command(name,args); await settle()
func discard_until_clear() -> void:
	var guard:=0
	while app.session.phase()=="discard" and guard<20:
		guard+=1
		var picked: Dictionary={}
		for card in app.session.state.hand:
			if card.id not in ["coin","corpse","pollution","punch"]: picked=card; break
		if picked.is_empty(): break
		await command("discard",{"uid":picked.uid})
func run() -> void:
	root.size=Vector2i(1600,900)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false
	app.meta.path="user://test-tutorial-ui-meta.json"; app.meta.data={"version":1,"tutorial_done":false,"cleared":{},"last_difficulty":""}
	root.add_child(app); await settle()
	app.handle_ui("setup","challenge"); await settle()
	var start=app.find_child("NewGameNext",true,false)
	check(start!=null and start.text=="选择初始卡牌","setup offers card selection before the tutorial")
	await click(start)
	check(app.current_page.picking and app.session.state.is_empty(),"tutorial first teaches initial cards")
	await shot("starting-cards-1600x900")
	for id in ["wood","wood","plastic","plastic","rope","rope","iron","cloth"]:
		await click(app.find_child("ResourcePlus_"+id,true,false))
	await click(app.find_child("StartVoyage",true,false))
	while app.transition_busy: await process_frame
	check(app.session.state.mode=="tutorial","tutorial started")
	check(banner_text().contains("选择目的地"),"banner starts with destination choice")
	var salvage=app.current_page.find_child("SalvageEntry",true,false)
	check(salvage!=null and salvage.disabled,"salvage is locked during the destination lesson (label=%s meta=%s op=%s)" % [("none" if salvage==null else str(salvage.disabled)),("none" if salvage==null else str(salvage.get_meta("salvage_disabled","?"))),("none" if salvage==null else str(salvage.get_meta("tutorial_operation","?")))])
	var option=app.find_child("NavigationOption",true,false)
	check(option!=null,"scripted destination visible")
	if option!=null:
		option.pressed.emit(); await settle()
	var depart=app.find_child("NavigationDepart",true,false)
	check(depart!=null,"depart button appears after selection")
	if depart!=null: depart.pressed.emit(); await settle()
	check(banner_text().contains("打捞"),"banner moves to salvage")
	salvage=app.current_page.find_child("SalvageEntry",true,false)
	var lesson_view: Dictionary = app.session.view()
	check(salvage!=null and not salvage.disabled,"salvage is enabled at its step (ap=%d op=%s can=%s)" % [int(lesson_view.get("ap",-1)),str(lesson_view.get("tutorial_operation","")),str(lesson_view.get("can_base",false))])
	for i in range(2):
		var button=app.current_page.find_child("SalvageEntry",true,false)
		if button!=null and not button.disabled:
			button.pressed.emit(); await settle()
	check(banner_text().contains("制作设备"),"banner moves to crafting")
	var craft_entry=app.find_child("CraftEntry",true,false)
	check(craft_entry!=null and not craft_entry.disabled,"craft entry is enabled at its step")
	craft_entry.pressed.emit(); await settle()
	var recipes: Array = app.find_children("CraftRecipeButton","Button",true,false)
	var filter_recipe: Button=null
	var other_enabled:=0
	for button in recipes:
		if str(button.get_meta("recipe_id",""))=="filter": filter_recipe=button
		elif not button.disabled: other_enabled+=1
	check(filter_recipe!=null and not filter_recipe.disabled,"only the filter recipe is offered")
	check(other_enabled==0,"other recipes are dimmed during the lesson")
	await shot("craft-1600x900")
	await command("close")
	await command("craft",{"id":"filter"})
	await command("install",{"uid":uid("filter"),"auto":true})
	check(app.session.state.cells.any(func(cell): return cell.equipment.get("id","")=="filter"),"filter installed through the lesson")
	await command("enter")
	check(banner_text().contains("阅读事件"),"banner moves to event")
	await shot("event-intro-1600x900")
	await click(app.find_child("NodeEventAction_advance",true,false))
	check(banner_text().contains("做出选择"),"banner moves to choice")
	await shot("event-choice-1600x900")
	await command("option",{"id":"wood"}); await settle()
	check(banner_text().contains("完成节点"),"banner moves to node result: "+banner_text())
	await command("advance")
	check(banner_text().contains("结束航行"),"banner moves to end voyage: "+banner_text())
	await command("end_voyage")
	check(banner_text().contains("弃牌"),"banner teaches discard")
	await discard_until_clear()
	check(banner_text().contains("使用生存牌"),"banner moves to survival cards")
	await command("play",{"uid":uid("water")})
	await command("play",{"uid":uid("food")})
	check(banner_text().contains("前往战斗"),"banner moves to the battle destination")
	await command("voyage",{"id":app.session.state.candidates[0].visit_id})
	await command("enter"); await command("advance"); await command("fight")
	check(banner_text().contains("第一次攻击"),"banner teaches the first attack")
	await shot("battle-1600x900")
	await command("play",{"uid":uid("spear")})
	check(banner_text().contains("攻击附魔"),"banner teaches enchantment after spear")
	check(banner_text().contains("攻击附魔"),"banner teaches attack enchantment")
	await shot("attack-lesson-1600x900")
	await card_click("iron")
	await card_click("action_attack")
	check(app.find_child("BattleHUDView",true,false).preview_summary_label.text.contains("附魔"),"desktop resource and attack selection show enchantment preview")
	await shot("attack-preview-1600x900")
	await card_click("action_attack",true)
	check(banner_text().contains("防御附魔"),"banner teaches defense enchantment")
	await card_click("wood")
	await card_click("action_block")
	await shot("defense-preview-1600x900")
	await card_click("action_block",true)
	check(banner_text().contains("结束回合"),"both native enchantments complete")
	await command("battle_end")
	await command("play",{"uid":uid("spear")})
	await command("advance"); await command("end_voyage")
	await discard_until_clear()
	await command("play",{"uid":uid("water")})
	await command("play",{"uid":uid("food")})
	await command("voyage",{"id":app.session.state.candidates[0].visit_id})
	check(banner_text().contains("修补筏格"),"banner teaches cell repair")
	var damaged: Array=[]
	for cell in app.session.state.cells:
		if cell.status=="damaged": damaged.append(str(cell.id))
	check(damaged.size()==1,"one cell is damaged for the repair lesson")
	await command("repair_cell",{"cell":damaged[0]})
	await command("enter"); await command("advance"); await command("shop_enter")
	check(banner_text().contains("购买物资"),"banner teaches buying")
	await shot("shop-1600x900")
	await command("buy",{"id":"wood","payment":"coin"})
	check(banner_text().contains("出售手牌"),"banner teaches sale")
	await click(app.find_child("ShopSellTab",true,false))
	await shot("sale-1600x900")
	await click(app.find_child("ShopSell_corpse",true,false))
	check(app.current_page.confirmation.visible,"sale opens confirmation")
	app.current_page.confirmation.confirmed.emit(); await settle()
	check(banner_text().contains("离开商店"),"banner teaches leaving the shop")
	await command("shop_leave"); await command("advance"); await command("end_voyage")
	await discard_until_clear()
	check(app.session.phase()=="finished" and str(app.session.state.result)=="tutorial","tutorial finishes")
	check(app.meta.tutorial_done(),"completion is written to meta progress")
	check(app.find_child("TutorialBanner",true,false)==null,"banner leaves the settlement screen")
	await shot("complete-1600x900")
	app.queue_free(); await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test-tutorial-ui-meta.json"))
	print("TUTORIAL UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
