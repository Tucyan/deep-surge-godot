extends SceneTree
## Real mouse routing in an isolated graphical game instance; no second input is
## sent between release and the first completed draw/state assertion.
class TimedApp extends "res://flow_app.gd":
	var render_us:=0
	var save_us:=0
	var ui_calls:=0
	var command_calls:=0
	func render() -> void:
		var start:=Time.get_ticks_usec(); super.render(); render_us+=Time.get_ticks_usec()-start
	func handle_ui(action: String,value: String="") -> void:
		ui_calls+=1; super.handle_ui(action,value)
	func handle_command(command: String,args: Dictionary={}) -> void:
		command_calls+=1; super.handle_command(command,args)
	func _persist_profile() -> bool:
		var start:=Time.get_ticks_usec(); var ok:=super._persist_profile(); save_us+=Time.get_ticks_usec()-start; return ok
var app
var failures:=0
var samples: Dictionary={}
var output_path:="res://evidence/interaction-latency.json"
var capture_prefix:="interaction-first-draw"
var focus_losses:=0
var input_samples:=20
func _init(): call_deferred("run")
func settle():
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
func mouse(point: Vector2,pressed: bool):
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
	event.position=root.get_final_transform()*point; event.global_position=event.position
	Input.parse_input_event(event); Input.flush_buffered_events()
func check(ok: bool,why: String):
	if not ok: failures+=1; printerr("FAIL: "+why)
func measure(label: String,point: Vector2,ready: Callable,same_rules: bool=true,diagnostics: Dictionary={}):
	var before: Dictionary=app.session.snapshot()
	var layout_id: int=app.layout.get_instance_id()
	var motion:=InputEventMouseMotion.new(); motion.position=root.get_final_transform()*point; motion.global_position=motion.position
	Input.parse_input_event(motion); Input.flush_buffered_events()
	mouse(point,true); await process_frame
	var fan=app.find_child("hand_fan",true,false)
	if is_instance_valid(fan):
		diagnostics.press_index=fan.pressed_index
		diagnostics.release_hit=fan.hit_card(point-fan.global_position)
	diagnostics.focus_losses=focus_losses
	app.render_us=0; app.save_us=0; app.ui_calls=0; app.command_calls=0
	var start:=Time.get_ticks_usec()
	mouse(point,false)
	var sync_ms: float=(Time.get_ticks_usec()-start)/1000.0
	await RenderingServer.frame_post_draw
	var draw_ms: float=(Time.get_ticks_usec()-start)/1000.0
	var ready_on_draw: bool=ready.call()
	if ready_on_draw and label not in ["idle"]:
		check(layout_id==app.layout.get_instance_id(),label+" preserves main HUD")
	var ready_later:=ready_on_draw
	if not ready_on_draw:
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		ready_later=ready.call()
		printerr("INPUT_MISS %s point=%s diagnostics=%s ready_without_more_input=%s" % [label,point,diagnostics,ready_later])
	check(ready_on_draw,label+" updates by first draw without another input")
	if same_rules:
		var after: Dictionary=app.session.snapshot()
		# Opening/closing a core panel is a valid dispatch and advances revision,
		# while state/profile/RNG remain unchanged.
		if label in ["craft_open","craft_close"]: before.revision=after.revision
		check(after==before,label+" preserves rules/RNG")
	var data:={"sync_ms":sync_ms,"draw_ms":draw_ms,"render_ms":app.render_us/1000.0,"save_ms":app.save_us/1000.0,"ui_calls":app.ui_calls,"commands":app.command_calls,"rebuild":layout_id!=app.layout.get_instance_id(),"ready_first_draw":ready_on_draw,"ready_later":ready_later}
	if not samples.has(label): samples[label]=[]
	if samples[label].is_empty() and label in ["navigation_select","settings_open","craft_open","battle_resource","battle_action"]:
		root.get_texture().get_image().save_png("res://evidence/"+capture_prefix+"-"+label+".png")
	samples[label].append(data)
	print("INPUT_LATENCY %s %s" % [label,JSON.stringify(data)])
	await process_frame
func button(label: String,node: Button,ready: Callable,same_rules: bool=true):
	check(node!=null and node.is_visible_in_tree() and not node.disabled,label+" clickable")
	if node==null or not node.is_visible_in_tree() or node.disabled: return
	var diagnostics:={"down":0,"up":0,"pressed":0,"rect":str(node.get_global_rect())}
	node.button_down.connect(func():diagnostics.down+=1,CONNECT_ONE_SHOT)
	node.button_up.connect(func():diagnostics.up+=1,CONNECT_ONE_SHOT)
	node.pressed.connect(func():diagnostics.pressed+=1,CONNECT_ONE_SHOT)
	await measure(label,node.get_global_rect().get_center(),ready,same_rules,diagnostics)
func card_point(kind: String,uid: String="") -> Dictionary:
	var fan=app.find_child("hand_fan",true,false)
	for i in range(fan.cards.size()):
		if not kind.is_empty() and fan.cards[i].definition.kind!=kind: continue
		if not uid.is_empty() and fan.cards[i].uid!=uid: continue
		var tile: Control=fan.tiles[i]
		for y in [.8,.6,.4]:
			for x in [.8,.5,.2]:
				var point: Vector2=tile.position+tile.size*tile.scale*Vector2(x,y)
				var global_point: Vector2=fan.global_position+point
				if not fan.get_viewport_rect().has_point(global_point): continue
				var ancestor: Node=fan; var clipped:=false
				while ancestor is Control:
					if ancestor.clip_contents and not ancestor.get_global_rect().has_point(global_point): clipped=true; break
					ancestor=ancestor.get_parent()
				if not clipped and Rect2(Vector2.ZERO,fan.size).has_point(point) and fan.hit_card(point)==i:
					return {"point":global_point,"uid":fan.cards[i].uid}
	return {}
func setup_battle():
	app.persistence=false
	app.session=preload("res://core/game_session.gd").new(app.catalog)
	check(app.session.dispatch("new",{"mode":"challenge","origin":"strong","seed":42}),"fresh combat fixture starts")
	var state: Dictionary=app.session.state
	state.hand=[]; state.node=app.catalog.entry("nodes","battle"); state.node.visit_id="input-latency-combat"
	state.phase="battle"
	state.battle={"id":"biter","hp":28,"turn":1,"ap":3,"entry_hp":40,"poison_until":0,"fear_until":0,"shields":[],"raft_target_cell":state.cells[0].id,"intent":{"type":"biter_bite","target_cell":state.cells[0].id,"cell_damage":1}}
	app.session.give("wood",2,false,"latency-fixture"); app.session.give("cloth",1,false,"latency-fixture"); app.session.give("iron",1,false,"latency-fixture")
	app.render(); await create_timer(1).timeout
func focus_input_delivery():
	await setup_battle()
	print("INPUT_COORDS visible=%s physical=%s final=%s" % [root.get_visible_rect(),root.size,root.get_final_transform()])
	for i in range(12):
		await create_timer(.18).timeout
		var card:=card_point("resource"); var fan=app.find_child("hand_fan",true,false)
		var local_point: Vector2=card.point-fan.global_position
		var before_hit: int=fan.hit_card(local_point)
		app.ui_calls=0
		mouse(card.point,true)
		var pressed_now: int=fan.pressed_index
		await process_frame
		var pressed_later: int=fan.pressed_index
		var release_hit: int=fan.hit_card(card.point-fan.global_position)
		mouse(card.point,false)
		await RenderingServer.frame_post_draw
		print("INPUT_DELIVERY i=%d logical=%s physical=%s hit=%d pressed_now=%d pressed_later=%d release_hit=%d callbacks=%d" % [i,card.point,root.get_final_transform()*card.point,before_hit,pressed_now,pressed_later,release_hit,app.ui_calls])
		check(app.ui_calls>0,"focused resource click delivered")
	app.queue_free(); await process_frame
	print("FOCUSED INPUT: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
func stats(values: Array) -> Dictionary:
	values.sort(); var n:=values.size()
	return {"n":n,"median":values[n/2],"p95":values[mini(n-1,int(ceil(n*.95))-1)],"max":values[-1]}
func run():
	if DisplayServer.get_name()=="headless": printerr("Graphical renderer required"); quit(1); return
	Input.use_accumulated_input=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output_path=arg.trim_prefix("--output=")
		if arg.begins_with("--capture-prefix="): capture_prefix=arg.trim_prefix("--capture-prefix=")
		if arg.begins_with("--input-samples="): input_samples=clampi(int(arg.trim_prefix("--input-samples=")),20,100)
	root.focus_exited.connect(func():focus_losses+=1)
	root.size=Vector2i(1280,720)
	app=TimedApp.new(); app.persistence=false; app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(app)
	await settle()
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	await create_timer(1).timeout
	if "--focus-input" in OS.get_cmdline_user_args(): await focus_input_delivery(); return
	for i in range(20):
		var start:=Time.get_ticks_usec(); await RenderingServer.frame_post_draw
		if not samples.has("idle"): samples.idle=[]
		samples.idle.append({"draw_ms":(Time.get_ticks_usec()-start)/1000.0,"sync_ms":0.0,"render_ms":0.0,"save_ms":0.0})
		await process_frame
	for i in range(input_samples):
		app.ui_state.card=""
		var card:=card_point("resource"); check(not card.is_empty(),"resource hit point exists")
		if card.is_empty(): break
		await measure("resource_card",card.point,func():return app.ui_state.card==card.uid and app.ui_calls>0)
	for i in range(input_samples):
		await settle()
		var options: Array=app.find_children("NavigationOption","Button",true,false)
		if options.is_empty(): break
		var option: Button=options[i%options.size()]; var id: String=str(option.get_meta("visit_id"))
		await button("navigation_select",option,func():return app.ui_calls>0 and str(app.ui_state.get("nav_select",""))==id and app.find_child("NavigationDepart",true,false)!=null)
	for i in range(5):
		await button("camera_toggle",app.find_child("ToggleRaftView",true,false),func():return app.ui_calls>0)
		await settle()
		var menu=app.find_child("VoyageMenu",true,false)
		var settings: Button=menu.get_children().filter(func(n):return n is Button and n.text=="设置")[0]
		await button("settings_open",settings,func():return app.local_panel=="settings" and app.find_child("ModalSurface",true,false)!=null)
		await settle()
		await button("settings_close",app.find_child("ModalSurface",true,false).find_child("CloseX",true,false),func():return app.local_panel=="")
		await settle()
		await button("craft_open",app.find_child("CraftEntry",true,false),func():return app.session.panel=="craft")
		await settle()
		await button("craft_close",app.find_child("ModalSurface",true,false).find_child("CloseX",true,false),func():return app.session.panel=="")
		await settle()
	# State-changing departure: isolated profile path, saving off/on measured separately.
	var snapshot: Dictionary=app.session.snapshot()
	app.store.path="user://interaction-latency-profile.json"
	for saving in [false,true]:
		for i in range(5):
			app.persistence=false; app.session.restore(snapshot); app.session.dispatch("resume"); app.ui_state.nav_select=""; app.render(); await settle()
			var option: Button=app.find_children("NavigationOption","Button",true,false)[0]
			option.pressed.emit(); await settle()
			app.persistence=saving
			await button("depart_save" if saving else "depart_no_save",app.find_child("NavigationDepart",true,false),func():return app.session.phase()=="preparation",false)
	# Combat UI fixture follows verify_card_selection_and_double_click.gd.
	await setup_battle()
	for i in range(input_samples):
		var card:=card_point("resource"); check(not card.is_empty(),"battle resource hit point exists")
		if card.is_empty(): break
		var selected: String=app.find_child("BattleHUDView",true,false).selected_resource_uid
		var expected: String="" if selected==card.uid else card.uid
		await measure("battle_resource",card.point,func():
			return app.find_child("BattleHUDView",true,false).selected_resource_uid==expected and app.ui_calls>0)
		await create_timer(.15).timeout
	for i in range(input_samples/2):
		var card:=card_point("","virtual_action_attack"); check(not card.is_empty(),"battle action hit point exists")
		if card.is_empty(): break
		var selected: String=app.find_child("BattleHUDView",true,false).selected_action
		var expected: String="" if selected=="attack" else "attack"
		await measure("battle_action",card.point,func():
			return app.find_child("BattleHUDView",true,false).selected_action==expected and app.ui_calls>0)
		await create_timer(.15).timeout
	var summary:={}
	for label in samples:
		summary[label]={}
		for field in ["sync_ms","draw_ms","render_ms","save_ms"]:
			summary[label][field]=stats(samples[label].map(func(s):return s[field]))
	var report:={"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"size":[1280,720],"failures":failures,"summary":summary,"samples":samples}
	var file:=FileAccess.open(output_path,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("INPUT_LATENCY_SUMMARY "+JSON.stringify(summary))
	app.queue_free(); await process_frame
	print("INTERACTION LATENCY: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
