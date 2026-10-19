extends SceneTree
const T=preload("res://core/tutorial_rules.gd")
var app
var failures:=0
var fixtures: Dictionary={}
func _init(): call_deferred("run")
func check(ok:bool,why:String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle():
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
func remember(id:String="",panel:String=""):
	if id.is_empty(): id=T.current_step(app.session.state)
	if id in ["done",""] or fixtures.has(id): return
	fixtures[id]={"save":app.session.snapshot(),"panel":app.session.panel if panel.is_empty() else panel}
func step(command:String,args:Dictionary={}):
	check(app.session.dispatch(command,args),command+": "+app.session.error); remember()
func uid(id:String)->String: return T.hand_uid(app.session.state,id)
func discard_rest():
	for i in range(40):
		if app.session.phase()!="discard": return
		for c in app.session.state.hand:
			if c.id not in ["coin","corpse","pollution","punch"]:
				step("discard",{"uid":c.uid}); break
func run():
	root.size=Vector2i(1680,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.display_settings.mobile=true; app.display_settings.free_aspect=true; app.display_settings.ui_scale=1.25
	app.apply_display_settings(false); await settle()
	step("new",T.start_args()); step("voyage",{"id":app.session.state.candidates[0].visit_id})
	step("salvage"); step("salvage"); remember("craft1-modal","craft")
	step("craft",{"id":"filter"}); step("install",{"uid":uid("filter"),"auto":true})
	step("enter"); step("advance"); step("option",{"id":"wood"}); step("advance"); step("end_voyage"); discard_rest()
	step("play",{"uid":uid("water")}); step("play",{"uid":uid("food")}); step("voyage",{"id":app.session.state.candidates[0].visit_id})
	step("enter"); step("advance"); step("fight"); step("play",{"uid":uid("spear")}); step("battle_action",{"action":"attack","resource_uid":uid("iron")}); step("battle_action",{"action":"block","resource_uid":uid("wood")}); step("battle_end"); step("play",{"uid":uid("spear")})
	step("advance"); step("end_voyage"); discard_rest()
	step("play",{"uid":uid("water")}); step("play",{"uid":uid("food")}); step("voyage",{"id":app.session.state.candidates[0].visit_id})
	step("repair_cell",{"cell":T.damaged_cells(app.session.state)[0]})
	step("enter"); step("advance"); step("shop_enter"); step("buy",{"id":"wood","payment":"coin"}); step("sell",{"uid":uid("corpse")}); step("shop_leave"); step("advance"); step("end_voyage"); discard_rest()
	for resolution in [Vector2i(1680,720),Vector2i(1260,540),Vector2i(2520,1080),Vector2i(1280,720)]:
		root.size=resolution
		app.display_settings.mobile=resolution.x!=1280
		for id in fixtures:
			check(app.session.restore(fixtures[id].save),"restore "+id)
			app.session.screen="game"; app.session.panel=fixtures[id].panel
			app.render(); await settle()
			var before:Dictionary=app.session.snapshot()
			var banner=app.find_child("TutorialBanner",true,false)
			check(banner!=null and banner.mouse_filter==Control.MOUSE_FILTER_IGNORE,"hint ignores input "+id)
			check(app.get_global_rect().encloses(banner.get_global_rect()),"hint fits screen "+id)
			var body=app.find_child("NodeEventBodyHost",true,false)
			if body!=null:
				check(is_equal_approx(body.offset_top,124),"node event keeps normal height "+id)
				check(not banner.get_global_rect().intersects(body.get_global_rect()),"hint clears event "+id)
			if fixtures[id].panel in ["craft","shop"]:
				check(app.current_page.global_position.y<=30,"modal has no reserved hint row "+id)
				var inventory=app.find_child("CraftInventory",true,false)
				if inventory!=null: check(not banner.get_global_rect().intersects(inventory.get_global_rect()),"hint clears material stock")
				for label in app.current_page.find_children("*","Label",true,false):
					if label.text.contains("资源共用翻倍价"): check(not banner.get_global_rect().intersects(label.get_global_rect()),"hint clears shop balance")
			for button in app.current_page.find_children("*","BaseButton",true,false):
				if button.is_visible_in_tree() and not button.disabled:
					check(not banner.get_global_rect().intersects(button.get_global_rect()),"hint clears action %s / %s" %[id,button.name])
					check(app.get_global_rect().encloses(button.get_global_rect()),"current action fits viewport %s / %s" %[id,button.name])
			check(app.session.snapshot()==before,"view preserves rules "+id)
			if id in ["nav1","read1","choose1","finish1","craft1-modal","buy3","sell3","leave3","repair3"]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://evidence/tutorial-node-%dx%d-%s.png" %[resolution.x,resolution.y,id])
	app.queue_free(); await settle()
	print("TUTORIAL NODE LAYOUT: %d stages, %s" %[fixtures.size(),"PASS" if failures==0 else "FAIL"]); quit(failures)
