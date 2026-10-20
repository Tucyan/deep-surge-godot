extends SceneTree
var app
var failures:=0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle():
	await process_frame; await process_frame; await process_frame
func run():
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.meta.path="user://setup-perf-isolated-meta.json"
	var sentinel:="do-not-overwrite-test-meta"
	var file:=FileAccess.open(app.meta.path,FileAccess.WRITE); file.store_string(sentinel); file.close()
	app.handle_command("new",{"mode":"challenge","difficulty":"standard","origin":"strong","seed":22})
	check(FileAccess.get_file_as_string(app.meta.path)==sentinel,"persistence=false never writes explicit new-game difficulty")
	app.handle_command("home"); await settle()
	var home_layout: int=app.layout.get_instance_id()
	var backdrop: int=app.title_backdrop.get_instance_id()
	app.handle_ui("setup","challenge"); await settle()
	check(app.layout.get_instance_id()==home_layout,"S07 entering setup retains home host")
	check(app.title_backdrop.get_instance_id()==backdrop,"S07 retains existing backdrop")
	var setup=app.current_page
	setup.chosen_difficulty="standard"; setup.rebuild(); await settle()
	var state: Dictionary=app.session.snapshot()
	if DisplayServer.get_name()!="headless":
		for i in range(120):
			if setup.RESOURCES.all(func(id):return app.assets._cache.has("card."+id)): break
			await process_frame
		check(setup.RESOURCES.all(func(id):return app.assets._cache.has("card."+id)),"S04 preparation warms picker art before opening")
	app.find_child("NewGameNext",true,false).pressed.emit(); await settle()
	var plus=app.find_child("ResourcePlus_wood",true,false)
	var plus_id: int=plus.get_instance_id()
	plus.grab_focus(); plus.pressed.emit(); await settle()
	check(is_instance_valid(plus) and app.find_child("ResourcePlus_wood",true,false).get_instance_id()==plus_id,"S08 count change retains control")
	check(setup.selected_resources()==["wood"],"one add selects one wood")
	check(app.find_child("StartVoyage",true,false).text=="正式开始","nonempty selection changes start label")
	setup.change_resource("wood",1); setup.change_resource("wood",1)
	check(setup.resource_counts.wood==2 and app.find_child("ResourcePlus_wood",true,false).disabled,"per-type limit remains two")
	for id in ["iron","rope","plastic","cloth"]: setup.change_resource(id,1)
	check(setup.selected_resources().size()==setup.resource_limit(),"total limit enforced")
	check(setup.RESOURCES.all(func(id):return app.find_child("ResourcePlus_"+id,true,false).disabled),"all plus buttons disable at total cap")
	for id in setup.RESOURCES: setup.change_resource(id,-2)
	check(setup.selected_resources().is_empty(),"remove returns to empty")
	check(app.find_child("StartVoyage",true,false).text=="随心所欲","empty selection label restored")
	check(app.session.snapshot()==state,"setup changes never touch rules or RNG")
	setup.chosen_difficulty="tutorial"; setup.rebuild(); await settle()
	check(app.find_child("StartVoyage",true,false).disabled,"tutorial cannot start empty")
	for id in setup.Tutorial.STARTING: setup.change_resource(id,1)
	check(not app.find_child("StartVoyage",true,false).disabled,"tutorial exact starting set enables start")
	# Real existing run, open/close settings without changing rule state.
	app.setup_mode=""; app.handle_command("resume"); await settle()
	app.story_mode_visible=true # Include the retained optional tab in lazy-build checks.
	app.settings_tab="display"; app.handle_ui("local_panel","settings"); await settle()
	check(app.find_child("MotionToggle",true,false)!=null,"active display tab is built")
	check(app.find_child("auto_sort",true,false)==null,"S05 inactive game tab is not built")
	check(app.find_child("NarrativeTabContent",true,false).get_child_count()==0,"inactive narrative form absent")
	var modal_id: int=app.find_child("ModalSurface",true,false).get_instance_id()
	app.find_child("TabGame",true,false).pressed.emit(); await settle()
	var sort=app.find_child("auto_sort",true,false)
	check(sort!=null,"game tab built on selection")
	var sort_id: int=sort.get_instance_id()
	app.find_child("TabDisplay",true,false).pressed.emit(); app.find_child("TabGame",true,false).pressed.emit(); await settle()
	check(app.find_child("auto_sort",true,false).get_instance_id()==sort_id,"tab revisit reuses controls")
	check(app.find_child("ModalSurface",true,false).get_instance_id()==modal_id,"tab switch retains surface")
	app.find_child("TabNarrative",true,false).pressed.emit(); await settle()
	check(app.find_child("NarrativeTabContent",true,false).get_child_count()>0,"narrative content builds on demand")
	var base_id: int=app.layout.get_instance_id()
	app.handle_ui("local_panel",""); await settle()
	check(app.layout.get_instance_id()==base_id and app.find_child("ModalSurface",true,false)==null,"S06 close retains HUD and removes modal")
	check(app.world_view.camera_input_enabled,"close restores camera input")
	var interaction=app.find_child("RaftInteraction",true,false)
	check(interaction.process_mode!=Node.PROCESS_MODE_DISABLED,"close restores raft interaction")
	check(app.session.snapshot()==state or app.session.state==state.state,"UI preserves rule state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.meta.path))
	app.queue_free(); await process_frame
	print("SETUP SETTINGS PERFORMANCE: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
