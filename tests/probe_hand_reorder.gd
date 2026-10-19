extends SceneTree
## Real graphical renderer; isolated preferences path. No player saves touched.
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
func measure(kind: String, sequence: int):
	var tray=app.find_child("hand_fan",true,false)
	var old_hud: int=app.layout.get_instance_id()
	var old_hand: int=tray.get_instance_id()
	var state: Dictionary=app.session.snapshot()
	var target:=Vector2.ZERO
	var moved_uid := ""
	var destination := -1
	if kind=="reorder":
		tray.focus_card(-1); tray._process(1.0)
		var source: int=0 if sequence%2==0 else tray.cards.size()-1
		destination=tray.cards.size()-1 if source==0 else 0
		moved_uid=tray.cards[source].uid
		var point: Vector2=tray.tiles[source].position+Vector2(20,60)
		var press:=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=tray.get_global_transform()*point; press.global_position=press.position
		root.push_input(press,true); tray._process(.21)
		if not tray.dragging:
			failures+=1; printerr("Probe did not start drag")
		target=Vector2(tray.base_x[destination]+tray.press_point.x,point.y)
		var motion:=InputEventMouseMotion.new(); motion.position=tray.get_global_transform()*target; motion.global_position=motion.position
		root.push_input(motion,true); tray._process(.03)
	max_frame_ms=0.0
	var start:=Time.get_ticks_usec()
	if kind=="reorder":
		var release:=InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.position=tray.get_global_transform()*target; release.global_position=release.position
		root.push_input(release,true)
	var cpu_ms: float=(Time.get_ticks_usec()-start)/1000.0
	await process_frame; await RenderingServer.frame_post_draw
	var draw_ms: float=(Time.get_ticks_usec()-start)/1000.0
	await process_frame
	var current_hand=app.find_child("hand_fan",true,false)
	var moved: bool=kind=="idle" or current_hand.cards[destination].uid==moved_uid
	if not moved: failures+=1; printerr("Probe release did not reorder")
	samples.append({"kind":kind,"cpu_ms":cpu_ms,"through_draw_ms":draw_ms,"max_frame_ms":max_frame_ms,"same_hud":old_hud==app.layout.get_instance_id(),"same_hand":old_hand==current_hand.get_instance_id(),"same_rules":state==app.session.snapshot(),"moved":moved})
func run():
	if DisplayServer.get_name()=="headless": printerr("Requires graphical renderer"); quit(1); return
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.session.give("wood",5,false,"reorder-probe"); app.render()
	await create_timer(1).timeout
	# Exercise the real synchronous preference write too, using a disposable path.
	app.hand_layout.path="user://reorder-probe.cfg"; app.persistence=true
	for i in range(3): await measure("reorder",i)
	samples.clear()
	for i in range(30):
		await measure("idle",i); await measure("reorder",i)
	var output: String="res://evidence/hand-reorder-probe.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(samples,"\t")); file.close()
	for kind in ["idle","reorder"]:
		var rows: Array=samples.filter(func(s): return s.kind==kind)
		for metric in ["cpu_ms","through_draw_ms","max_frame_ms"]:
			var values: Array=rows.map(func(s): return s[metric]); values.sort()
			print("%s %s median=%.3f p95=%.3f max=%.3f" % [kind,metric,values[14],values[28],values[29]])
	print("retained HUD/hand: %d/%d; rules: %d/%d" % [samples.filter(func(s): return s.same_hud and s.same_hand).size(),samples.size(),samples.filter(func(s): return s.same_rules).size(),samples.size()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.hand_layout.path))
	app.queue_free(); await process_frame; quit(failures)
