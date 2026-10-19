extends SceneTree
## First launch stays on the title screen. The lesson starts with card selection.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void: call_deferred("run")
func settle() -> void:
	await process_frame; await process_frame; await process_frame
func make_app(save_path: String, meta_path: String) -> Control:
	var app=load("res://scenes/main.tscn").instantiate()
	app.store.path=save_path
	app.meta.path=meta_path
	app.preference_path="user://test-first-run-intro.cfg"
	app.persistence=true
	root.add_child(app)
	await settle()
	# Exercise the real opening bootstrap, instead of assuming it has already run.
	var opening_exit=app.find_child("OpeningExit",true,false)
	if opening_exit!=null:
		opening_exit.pressed.emit(); await settle()
	return app
func run() -> void:
	root.size=Vector2i(1280,720)
	var save_path:="user://test-first-run-save.json"
	var meta_path:="user://test-first-run-meta.json"
	for path in [save_path,meta_path,"user://test-first-run-intro.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var first=await make_app(save_path,meta_path)
	check(first.session.state.is_empty(),"first launch does not create a run before selection")
	check(first.session.screen=="home","first launch waits on the title screen")
	check(not FileAccess.file_exists(save_path),"first launch does not write a run save")
	first.handle_ui("setup","challenge"); await settle()
	first.find_child("NewGameNext",true,false).pressed.emit(); await settle()
	check(first.current_page.picking and first.session.state.is_empty(),"tutorial starts with initial-card selection")
	for id in ["wood","wood","plastic","plastic","rope","rope","iron","cloth"]:
		first.find_child("ResourcePlus_"+id,true,false).pressed.emit(); await settle()
	first.find_child("StartVoyage",true,false).pressed.emit(); await settle()
	while first.transition_busy: await process_frame
	check(first.session.state.get("mode","")=="tutorial","selected cards start the tutorial")
	check(first.find_child("TutorialBanner",true,false)!=null,"first launch shows the lesson banner")
	check(FileAccess.file_exists(save_path),"first launch writes the run save")
	var first_snapshot: Dictionary=first.session.state.duplicate(true)
	first.queue_free(); await process_frame
	# Same unfinished tutorial save: restore it instead of starting a second run.
	var resumed=await make_app(save_path,meta_path)
	check(resumed.session.state.get("mode","")=="tutorial","unfinished tutorial save is restored")
	check(resumed.session.screen=="home","restored run waits on the title screen")
	check(resumed.session.state.get("run_id","")==first_snapshot.get("run_id",""),"restore keeps the same tutorial run")
	resumed.queue_free(); await process_frame
	# A finished tutorial with no save must not auto-start again.
	var meta=load("res://adapters/meta_store.gd").new(); meta.path=meta_path; meta.read_meta()
	meta.data={"version":1,"tutorial_done":true,"cleared":{},"last_difficulty":"standard"}; meta.write_meta()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var normal=await make_app(save_path,meta_path)
	check(normal.session.state.is_empty(),"finished tutorial does not auto-start")
	check(normal.session.screen=="home","later launches stay on the title screen")
	normal.queue_free(); await process_frame
	for path in [save_path,meta_path,"user://test-first-run-intro.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("TUTORIAL START: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
