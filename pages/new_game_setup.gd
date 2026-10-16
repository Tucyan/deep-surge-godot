extends "res://pages/flow_base.gd"
const RESOURCES = preload("res://core/inventory.gd").RESOURCES
const Difficulty = preload("res://core/difficulty_rules.gd")
var chosen_difficulty := ""
var picking := false
func resource_limit() -> int:
	return int(Difficulty.profile(catalog,chosen_difficulty).get("starting_cards",5))
var chosen_origin := "strong"
var chosen_seed := "22"
var resource_counts := {}
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
	resource_counts[id]=clampi(count+delta,0,2)
	rebuild()
func build() -> void:
	var center:=CenterContainer.new(); center.size_flags_vertical=Control.SIZE_EXPAND_FILL; add_child(center)
	if picking: resource_picker(center); return
	var box:=W.panel(center,Vector2(780,560))
	W.text(box,"新局准备",34,W.GOLD)
	W.text(box,"剧情模式 · 第一层15站（测试剧本）" if context.setup_mode=="story" else "挑战模式 · 选择难度、出身与航程种子",18,W.MUTED)
	W.text(box,"难度",18)
	var difficulty_choice:=OptionButton.new(); difficulty_choice.name="DifficultyChoice"; box.add_child(difficulty_choice)
	difficulty_choice.add_item("请选择难度")
	for d in context.difficulties: difficulty_choice.add_item(d.name)
	difficulty_choice.select(Difficulty.IDS.find(chosen_difficulty)+1)
	var description:=W.text(box,"请选择本次航程的难度。",17,W.MUTED); description.name="DifficultyDescription"; description.custom_minimum_size.y=100
	if chosen_difficulty!="": description.text=context.difficulties[Difficulty.IDS.find(chosen_difficulty)].description
	W.text(box,"出身",18)
	var choices:=OptionButton.new(); var ids: Array=context.origins.keys()
	for id in ids: choices.add_item(context.origins[id].name+" · "+context.origins[id].description)
	choices.select(maxi(0,ids.find(chosen_origin))); box.add_child(choices)
	W.text(box,"航程种子",18)
	var seed_input:=LineEdit.new(); seed_input.text=chosen_seed; seed_input.placeholder_text="0～4294967295"; box.add_child(seed_input)
	var error_label:=W.text(box,"",16,Color("df968b")); error_label.hide()
	var start:=W.button(box,"选择起手资源",func():
		if chosen_difficulty=="": return
		if not seed_input.text.is_valid_int() or int(seed_input.text)<0 or int(seed_input.text)>4294967295:
			error_label.text="请输入0～4294967295整数种子"; error_label.show(); return
		chosen_origin=ids[choices.selected]; chosen_seed=seed_input.text; picking=true; rebuild())
	start.name="NewGameNext"; start.disabled=chosen_difficulty==""
	difficulty_choice.item_selected.connect(func(index: int):
		chosen_difficulty=Difficulty.IDS[index-1] if index>0 else ""
		resource_counts.clear()
		description.text=context.difficulties[index-1].description if index>0 else "请选择本次航程的难度。"
		start.disabled=index==0)
	W.primary(start)
	W.text(box,"下一步选择起手资源；首次无涌泉。",16,W.MUTED)
	W.corner_close(box.get_parent(),func(): request("setup",""))
func resource_picker(center: Node) -> void:
	var box:=W.panel(center,Vector2(1180,500))
	W.text(box,"选择起手资源",34,W.GOLD)
	W.text(box,"%s · %s · 种子 %s" % [Difficulty.profile(catalog,chosen_difficulty).name,context.origins[chosen_origin].name,chosen_seed],18,W.MUTED)
	W.text(box,"每类最多2张，总计最多%d张；也可少选。" % resource_limit(),18,W.MUTED)
	var grid:=W.grid(box,5)
	for id in RESOURCES:
		var tile:=W.panel(grid,Vector2(200,0))
		W.art(tile,assets,"card."+id,160,false)
		W.text(tile,catalog.entry("cards",id).name,23,W.GOLD)
		var row:=HBoxContainer.new(); tile.add_child(row)
		var count: int=resource_counts.get(id,0)
		W.button(row,"−",func(): change_resource(id,-1),count==0)
		W.counter(row,"%d/2" % count)
		W.button(row,"+",func(): change_resource(id,1),count>=2 or selected_resources().size()>=resource_limit())
	var selected: Array=selected_resources()
	W.text(box,"已选 %d/%d" % [selected.size(),resource_limit()],22,W.GOLD)
	if selected.is_empty(): W.text(box,"随心所欲：额外获得2张，随机发放全部%d张资源牌。" % (resource_limit()+2),18,W.MUTED)
	var start:=W.button(box,"随心所欲" if selected.is_empty() else "正式开始",func(): send("new",{"difficulty":chosen_difficulty,"mode":context.setup_mode,"origin":chosen_origin,"seed":int(chosen_seed),"starting_resources":selected_resources()}))
	start.name="StartVoyage"
	W.primary(start)
	W.corner_close(box.get_parent(),func(): picking=false; rebuild())
