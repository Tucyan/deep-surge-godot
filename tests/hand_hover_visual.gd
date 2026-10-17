extends SceneTree
var failures := 0
func _init():
	call_deferred("run")
	call_deferred("watchdog")
func watchdog():
	await create_timer(30).timeout
	printerr("HAND HOVER VISUAL: timeout"); quit(2)
func check(ok: bool, message: String):
	if not ok: failures+=1; printerr(message)
func run():
	root.size=Vector2i(1600,780)
	root.content_scale_size=Vector2i(1600,780)
	var host=Control.new(); root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme=preload("res://presentation/widgets.gd").theme()
	var bg=ColorRect.new(); bg.color=Color("102b3a"); host.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var catalog=preload("res://content/catalog.gd").new(); catalog.load_catalog()
	var session=preload("res://core/game_session.gd").new(catalog)
	session.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	var original=session.snapshot()
	var assets=preload("res://presentation/asset_catalog.gd").new()
	var fans=[]
	for row in range(2):
		var title=Label.new(); title.position=Vector2(24,20+row*380)
		title.text="重叠 4.9%：只上浮，右侧不移动" if row==0 else "明显重叠：上浮，并为右侧局部腾位"
		title.add_theme_font_size_override("font_size",23); host.add_child(title)
		var entries=[]
		for i in range(10 if row==0 else 14):
			var id=["cloth","iron","plastic","rope","wood"][i%5]
			entries.append({"uid":"hover-fixture-%d" % i,"id":id,"definition":catalog.entry("cards",id),"temporary":false})
		var fan=preload("res://presentation/hand_fan.gd").new(); host.add_child(fan)
		fan.position=Vector2(24,100+row*380); fan.size=Vector2(1552,250)
		var view=session.view(); view.hand_layout=preload("res://presentation/hand_layout.gd").new()
		view.hand_layout.stack_resources=false; view.hand_layout.auto_sort=false
		fan.create(assets,entries,view); fans.append(fan)
	for i in range(3): await process_frame
	for row in range(2):
		var fan=fans[row]
		if row==0: fan.size.x=40+fan.card_width+fan.card_face_width*.951*9
		fan.focus_card(4); fan._process(2.0); fan.tip.hide(); fan.set_process(false)
		var shift: float=fan.target_positions[5].x-fan.base_x[5]
		print("HOVER row=%d width=%f face=%f overlap=%f shift=%f" % [row,fan.size.x,fan.card_face_width,1.0-(fan.base_x[1]-fan.base_x[0])/fan.card_face_width,shift])
		check(absf(shift)<.001 if row==0 else shift>0,"Hover clearance row %d" % row)
		for tile in fan.tiles: check(tile.z_index==1,"Hover preserves draw order")
		check(fan.selected_uids.is_empty(),"No battle selection required")
		check(is_equal_approx(fan.target_positions[4].x,fan.base_x[4]),"Focused card horizontal anchor")
	await process_frame; await RenderingServer.frame_post_draw
	check(session.snapshot()==original,"Visual hover does not alter rules or RNG")
	check(root.get_texture().get_image().save_png("res://evidence/hand-hover-clearance.png")==OK,"Save hover screenshot")
	print("HAND HOVER VISUAL: PASS" if failures==0 else "HAND HOVER VISUAL: FAIL")
	host.queue_free(); await process_frame; quit(failures)
