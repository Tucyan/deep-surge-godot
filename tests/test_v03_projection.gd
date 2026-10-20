extends SceneTree
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var catalog=load("res://content/catalog.gd").new(); catalog.load_catalog()
	var agent=load("res://adapters/agent_session.gd").new(catalog)
	check(agent.handle({"method":"reset","params":{"seed":22,"mode":"challenge","origin":"fool"}}).ok,"challenge reset")
	var before: Dictionary=agent._session.snapshot()
	var observation: Dictionary=agent.observe()
	check(observation.get("journey",{}).get("layer_label","")=="Ⅰ","Agent exposes public Roman layer label")
	check(observation.get("candidates",[{}])[0].get("visibility","")=="full","Agent retains public candidate visibility status")
	check(not observation.has("rng") and not observation.has("seed") and not observation.has("profile"),"Agent excludes live random state and profile")
	check(not observation.get("journey",{}).has("profile_id"),"journey excludes raw profile")
	var quote: Dictionary=observation.get("survival_settlement",{})
	check(quote.get("deprivation",{}).has("total") and quote.get("counts",{}).has("hunger") and quote.get("costs",{}).has("hydration"),"Agent exposes real damage, counts and costs")
	check(agent._session.snapshot()==before,"observe preserves rules and RNG")
	agent._session.state.player.hunger=0; agent._session.state.player.hydration=0
	agent._session.state.deprivation={"hunger":2,"hydration":1}
	var risk: Dictionary=agent.observe().survival_settlement
	check(risk.deprivation.hunger==3 and risk.deprivation.hydration==2 and risk.deprivation.total==5 and risk.counts.hunger==2,"Agent projects actual independently accumulated upcoming deprivation")
	agent._session.state.battle={"id":"probe","hp":8,"ap":2,"enemy_direct_damage":3,"rewards":{"coin":9},"source_outcome":"hidden","continuation":{"secret":true}}
	var battle: Dictionary=agent.observe().battle
	check(battle.hp==8 and not battle.has("rewards") and not battle.has("source_outcome") and not battle.has("continuation"),"battle preserves visible status and hides reward/provenance/continuation metadata")
	check(battle.get("enemy_direct_damage",-1)==3,"Agent preserves weather-adjusted public incoming damage")
	# Rule metadata must remain hidden even on a deterministic node option.
	agent._session.state.node={"id":"probe","name":"箱子","kind":"event","description":"打开取物","visit_id":"probe","battle_request":{"enemy":"secret"},"options":[{"id":"open","name":"打开","battle":{"enemy":"secret"},"battle_request":{"enemy":"secret"},"outcomes":[{"id":"hidden"}]}]}
	var node: Dictionary=agent.observe().get("node",{})
	check(not node.has("battle_request") and not node.get("options",[{}])[0].has("battle") and not node.get("options",[{}])[0].has("battle_request"),"node options hide battle metadata")
	var hud=load("res://pages/voyage_hud.gd").new()
	hud.context={"mode":"challenge","voyage":8,"length":25,"phase":"aftermath","journey":{"layer_label":"Ⅱ","layer_voyage":3,"layer_length":10},"revision":1,"survival_settlement":{"pending":true,"costs":{"hunger":45,"hydration":30},"deprivation":{"hunger":3,"hydration":2,"total":5},"counts":{"hunger":2,"hydration":1}}}
	hud.context.player={"hp":10,"hp_max":20,"hunger":0,"hunger_max":100,"hydration":0,"hydration_max":100,"sanity":60,"sanity_max":100}
	var status=load("res://presentation/hud/status_hud.gd").new(); hud.add_child(status); hud._status_hud=status
	hud.refresh_status()
	check("5生命" in status.tooltip_text and "累计饥饿2次" in status.tooltip_text,"status tooltip uses same actual damage/count projection")
	hud.context.survival_settlement.deprivation={"hunger":0,"hydration":0,"total":0}; hud.refresh_status()
	check("0生命" in status.tooltip_text,"status refresh reflects changed survival risk")
	hud.context.survival_settlement.deprivation={"hunger":3,"hydration":2,"total":5}
	var heading:=Label.new(); hud.add_child(heading); hud._heading_label=heading; hud.refresh_heading()
	check(heading.text.begins_with("Ⅱ · 航行 3/10"),"challenge heading uses Roman layer and local progress")
	var box:=VBoxContainer.new(); hud.add_child(box); hud.operation_content(box)
	var prose:=""
	for label in box.find_children("*","Label",true,false): prose+=label.text
	check("45" in prose and "30" in prose and "5生命" in prose and "累计" in prose and "2" in prose,"aftermath displays actual separate costs, damage and prior counts")
	for mode in ["story","tutorial"]:
		hud.context.mode=mode; hud.refresh_heading()
		check(heading.text.begins_with("第 8 / 25 次航行"),"story/tutorial retain voyage heading")
	for example in [{"mode":"challenge","kind":"battle","turn":2},{"mode":"challenge","kind":"ruin","turn":2},{"mode":"tutorial","kind":"battle","turn":2},{"mode":"challenge","kind":"battle","turn":1}]:
		var battle_view=load("res://pages/battle_hud_view.gd").new()
		battle_view.context={"mode":example.mode,"battle":{"turn":example.turn,"ap":2},"scene":{}}
		battle_view.hud=hud; battle_view.session=agent._session; battle_view.catalog=catalog
		agent._session.state.mode=example.mode; agent._session.state.node={"kind":example.kind}; agent._session.state.encounter={}
		battle_view.build_combat_log_panel(battle_view)
		var button: Button=battle_view.find_child("BattleRetreat",true,false)
		if example.mode=="tutorial": check(button.disabled and "教程" in button.tooltip_text,"tutorial retreat remains unavailable with accurate explanation")
		elif example.kind=="ruin": check("保护" in button.tooltip_text and "4生命" not in button.text,"protected exit does not advertise ordinary cost")
		else: check("4生命" in button.text and "可致死" in button.tooltip_text and button.disabled==(example.turn<2),"ordinary retreat advertises actual cost and turn restriction")
		var refreshed: Dictionary=battle_view.context.duplicate(true)
		refreshed.phase="battle"; refreshed.battle.id="biter"; refreshed.battle.hp=10
		battle_view.context=refreshed.duplicate(true)
		check(battle_view.refresh_after_action(refreshed),"same battle can refresh retained controls")
		check(button.disabled==(example.mode=="tutorial" or example.turn<2),"retained battle refresh preserves tutorial and turn retreat restrictions")
		battle_view.free()
	hud.free()
	var guide:=VBoxContainer.new()
	var settings=load("res://presentation/display_settings.gd").new()
	load("res://presentation/game_help.gd").build(guide,settings)
	var guide_text:=""
	for label in guide.find_children("*","Label",true,false): guide_text+=label.text
	check("分别航行5、10、10次" in guide_text and "均扣4生命" in guide_text and "累计次数保留" in guide_text,"help describes layered voyage, shared retreat cost and retained survival counts")
	check("剧情模式" not in guide_text,"hidden story mode remains absent from default help")
	guide.free()
	print("V03 PROJECTION: "+("PASS" if failures==0 else "FAIL")); quit(failures)
