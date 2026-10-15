extends SceneTree
var failures:=0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func run() -> void:
	var prefs=load("res://presentation/display_settings.gd").new(false)
	prefs.resolution=Vector2i(960,540); prefs.apply_window(root)
	await process_frame; await process_frame
	check(root.mode==Window.MODE_WINDOWED and root.size==Vector2i(960,540),"Desktop window resolution applies")
	prefs.fullscreen=true; prefs.apply_window(root)
	await process_frame; await process_frame
	check(root.mode==Window.MODE_FULLSCREEN,"Desktop fullscreen applies")
	prefs.resolution=Vector2i(960,540)
	check(prefs.render_size(Vector2(1600,900),Vector2i(1920,1080))==Vector2i(960,540),"Fullscreen resolution controls scene render target")
	prefs.fullscreen=false; prefs.resolution=Vector2i(1280,720); prefs.apply_window(root)
	await process_frame; await process_frame
	check(root.mode==Window.MODE_WINDOWED and root.size==Vector2i(1280,720),"Fullscreen can return to selected window size")
	print("DISPLAY WINDOW: "+("PASS" if failures==0 else "FAIL")); quit(failures)
