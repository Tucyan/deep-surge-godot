extends SceneTree
var app
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _init() -> void:
	call_deferred("run"); call_deferred("watchdog")
func watchdog() -> void:
	await create_timer(30).timeout
	printerr("EXPANSION UI: timeout"); quit(2)
func settle() -> void:
	await process_frame; await process_frame
func show_target(point: Vector2i) -> Button:
	app.handle_command("panel",{"id":"raft"})
	app.handle_ui("selected_id","pos:%d:%d" % [point.x,point.y])
	await settle()
	var buttons=app.find_children("*","Button",true,false).filter(func(b):return b.text=="扩建 (%d,%d)" % [point.x,point.y])
	return buttons[0] if not buttons.is_empty() else null
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.session.state.hand=[]; app.session.give("wood",6)
	for point in [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)]:
		var button=await show_target(point)
		check(button!=null and not button.disabled,"discounted expansion enabled")
		check(app.find_children("*","Label",true,false).any(func(label):return label.text=="木头1 · 基地AP1"),"detail quotes one wood")
		if button==null: quit(1); return
		if point.x==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/expansion-v15-1280x720.png")
		var wood: int=app.session.I.count(app.session.state,"wood")
		button.pressed.emit(); await settle()
		check(app.session.I.count(app.session.state,"wood")==wood-1,"real button spends discounted cost")
	root.size=Vector2i(1600,900)
	app.session.state.cells[-1].status="detached"; app.session.state.ap=1
	app.session.state.hand=[]; app.session.give("wood")
	var button=await show_target(Vector2i(2,0))
	check(button!=null and button.disabled,"fourth expansion unavailable with one wood")
	check(app.find_children("*","Label",true,false).any(func(label):return label.text=="木头2 · 基地AP1"),"detail quotes full cost after discount")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/expansion-v15-1600x900.png")
	app.session.give("wood"); button=await show_target(Vector2i(2,0))
	check(button!=null and not button.disabled,"two wood enables fourth expansion")
	if button!=null: button.pressed.emit(); await settle()
	check(app.session.state.expansion_count==4 and app.session.I.count(app.session.state,"wood")==0,"fourth UI expansion spends two wood")
	app.queue_free(); await process_frame
	print("EXPANSION UI: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
