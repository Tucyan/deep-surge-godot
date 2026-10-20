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
	app.display_settings.mobile=true; app.display_settings.free_aspect=true
	root.add_child(app); await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.session.give("wood",3,false,"mobile-layout-test")
	app.handle_ui("local_panel","craft"); app.handle_ui("craft_tab","transmute"); await settle()
	var saved: Dictionary=app.session.snapshot()
	var columns=app.find_child("TransmuteColumns",true,false)
	var left=app.find_child("TransmuteInventory",true,false)
	var middle=app.find_child("TransmuteCore",true,false)
	var right=app.find_child("TransmuteRightCol",true,false)
	check(columns!=null and columns is HBoxContainer,"phone transmutation keeps three side-by-side columns")
	check(left!=null and middle!=null and right!=null,"phone transmutation keeps material, target and confirm columns")
	if columns!=null and left!=null and middle!=null and right!=null:
		check(left.position.x<middle.position.x and middle.position.x<right.position.x,"phone columns read left to right")
		check(absf(left.position.y-middle.position.y)<2.0 and absf(middle.position.y-right.position.y)<2.0,"phone columns share one row")
		check(middle.size.x<maxf(left.size.x,right.size.x)*1.3,"phone middle column stays narrower")
		check(middle.size.x>maxf(left.size.x,right.size.x)*0.9,"phone middle column keeps usable width")
	# A page scroll stays available for short screens, so touch drags never select material.
	var scroll=app.find_child("MobileTransmutePageScroll",true,false)
	check(scroll!=null,"phone transmutation keeps a page scroll for short screens")
	var card=app.find_child("MatItem_wood",true,false)
	check(card!=null,"phone transmutation shows one card per material type")
	if card!=null:
		var point: Vector2=card.get_global_rect().position+Vector2(24,24)
		touch(point,true); await process_frame
		check(str(app.ui_state.get("transmute_uids",""))=="","touching a material surface does not allocate before release")
		var drag:=InputEventScreenDrag.new(); drag.index=0
		drag.position=point-Vector2(0,90); drag.relative=Vector2(0,-90)
		root.push_input(drag,true); await process_frame
		touch(point-Vector2(0,90),false); await settle()
		check(str(app.ui_state.get("transmute_uids",""))=="","dragging a material card never allocates material")
	var add=app.find_child("AddMaterial_wood",true,false)
	check(add==null,"material cards no longer carry a separate 投入1张 button")
	# A tap (press + release in place) adds one card; the invested slot takes it back.
	if card!=null:
		var tap_point: Vector2=card.get_global_rect().get_center()
		touch(tap_point,true); await process_frame
		touch(tap_point,false); await settle()
		var selected=str(app.ui_state.get("transmute_uids",""))
		check(selected not in ["","none"] and not ("," in selected),"tapping a material card allocates one instance")
	var slot=app.find_child("DiagramSlot1",true,false)
	check(slot!=null and slot.mouse_filter==Control.MOUSE_FILTER_STOP,"invested material has a native tap target")
	if slot!=null:
		var slot_point: Vector2=slot.get_global_rect().get_center()
		touch(slot_point,true); await process_frame
		touch(slot_point,false); await settle()
		check(str(app.ui_state.get("transmute_uids",""))=="none","tapping the invested slot returns the material")
	check(app.session.snapshot()==saved,"selection preserves AP, inventory and RNG")
	app.queue_free(); await settle()
	print("MOBILE TRANSMUTE LAYOUT: "+("PASS" if failures==0 else "FAIL")); quit(failures)
