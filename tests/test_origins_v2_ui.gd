extends SceneTree
var failures:=0
var app
func check(ok: bool, message: String):
	if not ok: failures+=1; printerr("FAIL: "+message)
func settle():
	await process_frame; await process_frame; await process_frame
func capture(name: String):
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/origins-v2-"+name+".png")
func _init(): run.call_deferred()
func run():
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_ui("setup","challenge"); await settle()
	var setup=app.current_page
	for origin in ["hoarder","zealot","engineer"]:
		setup.chosen_difficulty="standard"; setup.chosen_origin=origin; setup.rebuild(); await settle()
		var text: String=app.find_child("OriginDescription",true,false).text
		check(text==app.session.ORIGINS[origin].description,"selector shows updated "+origin)
		await capture("setup-"+origin)
	app.setup_mode=""; app.session=load("res://core/game_session.gd").new(app.catalog)
	var s=app.session
	s.dispatch("new",{"mode":"challenge","origin":"hoarder","seed":22})
	s.state.hand=[]; s.give("wood",12)
	s.state.node=app.catalog.entry("nodes","crabBattle"); s.state.node.visit_id="v2-ui"
	s.state.phase="story"; s.state.story_step="choice"; s.dispatch("fight")
	app.render(); await settle()
	var badge=app.find_child("HandCapacityBadge",true,false)
	check(badge!=null and badge.tooltip_text.contains("永久物资12张") and badge.tooltip_text.contains("储备充足"),"HUD explains high-stock trait")
	check(s.state.battle.shields.any(func(item):return item.source=="origin_hoarder"),"real HUD receives origin shield")
	await capture("hoarder-shield")
	s=load("res://core/game_session.gd").new(app.catalog); app.session=s
	s.dispatch("new",{"mode":"challenge","origin":"engineer","seed":22}); s.give("filter")
	check(s.dispatch("install",{"uid":s.state.hand[-1].uid,"cell":s.state.cells[0].id}),"engineer installs through dispatch")
	app.render(); await settle()
	badge=app.find_child("HandCapacityBadge",true,false)
	check(badge.tooltip_text.contains("精工已用1/4"),"HUD shows precision quota")
	check(app.current_page.context.cells[0].equipment.level==2,"presentation receives actual level2")
	await capture("engineer-level2")
	app.queue_free(); await settle()
	print("ORIGINS V2 UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
