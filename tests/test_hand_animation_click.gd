extends SceneTree
var failures:=0
var fan
var clicks: Array=[]
func _init(): call_deferred("run")
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func setup():
	if is_instance_valid(fan): fan.free()
	fan=preload("res://presentation/hand_fan.gd").new(); root.add_child(fan)
	fan.position=Vector2(80,400); fan.size=Vector2(900,240)
	var catalog=preload("res://content/catalog.gd").new(); catalog.load_catalog()
	var card:={"uid":"moving-wood","id":"wood","temporary":false,"definition":catalog.entry("cards","wood")}
	fan.create(preload("res://presentation/asset_catalog.gd").new(),[card],{"phase":"navigation","can_base":true,"battle":{},"hand":[card]})
	fan.arrange(); fan.set_process(false); fan.activated.connect(func(c):clicks.append(c.uid)); clicks.clear()
func press(point: Vector2):
	var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=true; e.position=point
	fan._gui_input(e)
func release(point: Vector2):
	var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.global_position=fan.global_position+point
	fan._input(e)
func move(point: Vector2):
	var e:=InputEventMouseMotion.new(); e.global_position=fan.global_position+point; fan._input(e)
func run():
	setup(); var point: Vector2=fan.tiles[0].position+Vector2(30,60)
	press(point); fan.tiles[0].position.x+=60; move(point)
	check(fan.pressed_index==0,"stationary pointer is not canceled by card animation")
	release(point); check(clicks.size()==1,"stationary click activates once despite animated tile motion")
	setup(); point=fan.tiles[0].position+Vector2(30,60)
	press(point); fan.tiles[0].position.x+=200; release(point)
	check(clicks.size()==1,"release uses original press when animation moved the card")
	setup(); point=fan.tiles[0].position+Vector2(30,60)
	press(point); move(point+Vector2(20,0)); release(point+Vector2(20,0))
	check(clicks.is_empty(),"real pointer movement still cancels an unheld click")
	setup(); point=fan.tiles[0].position+Vector2(30,60)
	press(point); release(Vector2(-500,-500)); check(clicks.is_empty(),"outside release never activates")
	setup(); point=fan.tiles[0].position+Vector2(30,60)
	fan.buttons[0].disabled=true; press(point); release(point); check(clicks.is_empty(),"disabled card never activates")
	setup(); point=fan.tiles[0].position+Vector2(30,60)
	press(point); fan._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT); release(point)
	check(clicks.is_empty(),"focus loss still cancels gesture")
	fan.queue_free(); await process_frame
	print("HAND ANIMATION CLICK: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
