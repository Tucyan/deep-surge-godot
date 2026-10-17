extends "res://pages/flow_base.gd"
const RESOURCES = preload("res://core/inventory.gd").RESOURCES
const Difficulty = preload("res://core/difficulty_rules.gd")
const Tutorial = preload("res://core/tutorial_rules.gd")
var chosen_difficulty := ""
var picking := false
var initialized := false
func resource_limit() -> int:
	if chosen_difficulty == "tutorial": return Tutorial.STARTING.size()
	return int(Difficulty.profile(catalog,chosen_difficulty).get("starting_cards",5))
var chosen_origin := "strong"
var chosen_seed := "22"
var resource_counts := {}

func unlocked_ids() -> Array:
	var meta: Dictionary = context.get("meta",{})
	return meta.get("unlocked",["tutorial","standard"])

## Default to the last difficulty the player actually picked. A first-time player
## who has not finished the tutorial lands on the tutorial instead.
func default_difficulty() -> String:
	if context.setup_mode == "story":
		var previous := str(context.get("meta", {}).get("last_difficulty", "standard"))
		return previous if previous != "tutorial" and previous in unlocked_ids() else "standard"
	var meta: Dictionary = context.get("meta",{})
	var last: String = str(meta.get("last_difficulty",""))
	if last != "" and last in unlocked_ids(): return last
	if not bool(meta.get("tutorial_done",false)) and "tutorial" in unlocked_ids(): return "tutorial"
	return "standard"

func rebuild() -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	build()
func selected_resources() -> Array:
	var result: Array=[]
	for id in RESOURCES:
		for i in range(int(resource_counts.get(id,0))): result.append(id)
	return result
func change_resource(id: String, delta: int) -> void:
	var count: int=resource_counts.get(id,0)
	if delta>0 and (count>=2 or selected_resources().size()>=resource_limit()): return
	if chosen_difficulty == "tutorial" and delta > 0 and count >= Tutorial.STARTING.count(id): return
	resource_counts[id]=clampi(count+delta,0,2)
	rebuild()
func build() -> void:
	if not initialized:
		chosen_difficulty = default_difficulty()
		initialized = true
	var center:=CenterContainer.new(); center.size_flags_vertical=Control.SIZE_EXPAND_FILL; add_child(center)
	if picking: resource_picker(center); return
	var box:=W.panel(center,Vector2(minf(780,get_viewport_rect().size.x-48),0))
	W.text(box,"新局准备",34,W.GOLD)
	W.text(box,"新手教程 · 从选牌开始学习航行" if chosen_difficulty=="tutorial" else ("剧情模式 · 第一章11节点，每节点均有剧情" if context.setup_mode=="story" else "挑战模式 · 选择难度、出身与航程种子"),18,W.MUTED)
	W.text(box,"难度",18)
	var difficulty_choice:=OptionButton.new(); difficulty_choice.name="DifficultyChoice"; box.add_child(difficulty_choice)
	difficulty_choice.add_item("请选择难度")
	var unlocked: Array = unlocked_ids()
	for i in range(Difficulty.IDS.size()):
		var id: String = Difficulty.IDS[i]
		var locked: bool = id not in unlocked
		difficulty_choice.add_item(context.difficulties[i].name + (" · 未解锁（%s）" % Difficulty.unlock_requirement(id) if locked else ""))
		if locked: difficulty_choice.set_item_disabled(i+1,true)
		if context.setup_mode == "story" and id == "tutorial": difficulty_choice.set_item_disabled(i+1, true)
	difficulty_choice.select(Difficulty.IDS.find(chosen_difficulty)+1)
	var tutorial: bool = chosen_difficulty == "tutorial"
	var description:=W.text(box,"请选择本次航程的难度。",17,W.MUTED); description.name="DifficultyDescription"; description.custom_minimum_size.y=96
	var index := Difficulty.IDS.find(chosen_difficulty)
	if index>=0: description.text=context.difficulties[index].description
	else: description.text="请选择本次航程的难度。"
	var unlock_line := "初始解锁新手教程与简单；困难需通关简单，噩梦需通关困难。"
	var cleared: Dictionary = context.get("meta",{}).get("cleared",{})
	if bool(cleared.get("standard",false)): unlock_line = "已通关简单；噩梦仍需通关困难。"
	if bool(cleared.get("hard",false)): unlock_line = "已通关困难；全部难度均已解锁。"
	W.text(box,unlock_line,15,W.MUTED)
	var ids: Array = context.origins.keys()
	var choices: OptionButton = null
	var seed_input: LineEdit = null
	if tutorial:
		W.text(box,"先学习选择初始卡牌，再出发。资源可以用于制造、战斗与修补筏格。",17,W.MUTED)
		W.text(box,"之后依次学习导航、打捞、制造、安装、事件、战斗、筏格、弃牌与商店。",16,W.MUTED)
	else:
		W.text(box,"出身",18)
		choices=OptionButton.new()
		for id in ids: choices.add_item(context.origins[id].name+" · "+context.origins[id].description)
		choices.select(maxi(0,ids.find(chosen_origin))); box.add_child(choices)
		W.text(box,"航程种子",18)
		seed_input=LineEdit.new(); seed_input.text=chosen_seed; seed_input.placeholder_text="0～4294967295"; box.add_child(seed_input)
	var error_label:=W.text(box,"",16,Color("df968b")); error_label.hide()
	var start:=W.button(box,"选择初始卡牌" if tutorial else "选择起手资源",func():
		if chosen_difficulty=="": return
		if chosen_difficulty == "tutorial":
			picking=true; rebuild(); return
		if not seed_input.text.is_valid_int() or int(seed_input.text)<0 or int(seed_input.text)>4294967295:
			error_label.text="请输入0～4294967295整数种子"; error_label.show(); return
		chosen_origin=ids[choices.selected]; chosen_seed=seed_input.text; picking=true; rebuild())
	start.name="NewGameNext"; start.disabled=chosen_difficulty==""
	difficulty_choice.item_selected.connect(func(selected: int):
		if choices != null: chosen_origin=ids[choices.selected]
		if seed_input != null: chosen_seed=seed_input.text
		chosen_difficulty=Difficulty.IDS[selected-1] if selected>0 else ""
		resource_counts.clear()
		rebuild())
	W.primary(start)
	W.text(box,"下一步选择初始卡牌，再开始航行。",16,W.MUTED)
	W.corner_close(box.get_parent(),func(): request("setup",""))
func resource_picker(center: Node) -> void:
	var tutorial := chosen_difficulty == "tutorial"
	var box:=W.panel(center,Vector2(minf(1060,get_viewport_rect().size.x-48),0))
	var heading:=W.text(box,"新手教程 · 1/%d · 选择初始卡牌" % Tutorial.TOTAL_STEPS if tutorial else "选择起手资源",28,W.GOLD)
	heading.name="StartingCardHeading"
	if tutorial:
		W.text(box,str(Tutorial.TEXTS.starting_cards[1]),17,W.INK)
		W.text(box,"每类最多2张，本次选择8张。塑料和木头用于制作滤水器，其他材料留作后续操作。",16,W.MUTED)
	else:
		W.text(box,"%s · %s · 种子 %s" % [Difficulty.profile(catalog,chosen_difficulty).name,context.origins[chosen_origin].name,chosen_seed],18,W.MUTED)
		W.text(box,"每类最多2张，总计最多%d张；也可少选。" % resource_limit(),18,W.MUTED)
	var grid:=W.grid(box,5)
	for id in RESOURCES:
		var tile:=W.panel(grid,Vector2(0,0))
		tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		W.art(tile,assets,"card."+id,110,false)
		W.text(tile,catalog.entry("cards",id).name,18,W.GOLD)
		var row:=HBoxContainer.new(); tile.add_child(row)
		var count: int=resource_counts.get(id,0)
		var target: int=Tutorial.STARTING.count(id) if tutorial else 2
		var minus:=W.button(row,"−",func(): change_resource(id,-1),count==0); minus.name="ResourceMinus_"+id
		W.counter(row,"%d/%d" % [count,target])
		var plus:=W.button(row,"+",func(): change_resource(id,1),count>=target or selected_resources().size()>=resource_limit()); plus.name="ResourcePlus_"+id
	var selected: Array=selected_resources()
	W.text(box,"已选 %d/%d" % [selected.size(),resource_limit()],22,W.GOLD)
	if selected.is_empty() and not tutorial: W.text(box,"随心所欲：额外获得2张，随机发放全部%d张资源牌。" % (resource_limit()+2),18,W.MUTED)
	var start:=W.button(box,"开始航行" if tutorial else ("随心所欲" if selected.is_empty() else "正式开始"),func():
		var args: Dictionary=Tutorial.start_args() if tutorial else {"difficulty":chosen_difficulty,"mode":context.setup_mode,"origin":chosen_origin,"seed":int(chosen_seed)}
		args.starting_resources=selected_resources()
		send("new",args))
	start.name="StartVoyage"
	start.disabled=tutorial and selected.size()!=resource_limit()
	W.primary(start)
	W.corner_close(box.get_parent(),func(): picking=false; rebuild())
