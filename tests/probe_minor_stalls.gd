extends SceneTree
## Follow-up inventory only. Real UI callbacks, isolated run with persistence off.
var app
var samples := []
var last_frame := 0
var max_frame_ms := 0.0
var failures := 0
func _init(): call_deferred("run")
func _process(_delta):
	var now:=Time.get_ticks_usec()
	if last_frame>0: max_frame_ms=maxf(max_frame_ms,(now-last_frame)/1000.0)
	last_frame=now
	return false
func measure(label: String, iteration: int, operation: Callable):
	var hud_id: int=app.layout.get_instance_id()
	max_frame_ms=0.0
	var start:=Time.get_ticks_usec()
	operation.call()
	var cpu_ms: float=(Time.get_ticks_usec()-start)/1000.0
	await process_frame; await RenderingServer.frame_post_draw
	var draw_ms: float=(Time.get_ticks_usec()-start)/1000.0
	await process_frame
	if not app.message.is_empty(): failures+=1; printerr(label+": "+app.message)
	samples.append({"action":label,"iteration":iteration,"cpu_ms":cpu_ms,"through_draw_ms":draw_ms,"max_frame_ms":max_frame_ms,"rebuilt_hud":hud_id!=app.layout.get_instance_id(),"phase":app.session.phase(),"screen":app.session.screen,"error":app.message})
func run():
	if DisplayServer.get_name()=="headless": printerr("Requires graphical renderer"); quit(1); return
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app)
	app.meta.path="user://minor-stall-probe-meta.json"
	await create_timer(1).timeout
	for i in range(6):
		await measure("idle_home",i,func(): pass)
		await measure("home_to_setup",i,func(): app.handle_ui("setup","challenge"))
		# Select an unlocked non-tutorial run before measuring its actual picker.
		app.current_page.chosen_difficulty="standard"; app.current_page.rebuild()
		await process_frame; await RenderingServer.frame_post_draw
		await measure("setup_to_picker",i,func(): app.find_child("NewGameNext",true,false).pressed.emit())
		await measure("picker_plus_wood",i,func(): app.find_child("ResourcePlus_wood",true,false).pressed.emit())
		await measure("picker_start_game",i,func(): app.find_child("StartVoyage",true,false).pressed.emit())
		await measure("idle_game",i,func(): pass)
		await measure("game_settings_open",i,func(): app.handle_ui("local_panel","settings"))
		await measure("game_settings_close",i,func(): app.handle_ui("local_panel",""))
		await measure("game_to_home",i,func(): app.handle_command("home"))
		await measure("home_resume",i,func(): app.handle_command("resume"))
		# Next iteration is another new run; discard only this in-memory probe session.
		app.session=app.Session.new(app.catalog)
		app.setup_mode=""; app.render(); await process_frame; await RenderingServer.frame_post_draw
	var file:=FileAccess.open("res://evidence/minor-stall-inventory.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"\t")); file.close()
	var names: Array=[]
	for row in samples:
		if not names.has(row.action): names.append(row.action)
	for label in names:
		var rows: Array=samples.filter(func(s): return s.action==label)
		print("%s first cpu=%.3f draw=%.3f; warm:" % [label,rows[0].cpu_ms,rows[0].through_draw_ms])
		for metric in ["cpu_ms","through_draw_ms","max_frame_ms"]:
			var values: Array=rows.slice(1).map(func(s): return s[metric]); values.sort()
			print("  %s median=%.3f max=%.3f" % [metric,values[2],values[4]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.meta.path))
	app.queue_free(); await process_frame; quit(failures)
