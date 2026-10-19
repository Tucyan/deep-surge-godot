extends SceneTree
var app
var failures:=0
var active_case:="new"
var drawn_frames: Array=[]
var capture_counts: Dictionary={}
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func observe_draw():
	if not is_instance_valid(app) or not is_instance_valid(app.loading_transition): return
	var overlay=app.loading_transition
	drawn_frames.append({"case":active_case,"elapsed":overlay.elapsed,"stage":overlay.stage.text})
	if "--capture" not in OS.get_cmdline_user_args(): return
	var count: int=capture_counts.get(active_case,0)
	capture_counts[active_case]=count+1
	if count%2==0 and count<48:
		root.get_texture().get_image().save_png("res://evidence/loading-frames/%s-%02d.png" % [active_case,count])
func wait_transition():
	var frames:=0
	while app.get("transition_busy")==true and frames<600:
		await process_frame; frames+=1
	check(frames<600,"transition always finishes")
func run():
	root.size=Vector2i(1280,720)
	Engine.max_fps=120
	if DisplayServer.get_name()!="headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/loading-frames"))
		RenderingServer.frame_post_draw.connect(observe_draw)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.meta.path="user://loading-test-meta.json"
	if not app.has_method("request_command"):
		check(false,"S01–S03 UI command transition entry is missing")
		app.queue_free(); await process_frame; quit(failures); return
	var before: Dictionary=app.session.snapshot()
	app.request_command("new",{"mode":"challenge","difficulty":"standard","origin":"strong","seed":22})
	check(app.transition_busy and app.find_child("LoadingTransition",true,false)!=null,"new game immediately shows animated transition")
	check(app.session.snapshot()==before,"rules wait until overlay is painted")
	app.request_command("new",{"mode":"challenge","seed":99})
	var overlay=app.find_child("LoadingTransition",true,false)
	var initial_time: float=overlay.elapsed
	await process_frame; await process_frame; await process_frame
	check(overlay.elapsed>initial_time,"animation advances across loading frames")
	if DisplayServer.get_name()!="headless" and "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/loading-new-a.png")
		await create_timer(.09).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/loading-new-b.png")
	await wait_transition()
	check(app.session.screen=="game" and app.session.state.seed==22,"new game executes original command once")
	check(app.find_child("LoadingTransition",true,false)==null,"overlay removed after target draw")
	var state: Dictionary=app.session.state.duplicate(true)
	active_case="home"
	app.request_command("home"); await wait_transition()
	check(app.session.screen=="home" and app.session.state==state,"home transition retains active run")
	active_case="resume"
	app.request_command("resume"); await wait_transition()
	check(app.session.screen=="game" and app.session.state==state,"resume transition retains active run")
	active_case="reject"
	app.request_command("new",{"difficulty":"standard","mode":"challenge","seed":99}); await wait_transition()
	check(not app.message.is_empty() and app.session.state==state,"rejected command keeps original state and exits overlay")
	check(not app.transition_busy,"failure restores command input")
	if DisplayServer.get_name()!="headless":
		for kind in ["new","home","resume"]:
			var frames: Array=drawn_frames.filter(func(f):return f.case==kind)
			check(frames.size()>5 and frames.back().elapsed>frames.front().elapsed+.1,"rendered moving frames for "+kind)
		var file:=FileAccess.open("res://evidence/loading-frame-sequence.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(drawn_frames,"\t")); file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.meta.path))
	app.queue_free(); await process_frame
	print("LOADING TRANSITION: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
