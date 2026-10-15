extends SceneTree
var failures:=0
func _init(): call_deferred("run")
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func run():
	root.size=Vector2i(1280,720)
	var app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	var s=app.session; s.state.phase="story"; s.state.story_step="choice"
	s.state.node=app.catalog.entry("nodes","battle"); s.state.node.visit_id="auto-ui"; s.state.hand=[]; s.state.player.hp=20
	app.handle_command("fight"); s.state.battle.ap=1; s.give("medkit"); app.render(); await process_frame; await process_frame
	var punch: Dictionary=s.state.hand.filter(func(c):return c.id=="punch")[0]
	app.handle_command("play",{"uid":punch.uid}); await process_frame
	check(s.state.battle.ap==0 and s.state.battle.turn==1,"medkit preserves free action in UI")
	var medkit: Dictionary=s.state.hand.filter(func(c):return c.id=="medkit")[0]
	app.handle_command("play",{"uid":medkit.uid}); await process_frame; await process_frame
	check(s.phase()=="battle" and s.state.battle.turn==2 and s.state.battle.ap==3,"UI rerenders automatically advanced battle")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/auto-progress-battle-1280.png")
	s.state.phase="aftermath"; s.state.hand=[]; s.state.ap=0; s.state.battle={}
	app.handle_command("resume"); await process_frame; await process_frame
	check(s.phase()=="navigation" and s.state.voyage==2,"UI displays navigation after automatic settlement")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/auto-progress-navigation-1280.png")
	app.queue_free(); await process_frame
	print("AUTO PROGRESS UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
