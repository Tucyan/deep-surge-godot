extends SceneTree
var failures:=0
func check(ok: bool,why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void: call_deferred("run")
func run() -> void:
	var catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalogue loads")
	var assets=load("res://presentation/asset_catalog.gd").new()
	var session=load("res://core/game_session.gd").new(catalog)
	check(session.dispatch("new",{"mode":"challenge","origin":"strong","seed":22}),"challenge starts")
	for kind in ["battle","ruin"]:
		var page=load("res://pages/flow_story.gd").new(); root.add_child(page)
		page.size=Vector2(1600,700); page.theme=load("res://presentation/widgets.gd").theme()
		var view: Dictionary=session.view()
		view.phase="story"; view.story_step="choice"
		view.node=catalog.entry("nodes",kind); view.node.visit_id="exit-ui-test"
		view.event_options=[]
		page.setup(view,catalog,assets)
		await process_frame; await process_frame
		var exit_button: Button=page.find_child("NodeEventAction_leave_encounter",true,false)
		check(exit_button!=null,"encounter exposes exit control")
		if exit_button!=null:
			if kind=="battle": check("4生命" in exit_button.text and "可致死" in exit_button.tooltip_text,"ordinary prebattle exit advertises lethal HP cost")
			else: check("保护" in exit_button.text and "4生命" not in exit_button.text,"ruin exit retains protected wording")
		page.free()
	print("V03 EVENT EXIT: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
