extends SceneTree
## GPU appearance/draw-call regression against the frozen pre-optimization frame.
const Frame = preload("res://presentation/nautical_frame.gd")
const Legacy = preload("res://tests/fixtures/paper_frame_legacy.gd")
var failures := 0
var results: Array = []
var viewport: SubViewport

func _init(): call_deferred("run")
func check(ok: bool, why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)

func capture(frame: Control, size_value: Vector2, zoom: float, opacity: float, is_paper: bool, release: bool = true) -> Dictionary:
	frame.paper=is_paper; frame.paper_opacity=opacity
	frame.position=Vector2(8.25,8.5); frame.size=size_value; frame.scale=Vector2.ONE*zoom
	viewport.add_child(frame)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	var draws:=viewport.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	# Exercise redraw without geometry changes as well as initial construction.
	frame.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	check(image.get_data()==viewport.get_texture().get_image().get_data(),"Unchanged redraw preserves pixels")
	viewport.remove_child(frame)
	if release: frame.free()
	return {"image":image,"draws":draws}

func run():
	if DisplayServer.get_name()=="headless": printerr("Requires graphical renderer"); quit(1); return
	Engine.max_fps=0; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	viewport=SubViewport.new(); viewport.size=Vector2i(1700,500)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	for spec in [[Vector2(1244,208),1.0,.7,true],[Vector2(1244,208),1.25,.7,true],[Vector2(930.5,173.75),1.1,.35,true],[Vector2(1580,280),1.0,1.0,true],[Vector2(80,80),1.25,0.0,true],[Vector2(1244,208),1.0,.7,false],[Vector2(1555,260),.8,.7,true],[Vector2(1244,208),1.2,.7,true]]:
		var old=await capture(Legacy.new(),spec[0],spec[1],spec[2],spec[3])
		var current=await capture(Frame.new(),spec[0],spec[1],spec[2],spec[3])
		var before: PackedByteArray=old.image.get_data(); var after: PackedByteArray=current.image.get_data()
		var changed:=0; var max_error:=0
		if before!=after:
			for i in range(before.size()):
				var error:=absi(int(before[i])-int(after[i]))
				if error>0: changed+=1; max_error=maxi(max_error,error)
		check(max_error<=1,"Original appearance within one RGBA byte: size=%s scale=%s error=%d" % [spec[0],spec[1],max_error])
		check(current.draws<100,"Paper draw budget <100: got %d at %s" % [current.draws,spec[0]])
		results.append({"size":str(spec[0]),"scale":spec[1],"paper_opacity":spec[2],"paper":spec[3],"old_draws":old.draws,"new_draws":current.draws,"changed_channels":changed,"max_byte_error":max_error})
		if results.size()==1:
			old.image.save_png("res://evidence/paper-grain-before.png")
			current.image.save_png("res://evidence/paper-grain-after.png")
		print("PAPER_GRAIN "+JSON.stringify(results[-1]))
	# Reuse one frame through resize, including zero-dot and sub-minimum bounds.
	var frame:=Frame.new()
	for size_value in [Vector2(1244,208),Vector2(80,80),Vector2(20,20),Vector2(930,170),Vector2(1244,208)]:
		var reference=await capture(Legacy.new(),size_value,1.0,.7,true)
		var resized=await capture(frame,size_value,1.0,.7,true,false)
		check(resized.draws<100,"Resize stays within draw budget: "+str(size_value))
		var equal: bool=reference.image.get_data()==resized.image.get_data()
		check(equal,"Reused frame pixels match legacy after resize: "+str(size_value))
		results.append({"resize":true,"size":str(size_value),"pixels_equal":equal,"new_draws":resized.draws,"old_draws":reference.draws})
	frame.free(); viewport.queue_free(); await process_frame
	var file:=FileAccess.open("res://evidence/paper-grain-visual-20261019.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"cases":results},"\t")); file.close()
	print("PAPER GRAIN: "+("PASS" if failures==0 else "FAIL")); quit(failures)
