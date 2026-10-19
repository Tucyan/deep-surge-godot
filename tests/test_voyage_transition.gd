extends SceneTree
var app
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func wait_transition():
	await create_timer(2.0).timeout
	check(not app.transition_busy,"transition finishes and restores input")
	var frames:=0
	while app._ui_command_pending and frames<240:
		if is_instance_valid(app.acquisition_overlay) and not app.acquisition_overlay.collecting: app.acquisition_overlay.collect()
		await process_frame; frames+=1
	check(not app._ui_command_pending,"post-voyage acquisition completes before next input")
func fixture():
	app.handle_command("abandon")
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.session.state.hand=[]; app.session.state.coins=0
	app.session.state.phase="aftermath"
	app.render()
func verify_transition(command: String, args: Dictionary = {}):
	var before: Dictionary=app.session.snapshot()
	var twin=load("res://core/action_query.gd").fork(app.session)
	twin._auto_advancing=false
	twin.auto_end_voyage=app.session.auto_end_voyage
	check(twin.dispatch(command,args),"reference command succeeds")
	app.request_command(command,args)
	check(app.transition_busy,"round change starts transition")
	check(app.session.snapshot()==before,"fade appears before settlement")
	var overlay=app.find_child("VoyageTransition",true,false)
	check(is_instance_valid(overlay),"dedicated voyage overlay exists")
	if is_instance_valid(overlay):
		check(overlay.backdrop_color.r<.2 and overlay.backdrop_color.g<.2 and overlay.backdrop_color.b<.2 and overlay.backdrop_color.a>.3 and overlay.backdrop_color.a<1,"dark translucent backdrop")
		app.request_command(command,args)
		await create_timer(.4).timeout
		check(overlay.elapsed>.1,"animation advances")
		if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/voyage-transition.png")
	await wait_transition()
	check(app.session.snapshot()==twin.snapshot(),"settlement and RNG match one synchronous dispatch")
	check(app.find_child("VoyageTransition",true,false)==null,"overlay removed")
func run():
	root.size=Vector2i(1280,720); Engine.max_fps=60
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	await process_frame
	fixture()
	await verify_transition("end_voyage")
	check(app.session.state.voyage==2 and app.session.phase()=="navigation","next voyage opens")
	fixture()
	app.session.give("wood",12)
	app.request_command("end_voyage")
	check(not app.transition_busy and app.session.phase()=="discard","excess hand remains interactive before transition")
	while app.session.state.hand.size()>11:
		app.request_command("discard",{"uid":app.session.state.hand[0].uid})
	check(not app.transition_busy,"nonfinal discard does not animate")
	await verify_transition("discard",{"uid":app.session.state.hand[0].uid})
	fixture()
	app.session.state.ap=0; app.session.give("water")
	app.session.state.player.hydration=60
	await verify_transition("play",{"uid":app.session.state.hand[0].uid})
	check(app.session.state.voyage==2,"last effective free action auto-settles with animation")
	fixture()
	app.session.state.phase="story"; app.session.state.story_step="result"; app.session.state.ap=0
	await verify_transition("advance")
	fixture()
	app.session.state.ap=0; app.session.give("wood",11)
	app.session.state.phase="story"; app.session.state.story_step="result"
	app.request_command("advance")
	check(not app.transition_busy and app.session.phase()=="discard","automatic settlement waits for excess hand")
	await verify_transition("discard",{"uid":app.session.state.hand[0].uid})
	fixture()
	app.session.state.voyage=app.session.state.length
	app.request_command("end_voyage")
	check(not app.transition_busy and app.session.phase()=="finished","terminal settlement has no next voyage overlay")
	fixture()
	app.session.state.phase="navigation"
	app.request_command("end_voyage")
	check(not app.transition_busy and not app.message.is_empty(),"invalid command keeps immediate error")
	app.queue_free(); await process_frame
	print("VOYAGE TRANSITION: "+("PASS" if failures==0 else "FAIL")); quit(failures)
