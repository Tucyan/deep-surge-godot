extends SceneTree
var app
var failures:=0
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func settle():
	for i in range(8): await process_frame
func touch(point: Vector2, pressed: bool):
	var event:=InputEventScreenTouch.new(); event.index=0; event.pressed=pressed
	event.position=point; root.push_input(event,true)
func run():
	app=load("res://scenes/main.tscn").instantiate(); app.persistence=false
	app.display_settings.mobile=true; root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.session.give("wood",3,false,"mobile-scroll-test")
	app.handle_ui("local_panel","craft"); app.handle_ui("craft_tab","transmute"); await settle()
	var saved: Dictionary=app.session.snapshot()
	var scroll=app.find_child("MobileTransmutePageScroll",true,false)
	var card=app.find_child("MatItem_wood",true,false)
	var point: Vector2=card.get_global_rect().position+Vector2(24,24)
	touch(point,true); await process_frame
	check(str(app.ui_state.get("transmute_uids",""))=="","touching a material surface does not allocate before release")
	var drag:=InputEventScreenDrag.new(); drag.index=0
	drag.position=point-Vector2(0,90); drag.relative=Vector2(0,-90)
	root.push_input(drag,true); await process_frame
	touch(point-Vector2(0,90),false); await settle()
	check(scroll.scroll_vertical>0,"dragging the material card scrolls the page")
	check(str(app.ui_state.get("transmute_uids",""))=="","scrolling never allocates material")
	scroll.scroll_vertical=120; await settle()
	var add=app.find_child("AddMaterial_wood",true,false)
	check(add!=null and not add.disabled,"explicit material action is available")
	if add: add.pressed.emit()
	await settle()
	check(not str(app.ui_state.get("transmute_uids","")).is_empty(),"explicit material action selects one instance")
	check(app.find_child("MobileTransmutePageScroll",true,false).scroll_vertical==120,"material selection preserves reading position")
	scroll=app.find_child("MobileTransmutePageScroll",true,false)
	var slot=app.find_child("RemoveTransmuteSlot_0",true,false)
	check(slot!=null,"invested material has a native release-based control")
	if slot:
		var selected: String=str(app.ui_state.transmute_uids)
		var desired: float=slot.global_position.y-scroll.global_position.y+scroll.scroll_vertical-100
		scroll.scroll_vertical=int(desired); await settle()
		point=slot.get_global_rect().get_center()
		touch(point,true); await process_frame
		check(str(app.ui_state.transmute_uids)==selected,"touching invested slot does not remove material")
		drag=InputEventScreenDrag.new(); drag.index=0; drag.position=point+Vector2(0,60); drag.relative=Vector2(0,60)
		root.push_input(drag,true); await process_frame
		touch(point+Vector2(0,60),false); await settle()
		check(str(app.ui_state.transmute_uids)==selected,"scrolling from invested slot never cancels material")
	check(app.session.snapshot()==saved,"selection and scrolling preserve AP, inventory and RNG")
	app.queue_free(); await settle()
	print("MOBILE TRANSMUTE SCROLL: "+("PASS" if failures==0 else "FAIL")); quit(failures)
