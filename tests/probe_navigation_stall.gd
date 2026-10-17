extends SceneTree
## Diagnostic only. Uses a fresh session and uniquely named disposable save files.
## Splits the cost into rule dispatch, view/snapshot projection, saving, story
## gallery, partial HUD refresh and the wait to the next completed draw.
class TimedStore extends "res://adapters/save_store.gd":
	var write_us := 0
	func write(data: Dictionary) -> bool:
		var start := Time.get_ticks_usec()
		var ok := super.write(data)
		write_us=Time.get_ticks_usec()-start
		return ok
class TimedSession extends "res://core/game_session.gd":
	var dispatch_us := 0
	var view_us := 0
	func dispatch(command: String, args: Dictionary = {}) -> bool:
		var start := Time.get_ticks_usec()
		var ok := super.dispatch(command,args)
		dispatch_us=Time.get_ticks_usec()-start
		return ok
	func view() -> Dictionary:
		var start := Time.get_ticks_usec()
		var result := super.view()
		view_us=Time.get_ticks_usec()-start
		return result
class TimedApp extends "res://flow_app.gd":
	var render_us := 0
	var gallery_us := 0
	var partial_us := 0
	func render() -> void:
		var start := Time.get_ticks_usec()
		super.render()
		render_us=Time.get_ticks_usec()-start
	func select_navigation(visit_id: String) -> bool:
		partial_us=0
		var start := Time.get_ticks_usec()
		var ok := super.select_navigation(visit_id)
		partial_us=Time.get_ticks_usec()-start
		return ok
	func update_after_departure() -> bool:
		var start := Time.get_ticks_usec()
		var ok := super.update_after_departure()
		partial_us=Time.get_ticks_usec()-start
		return ok
var app
var failures := 0
var view_us_only := 0
var select_cpu: Array = []
var select_draw: Array = []
var select_ui: Array = []
var depart_cpu: Array = []
var depart_draw: Array = []
var depart_ui: Array = []
var depart_ui_nosave: Array = []
var depart_cpu_nosave: Array = []
var depart_cpu_save: Array = []
var depart_save: Array = []
var idle_draw: Array = []
var select_view: Array = []
var depart_dispatch: Array = []
var depart_view: Array = []
func _init(): call_deferred("run")
func reset_timers() -> void:
	app.render_us=0; app.gallery_us=0; app.partial_us=0
	app.session.dispatch_us=0; app.session.view_us=0
	if app.store.has_method("write"): app.store.write_us=0
func measure(label: String, operation: Callable, expect_rules_change: bool) -> Dictionary:
	var old_layout: int=app.layout.get_instance_id()
	var old_hand: int=app.find_child("hand_fan",true,false).get_instance_id()
	var old_interaction: int=app.find_child("RaftInteraction",true,false).get_instance_id()
	var old_cell: int=app.world_view.cells.get_child(0).get_instance_id()
	var before: Dictionary=app.session.snapshot()
	reset_timers()
	var start := Time.get_ticks_usec()
	operation.call()
	var cpu := Time.get_ticks_usec()-start
	await process_frame
	await RenderingServer.frame_post_draw
	var through_draw := Time.get_ticks_usec()-start
	var same_rules: bool=before==app.session.snapshot()
	var data := {"cpu":cpu/1000.0,"draw":through_draw/1000.0,"dispatch":app.session.dispatch_us/1000.0,"view":app.session.view_us/1000.0,"save":app.store.write_us/1000.0,"gallery":app.gallery_us/1000.0,"partial":app.partial_us/1000.0,"render":app.render_us/1000.0,"hud":old_layout!=app.layout.get_instance_id(),"hand":old_hand!=app.find_child("hand_fan",true,false).get_instance_id(),"interaction":old_interaction!=app.find_child("RaftInteraction",true,false).get_instance_id(),"cell":old_cell==app.world_view.cells.get_child(0).get_instance_id(),"rules":same_rules}
	print("NAV_PROBE %s cpu=%.3f dispatch=%.3f view=%.3f save=%.3f gallery=%.3f partial_ui=%.3f render=%.3f through_draw=%.3f replaced_hud=%s replaced_hand=%s replaced_interaction=%s same_cell=%s same_rules=%s" % [label,data.cpu,data.dispatch,data.view,data.save,data.gallery,data.partial,data.render,data.draw,data.hud,data.hand,data.interaction,data.cell,data.rules])
	if data.hud: failures+=1; printerr("FAIL: %s replaced the main layout" % label)
	if data.hand: failures+=1; printerr("FAIL: %s replaced the hand" % label)
	if data.interaction: failures+=1; printerr("FAIL: %s replaced the raft interaction" % label)
	if data.rules and expect_rules_change: failures+=1; printerr("FAIL: %s did not change the rules" % label)
	if not data.rules and not expect_rules_change: failures+=1; printerr("FAIL: %s changed the rule snapshot" % label)
	return data
func stats(values: Array) -> String:
	var sorted := values.duplicate(); sorted.sort()
	var count := sorted.size()
	if count == 0: return "n=0"
	var median: float = sorted[count/2] if count%2==1 else (sorted[count/2-1]+sorted[count/2])*0.5
	var p95: float = sorted[mini(count-1,maxi(0,int(ceil(count*0.95))-1))]
	return "n=%d median=%.3f p95=%.3f max=%.3f" % [count,median,p95,sorted[count-1]]
func option_for(visit_id: String) -> Button:
	for button in app.find_children("NavigationOption","Button",true,false):
		if str(button.get_meta("visit_id",""))==visit_id: return button
	return null
func run():
	if DisplayServer.get_name()=="headless": quit(1); return
	root.size=Vector2i(1280,720)
	app=TimedApp.new(); app.persistence=false
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(app)
	await process_frame
	app.session=TimedSession.new(app.catalog)
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
	await create_timer(1).timeout
	var test_store:=TimedStore.new()
	test_store.path="user://navigation-stall-probe-%d.json" % OS.get_process_id()
	app.store=test_store
	var initial: Dictionary=app.session.snapshot()
	var view: Dictionary=app.session.view()
	var candidates: Array=view.candidates
	var ids: Array=[]
	for candidate in candidates: ids.append(str(candidate.visit_id))
	print("NAV_PROBE content=%s candidates=%s" % [app.session.VERSION,ids])
	for i in range(30):
		var idle: Dictionary=await measure("idle_%d" % i,func():pass,false)
		idle_draw.append(idle.draw)
	# Page rebuilt from scratch once per switch is no longer expected: only the
	# navigation texts and rows are replaced.
	for i in range(30):
		var id: String=ids[i%ids.size()]
		var option:=option_for(id)
		if option == null: failures+=1; printerr("FAIL: no option for %s" % id); continue
		var data: Dictionary=await measure("select_%d" % i,func(): option.pressed.emit(),false)
		select_cpu.append(data.cpu); select_draw.append(data.draw); select_ui.append(data.partial); select_view.append(data.view)
		if str(app.ui_state.get("nav_select",""))!=id: failures+=1; printerr("FAIL: select_%d did not record the choice" % i)
	for saving in [false,true]:
		for i in range(15):
			app.persistence=false
			if not app.session.restore(initial): failures+=1; continue
			if not app.session.dispatch("resume"): failures+=1; continue
			app.ui_state.nav_select=""
			app.render()
			await process_frame
			var id: String=ids[i%ids.size()]
			var option:=option_for(id)
			if option == null: failures+=1; printerr("FAIL: no depart option for %s" % id); continue
			option.pressed.emit()
			await process_frame
			app.persistence=saving
			var depart=app.find_child("NavigationDepart",true,false)
			if depart == null: failures+=1; printerr("FAIL: no depart button for %s" % id); continue
			var data: Dictionary=await measure("depart_save_%s_%d" % [saving,i],func(): depart.pressed.emit(),true)
			depart_cpu.append(data.cpu); depart_draw.append(data.draw); depart_ui.append(data.partial); depart_view.append(data.view); depart_dispatch.append(data.dispatch)
			depart_save.append(data.save)
			if saving:
				depart_cpu_save.append(data.cpu)
			else:
				depart_cpu_nosave.append(data.cpu); depart_ui_nosave.append(data.partial)
			if app.session.phase()!="preparation": failures+=1; printerr("FAIL: depart_save_%s_%d did not reach preparation" % [saving,i])
	app.persistence=false
	for path in [test_store.path,test_store.path+".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	app.queue_free(); await process_frame
	print("NAV_PROBE STATS idle_draw[ms] %s" % stats(idle_draw))
	print("NAV_PROBE STATS select_sync[ms] %s" % stats(select_cpu))
	print("NAV_PROBE STATS select_partial_ui[ms] %s" % stats(select_ui))
	print("NAV_PROBE STATS select_view[ms] %s" % stats(select_view))
	print("NAV_PROBE STATS select_draw[ms] %s" % stats(select_draw))
	print("NAV_PROBE STATS depart_sync[ms] %s" % stats(depart_cpu))
	print("NAV_PROBE STATS depart_sync_nosave[ms] %s" % stats(depart_cpu_nosave))
	print("NAV_PROBE STATS depart_sync_save[ms] %s" % stats(depart_cpu_save))
	print("NAV_PROBE STATS depart_partial_ui_nosave[ms] %s" % stats(depart_ui_nosave))
	print("NAV_PROBE STATS depart_save_write[ms] %s" % stats(depart_save))
	print("NAV_PROBE STATS depart_dispatch[ms] %s" % stats(depart_dispatch))
	print("NAV_PROBE STATS depart_view[ms] %s" % stats(depart_view))
	print("NAV_PROBE STATS depart_partial_ui[ms] %s" % stats(depart_ui))
	print("NAV_PROBE STATS depart_draw[ms] %s" % stats(depart_draw))
	print("NAVIGATION STALL DIAGNOSTIC: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
