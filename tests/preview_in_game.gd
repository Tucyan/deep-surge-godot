extends SceneTree
## In-game visual capture of the phone node event. Drives the real command
## flow (new -> voyage -> enter) so the persistent HUD, top status bar and hand
## strip behave exactly as they do in play, then captures
## evidence/node-event-phone-<prefix>-*.png. DS_SHOT_PREFIX names the run.
## The last two captures inject a long prose to check the text plate.
var app
var failures := 0

func _init() -> void: call_deferred("run")

func settle() -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw

func prefix() -> String:
	var p := OS.get_environment("DS_SHOT_PREFIX")
	return p if p != "" else "phone"

func capture(name: String) -> void:
	await settle()
	if root.get_texture().get_image().save_png("res://evidence/node-event-phone-"+name+".png") != OK:
		failures += 1; printerr("FAIL: save "+name)

func enter_node() -> void:
	app.handle_command("new", {"mode":"challenge","origin":"strong","seed":22})
	await settle()
	app.handle_command("voyage", {"id":app.session.state.candidates[0].visit_id})
	await settle()
	app.handle_command("enter")
	await settle()

func report(tag: String) -> void:
	var body = app.find_child("NodeEventBodyHost", true, false)
	var art = app.find_child("NodeEventArt", true, false)
	var prose = app.find_child("NodeEventProse", true, false)
	var choices = app.find_child("NodeEventOptions", true, false)
	if body == null or art == null or prose == null or choices == null:
		failures += 1; printerr("FAIL: event page missing "+tag); return
	var canvas: Vector2 = app.size
	print("%s | canvas %.0fx%.0f | host %.0fx%.0f @%.0f,%.0f | art %.0fx%.0f | prose %.0fx%.0f | options %.0fx%.0f" % [
		tag, canvas.x, canvas.y,
		body.size.x, body.size.y, body.get_global_rect().position.x, body.get_global_rect().position.y,
		art.size.x, art.size.y, prose.size.x, prose.size.y, choices.size.x, choices.size.y])
	var text = app.find_child("NodeEventText", true, false)
	var scroll = app.find_child("NodeEventProseScroll", true, false)
	var holder = app.find_child("NodeEventProseHolder", true, false)
	if scroll != null: print("   scroll %s holder %s" % [scroll.get_global_rect(), holder.get_global_rect() if holder != null else Rect2()])
	if text != null:
		for child in text.get_children():
			var label := child as Label
			print("   %-18s %s %s" % [str(child.name), str(child.get_global_rect()), label.text.left(14) if label != null else ""])

func long_text() -> void:
	var node: Dictionary = app.session.state.node
	node["description"] = "海面浮着一层薄雾，木筏边缘的灯忽明忽暗。远处的浪声比刚才更近，像是有什么正贴着水面跟过来。你把绳索又收紧一圈，指节冻得发白；这次出海带的东西不多，能换到的补给也只剩下压在箱底的那一点。舷侧的木板被泡得发胀，踩上去咯吱作响。你想起出发前答应过谁要把这批货送到，现在连方向都得靠罗盘上的红点猜。"
	app.render()
	await settle()
	await capture("long-text")
	node["description"] = "海面浮着一层薄雾，木筏边缘的灯忽明忽暗。远处的浪声比刚才更近，像是有什么正贴着水面跟过来。你把绳索又收紧一圈，指节冻得发白；这次出海带的东西不多，能换到的补给也只剩下压在箱底的那一点。舷侧的木板被泡得发胀，踩上去咯吱作响。你想起出发前答应过谁要把这批货送到，现在连方向都得靠罗盘上的红点猜。潮水一寸一寸往上漫，第三只箱子的封条已经被浸得翘起来；要不要先把它拖到灯下看看，还是趁着还有退路往岸边靠一靠，取决于你还剩多少时间。雾越来越浓，连桅杆顶端都看不清了，只有水声一下一下地敲着船底，像是有人在下面耐心地等。"
	app.render()
	await settle()
	await capture("longer-text")
	var prose = app.find_child("NodeEventProse", true, false)
	var scroll = app.find_child("NodeEventProseScroll", true, false)
	if prose != null and scroll != null:
		print("   long text | plate %.0fx%.0f | scroll %.0fx%.0f | content %.0f" % [prose.size.x, prose.size.y, scroll.size.x, scroll.size.y, scroll.get_child(0).get_combined_minimum_size().y])
	var extreme := "海面浮着一层薄雾，木筏边缘的灯忽明忽暗。远处的浪声比刚才更近，像是有什么正贴着水面跟过来。你把绳索又收紧一圈，指节冻得发白；这次出海带的东西不多，能换到的补给也只剩下压在箱底的那一点。舷侧的木板被泡得发胀，踩上去咯吱作响。你想起出发前答应过谁要把这批货送到，现在连方向都得靠罗盘上的红点猜。潮水一寸一寸往上漫，第三只箱子的封条已经被浸得翘起来；要不要先把它拖到灯下看看，还是趁着还有退路往岸边靠一靠，取决于你还剩多少时间。雾越来越浓，连桅杆顶端都看不清了，只有水声一下一下地敲着船底，像是有人在下面耐心地等。"
	node["description"] = extreme.repeat(3)
	app.render()
	await settle()
	await capture("extreme-text")
	var prose2 = app.find_child("NodeEventProse", true, false)
	var scroll2 = app.find_child("NodeEventProseScroll", true, false)
	if prose2 != null and scroll2 != null:
		var bar: VScrollBar = scroll2.get_v_scroll_bar()
		var before_y: float = scroll2.get_child(0).get_global_rect().position.y
		scroll2.scroll_vertical = 200
		await settle()
		var after_y: float = scroll2.get_child(0).get_global_rect().position.y
		print("   extreme text | plate %.0fx%.0f | scroll %.0fx%.0f | content %.0f | scrollable %s | bar %s vis=%s max=%.0f page=%.0f | scroll %.0f -> %.0f" % [prose2.size.x, prose2.size.y, scroll2.size.x, scroll2.size.y, scroll2.get_child(0).get_combined_minimum_size().y, str(bar.max_value > 1.0), str(bar.get_global_rect()), str(bar.is_visible_in_tree()), bar.max_value, bar.page, before_y, after_y])
	node["description"] = "浮箱里只有三份完好的东西，只能带走其中一份。"
	app.render()
	await settle()

func run() -> void:
	root.size = Vector2i(1680,720)
	app = load("res://scenes/main.tscn").instantiate()
	app.persistence = false
	root.add_child(app)
	await settle()
	app.display_settings.mobile = true
	app.display_settings.ui_scale = 1.25
	app.display_settings.free_aspect = true
	app.apply_display_settings(false)
	await enter_node()
	report("1680x720 intro")
	await capture("1680x720-intro")
	app.handle_command("advance")
	await settle()
	report("1680x720 choice")
	await capture("1680x720-choice")
	var page = app.find_child("NodeEventBody", true, false)
	var usable: Array = page.entries.filter(func(e): return not e.button.disabled)
	if not usable.is_empty():
		page.press(usable[0])
		await settle()
		report("1680x720 preselect")
		await capture("1680x720-preselect")
		if usable[0].get("cancel") != null: usable[0].cancel.pressed.emit()
		await settle()
	await long_text()
	root.size = Vector2i(1260,540)
	await settle()
	app.apply_display_settings(false)
	await settle()
	report("1260x540 choice")
	await capture("1260x540-choice")
	root.size = Vector2i(2520,1080)
	await settle()
	app.apply_display_settings(false)
	await settle()
	report("2520x1080 choice")
	await capture("2520x1080-choice")
	app.queue_free(); await settle()
	print("INGAME PREVIEW [%s]: %s" % [prefix(), "OK" if failures == 0 else "FAIL"])
	quit(failures)
