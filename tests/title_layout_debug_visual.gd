extends SceneTree
var failures:=0
func _init(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures+=1; printerr(message)
func run():
	root.size=Vector2i(1280,720)
	var menu=load("res://presentation/title_menu.gd").new(); root.add_child(menu); menu.size=Vector2(1280,720); menu.create({"active":false,"has_run":false})
	await create_timer(0.4).timeout
	var panel=menu.layout_debug
	check(panel!=null,"debug panel missing")
	panel.toggle_editor()
	var original=panel.snapshot()
	for i in range(7):
		panel.picker.select(i); panel.sync_fields()
		var target=panel.targets[i]
		var ratio:float=target.size.x/target.size.y
		panel.fields[0].value=original.items[panel.KEYS[i]].x-12
		panel.fields[2].value=original.items[panel.KEYS[i]].width+20
		check(abs(target.position.x-(original.items[panel.KEYS[i]].x-12))<0.1,"live position")
		check(abs(target.size.x/target.size.y-ratio)<0.001,"locked aspect")
	var adjusted=panel.snapshot()
	check(panel.save_to("res://evidence/title-layout-debug-export.json"),"export failed")
	check(panel.apply_snapshot(original),"restore default failed")
	check(panel.apply_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://evidence/title-layout-debug-export.json"))),"export read failed")
	check(panel.snapshot()==adjusted,"round trip mismatch")
	check(not panel.apply_snapshot({"schema":1,"items":{}}),"invalid import accepted")
	check(panel.snapshot()==adjusted,"invalid data mutated layout")
	panel.apply_snapshot(original); panel.picker.select(6); panel.sync_fields(); panel.status.text="验证完成 · 调整参数后保存或导出"
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/title-layout-debug-panel.png")
	panel.toggle_editor(); check(menu.buttons[0].mouse_filter==Control.MOUSE_FILTER_STOP,"interaction not restored")
	menu.queue_free(); await process_frame
	print("TITLE LAYOUT DEBUG: PASS" if failures==0 else "TITLE LAYOUT DEBUG: FAIL"); quit(0 if failures==0 else 1)
