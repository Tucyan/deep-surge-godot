extends SceneTree
var failures := 0
var app
var fan
var used := []
var quick := []
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures += 1; printerr("FAIL: " + why)
func touch(down: bool, point: Vector2, finger: int = 0, canceled: bool = false):
	var e := InputEventScreenTouch.new()
	e.index = finger; e.pressed = down; e.canceled = canceled
	e.position = point if down else fan.global_position + point
	if down: fan._gui_input(e)
	else: fan._input(e)
func move_to(point: Vector2, finger: int = 0):
	var e := InputEventScreenDrag.new(); e.index = finger; e.position = fan.global_position + point
	fan._input(e)
func setup(phase: String = "preparation", ap: int = 3, id: String = "water", count: int = 1):
	if is_instance_valid(fan): fan.free()
	fan = load("res://presentation/hand_fan.gd").new(); app.add_child(fan)
	fan.position = Vector2(100,450); fan.size = Vector2(900,238)
	var card := {"uid":"mobile-test", "id":id, "definition":app.session.catalog.entry("cards",id), "temporary":false}
	var entries := [card]
	for i in range(1,count):
		var copy := card.duplicate(); copy.uid = "mobile-test-%d" % i; entries.append(copy)
	if count > 1:
		entries.append({"uid":"mobile-neighbour","id":"food","definition":app.session.catalog.entry("cards","food"),"temporary":false})
	var layout = load("res://presentation/hand_layout.gd").new(); layout.auto_sort=false
	fan.create(app.assets,entries,{"mobile":true,"phase":phase,"can_base":phase=="preparation","battle":{"ap":ap},"hand":entries,"hand_layout":layout})
	fan.arrange(); fan.set_process(false)
	fan.activated.connect(func(c): used.append(c.uid))
	fan.battle_action_double_clicked.connect(func(c): quick.append(c.uid))
	used.clear(); quick.clear()
func point(index: int = 0) -> Vector2: return fan.tiles[index].position + Vector2(40,80)
func run():
	app = load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame; await process_frame
	setup()
	touch(true,point()); touch(false,point())
	check(used.is_empty(),"mobile tap cannot consume survival card")
	setup(); touch(true,point()); fan._process(.049)
	check(not fan.dragging,"hold waits until 0.05 seconds")
	fan._process(.0011); check(fan.dragging,"0.05 second hold starts drag")
	move_to(Vector2(400,-50)); touch(false,Vector2(400,-50))
	check(used.size()==1,"release above hand uses exactly one card")
	setup(); var start := point(); touch(true,start); fan._process(.051)
	move_to(Vector2(400,-50)); move_to(start); touch(false,start)
	check(used.is_empty(),"return into hand cancels use")
	setup(); touch(true,point()); fan._process(.051); touch(false,Vector2(-20,-50))
	check(used.is_empty(),"release beside hand cannot use")
	setup(); touch(true,point()); fan._process(.051); touch(false,Vector2(400,-600))
	check(used.is_empty(),"offscreen release cannot use")
	setup(); touch(true,point()); fan._process(.051); touch(false,Vector2(400,-50),1)
	check(fan.pressed_index==0 and used.is_empty(),"second finger cannot release held card")
	touch(false,Vector2(400,-50),0,true)
	check(used.is_empty() and not fan.dragging,"OS cancellation never uses")
	setup("navigation"); touch(true,point()); fan._process(.051); touch(false,Vector2(400,-50))
	check(used.is_empty(),"navigation cannot use survival cards")
	setup("battle",0,"spear"); touch(true,point()); fan._process(.051); touch(false,Vector2(400,-50))
	check(used.is_empty() and quick.is_empty(),"insufficient AP cannot play")
	setup("discard",3,"pollution"); touch(true,point()); fan._process(.051); touch(false,Vector2(400,-50))
	check(used.is_empty(),"forbidden discard cannot play")
	for mode in ["spread","raise"]:
		setup("discard",3,"wood",6)
		fan.hand_layout.hover_mode=mode; fan.arrange(); fan._process(1.0)
		touch(true,point()); fan._process(.049)
		fan.show_description()
		check(not fan.tip_text.text.contains("调整顺序"),"mobile discard help does not promise sorting "+mode)
		var rear: Vector2=fan.stack_bases[0].position
		var neighbour: Vector2=fan.tiles[1].position
		var order: Array=fan.cards.map(func(c):return c.uid)
		fan._process(.003)
		check(fan.stack_bases[0].position.is_equal_approx(rear),"discard hold leaves rear cards stationary "+mode)
		move_to(Vector2(800,-50)); fan._process(.2)
		check(fan.tiles[0].position.y<0,"discard slides the front card above hand "+mode)
		check(fan.stack_bases[0].position.is_equal_approx(rear) and fan.stack_bases[0].modulate.a==1.0 and fan.stack_bases[0].z_index==1,"discard rear stays opaque on table "+mode)
		check(fan.tiles[1].position.is_equal_approx(neighbour),"discard does not open a sorting slot "+mode)
		move_to(Vector2(800,80)); fan._process(.2); touch(false,Vector2(800,80))
		check(used.is_empty() and fan.cards.map(func(c):return c.uid)==order,"returning discard cancels without reordering "+mode)
		fan._process(1.0); touch(true,point()); fan._process(.051)
		move_to(Vector2(800,-50)); fan._process(.2); touch(false,Vector2(800,-50))
		check(used==["mobile-test"],"stack discard activates only the front UID "+mode)
	setup("battle",3); touch(true,point()); fan._process(.051); touch(false,Vector2(400,-50))
	check(quick.size()==1 and used.is_empty(),"battle drag confirms playable card via validated battle action")
	setup("battle",3); var attack: int = fan.cards.size()-2
	touch(true,point(attack)); fan._process(.051); touch(false,Vector2(400,-50))
	check(quick==["virtual_action_attack"],"fixed attack can drag to confirm")
	fan.free(); fan=null
	app.display_settings.mobile=true
	root.size=Vector2i(1680,720)
	app.display_settings.ui_scale=1.25; app.display_settings.free_aspect=true
	app.apply_display_settings(false)
	await process_frame; await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.session.give("water",1,false,"mobile-integration")
	app.session.state.player.hydration=40
	app.render(); await process_frame; await process_frame
	fan=app.find_child("hand_fan",true,false)
	fan._process(1.0)
	var water_index: int = fan.cards.find(fan.cards.filter(func(c):return c.id=="water")[0])
	var water_point := point(water_index)
	var before: Dictionary=app.session.snapshot()
	touch(true,water_point); touch(false,water_point)
	check(app.session.snapshot()==before,"real mobile tap preserves inventory AP and RNG")
	fan=app.find_child("hand_fan",true,false); fan._process(1.0)
	water_index=fan.cards.find(fan.cards.filter(func(c):return c.id=="water")[0])
	var water_uid: String=fan.cards[water_index].uid
	touch(true,point(water_index)); fan._process(.051); touch(false,Vector2(400,-50))
	check(app.session.state.player.hydration>40,"real mobile drag applies water effect")
	check(not app.session.state.hand.any(func(c):return c.uid==water_uid),"real mobile drag consumes selected UID")
	await process_frame; await process_frame
	app.session.state.hand.clear()
	app.session.give("wood",6,false,"mobile-stack-discard")
	app.session.give("iron",6,false,"mobile-stack-discard")
	app.session.state.phase="discard"; app.session.state.player.limit=1
	app.render(); await process_frame; await process_frame
	fan=app.find_child("hand_fan",true,false); fan._process(1.0)
	var stack_index: int=fan.cards.find_custom(func(c):return c.id=="wood")
	var discarded_uid: String=fan.cards[stack_index].uid
	var hand_before: Array=app.session.state.hand.duplicate(true)
	var rng_before: Dictionary=app.session.state.rng.duplicate(true)
	touch(true,point(stack_index)); fan._process(.051)
	var stack_rest: Vector2=fan.stack_bases[stack_index].position
	move_to(Vector2(400,-50)); fan._process(.2)
	check(fan.stack_bases[stack_index].position.is_equal_approx(stack_rest),"real discard rear remains on table")
	if "--capture-discard" in OS.get_cmdline_user_args():
		await process_frame; await process_frame
		root.get_texture().get_image().save_png("user://mobile-stack-discard.png")
	touch(false,Vector2(400,-50))
	check(app.session.state.hand.size()==hand_before.size()-1 and not app.session.state.hand.any(func(c):return c.uid==discarded_uid),"real stack discard removes exactly the front UID")
	check(app.session.I.count(app.session.state,"wood")==5 and app.session.I.count(app.session.state,"iron")==6,"real stack discard preserves remaining cards")
	check(app.session.state.rng==rng_before,"stack discard does not consume RNG")
	await process_frame; await process_frame
	fan=app.find_child("hand_fan",true,false)
	stack_index=fan.cards.find_custom(func(c):return c.id=="wood")
	check(fan.cards[stack_index].stack_count==5 and fan.stack_bases[stack_index]!=null,"real stack discard refreshes remaining stack")
	app.session.state.node=app.catalog.entry("nodes","battle")
	app.session.state.node.visit_id="mobile-battle"
	app.session.state.phase="story"; app.session.state.story_step="choice"
	check(app.session.dispatch("fight"),"enter real battle fixture")
	app.session.state.battle.hp=30; app.session.give("cloth",1,false,"mobile-invalid-combo")
	app.render(); await process_frame; await process_frame
	fan=app.find_child("hand_fan",true,false); fan._process(1.0)
	var attack_index: int=fan.cards.size()-2
	var ap_before: int=app.session.state.battle.ap
	var hp_before: int=app.session.state.battle.hp
	touch(true,point(attack_index)); fan._process(.051); touch(false,Vector2(400,-50))
	check(app.session.state.battle.ap==ap_before-1 and app.session.state.battle.hp<hp_before,"real battle drag attacks exactly once")
	await process_frame; await process_frame
	fan=app.find_child("hand_fan",true,false); fan._process(1.0)
	var cloth_index: int=fan.cards.find(fan.cards.filter(func(c):return c.id=="cloth")[0])
	touch(true,point(cloth_index)); touch(false,point(cloth_index))
	before=app.session.snapshot()
	touch(true,point(fan.cards.size()-2)); fan._process(.051); touch(false,Vector2(400,-50))
	check(app.session.snapshot()==before,"cloth plus attack drag cannot spend AP or material")
	fan=null
	app.display_settings.mobile=true; app.settings_tab="game"; app.handle_ui("local_panel","settings")
	await process_frame; await process_frame
	check(app.find_child("CameraOrbitBinding",true,false)==null,"mobile hides mouse binding")
	check(app.find_child("CameraResetBinding",true,false)==null,"mobile hides keyboard binding")
	check(app.find_child("MobileCameraHint",true,false)!=null,"mobile exposes touch help")
	app.queue_free(); await process_frame
	print("MOBILE HAND: " + ("PASS" if failures==0 else "FAIL")); quit(failures)
