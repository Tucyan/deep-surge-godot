extends SceneTree
var failures:=0
var app
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func capture(name: String):
	if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/acquisition-arrival-"+name+".png")
func run():
	root.size=Vector2i(1280,720); Engine.max_fps=60
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.session.state.hand=[]; app.session.state.coins=0
	app.session.give("iron",3,false,"fixture")
	app.session.state.cells[0].equipment={"id":"fishingNet","level":2,"fuel":0,"progress":0,"boost_cards":[]}
	app.render(); await process_frame; await process_frame
	var old_capacity: int=app.hud_view().capacity
	app.request_command("salvage")
	for i in range(120):
		if is_instance_valid(app.acquisition_overlay): break
		await process_frame
	var overlay=app.acquisition_overlay
	check(is_instance_valid(overlay),"real salvage opens receipt")
	if not is_instance_valid(overlay): app.queue_free(); quit(1); return
	await create_timer(.3).timeout
	var pending: Array=overlay.batch.items.map(func(item):return item.uid)
	var presented: Dictionary=app.hud_view()
	check(not presented.hand.any(func(item):return item.uid in pending),"unconfirmed cards are not in presented hand")
	check(presented.capacity==old_capacity,"unconfirmed cards do not increase capacity counter")
	var fan=app.layout.find_child("hand_fan",true,false)
	check(not fan.cards.any(func(group):return group.get("stack_uids",[]).any(func(uid):return uid in pending)),"unconfirmed cards cannot join an existing stack")
	await capture("waiting")
	var saved: Dictionary=app.session.snapshot()
	var arrival_seen: Array=[]
	if overlay.has_signal("arrived"):
		overlay.arrived.connect(func():
			arrival_seen.append(true)
			for tile in overlay.tiles:
				var item: Dictionary=tile.get_meta("item")
				check(item.has("destination_position") and tile.global_position.distance_to(item.destination_position)<2,"flight lands directly on final hand position")
				check(item.has("destination_size") and tile.get_global_rect().size.distance_to(item.destination_size)<3,"flight matches final card size instead of collapsing to corner")
			var hand=app.layout.find_child("hand_fan",true,false)
			for i in range(hand.tiles.size()): check(hand.tiles[i].position.distance_to(hand.target_positions[i])<.1,"landed cards have no second slide after receipt")
		)
	else: check(false,"receipt exposes exact arrival boundary")
	overlay.collect()
	await create_timer(.25).timeout; await capture("flying")
	await create_timer(1.3).timeout
	check(arrival_seen.size()==1,"arrival boundary runs once")
	check(app.hud_view().capacity==old_capacity+pending.size(),"confirmed cards enter presented hand")
	check(app.session.snapshot()==saved,"presentation confirmation neither grants twice nor consumes RNG")
	fan=app.layout.find_child("hand_fan",true,false)
	for i in range(fan.tiles.size()): check(fan.tiles[i].position.distance_to(fan.target_positions[i])<.1,"cards stay at their final positions after input resumes")
	await capture("collected")
	app.queue_free(); await process_frame
	print("ACQUISITION ARRIVAL: "+("PASS" if failures==0 else "FAIL")); quit(failures)
