extends SceneTree
var failures := 0
var app
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void: call_deferred("run")
func shot(id: String) -> void:
	app.render()
	await process_frame; await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://evidence/spring-v9-health-"+id+".png")==OK,"capture "+id)
	var hud=app.layout.find_child("SurgeStatusHUD",true,false)
	check(hud!=null and hud.health==app.session.state.player.hp and hud.max_health==app.session.state.player.hp_max,"HUD matches actual HP")
func run() -> void:
	root.size=Vector2i(1600,900)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false
	root.add_child(app); await process_frame
	var recorded: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/spring-v9-playtests/challenge-fool-4294967295-careful-scholar.json"))
	check(app.session.restore(recorded.trace.initial),"public route initial save")
	check(app.session.dispatch("resume"),"show game")
	await shot("start")
	var healed := false
	var battle := false
	for step in recorded.trace.steps:
		var card: Dictionary=app.session.I.find(app.session.state,step.args.get("uid",""))
		if not healed and step.command=="play" and card.get("id","")=="medkit":
			var hp: int=app.session.state.player.hp
			await shot("before-heal")
			var fans=get_nodes_in_group("hand_fans").filter(func(f):return app.layout.is_ancestor_of(f))
			var clicked := false
			for fan in fans:
				for i in range(fan.cards.size()):
					if fan.cards[i].uid==card.uid:
						fan.buttons[i].pressed.emit(); clicked=true; break
				if clicked: break
			check(clicked and app.session.state.player.hp==hp+3,"actual hand button heals three")
			check(app.session.I.find(app.session.state,card.uid).is_empty(),"UI consumes one medkit")
			await shot("after-heal"); healed=true
		else: check(app.session.dispatch(step.command,step.args),"replay public command "+step.command)
		if not battle and app.session.phase()=="battle":
			await shot("battle"); battle=true
		if healed and battle: break
	check(healed and battle,"real route exercises healing and battle")
	app.queue_free(); await process_frame
	print("HEALTH VISUAL: %s" % ("PASS" if failures==0 else "FAIL")); quit(1 if failures>0 else 0)
