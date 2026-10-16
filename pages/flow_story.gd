extends "res://pages/flow_base.gd"
func choice(panel: Node, title: String, command: String, args: Dictionary = {}, reason: String = "", detail: String = "") -> void:
	var button := W.button(panel,title+("\n"+detail if detail!="" else ""),func(): send(command,args.duplicate(true)),reason!="",reason if reason!="" else detail)
	button.custom_minimum_size.y=60 if detail!="" else 42
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",15)
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func choices_panel(row: Node, title: String, description: String = ""):
	var panel := VBoxContainer.new(); panel.name="NodeEventChoices"
	panel.add_theme_constant_override("separation",6)
	panel.custom_minimum_size.x=0; panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(panel); W.text(panel,title,20,W.GOLD)
	if description!="": W.text(panel,description,17)
	return panel
func costs(option: Dictionary) -> String:
	var result := PackedStringArray()
	if option.get("cost",0)>0: result.append("%d AP" % option.cost)
	for id in option.get("cardCosts",{}): result.append(catalog.entry("cards",id).name+"×%d" % option.cardCosts[id])
	for stat in option.get("statCosts",{}): result.append({"hp":"生命","sanity":"SAN"}.get(stat,stat)+"%d" % option.statCosts[stat])
	return " · ".join(result)

func event_option(panel: Node, option: Dictionary) -> void:
	var alternatives: Array=option.get("actions",[])
	if alternatives.is_empty(): return
	var index := 0
	for i in range(alternatives.size()):
		if alternatives[i].reason=="": index=i; break
	var selection: OptionButton
	if alternatives.size()>1:
		selection=OptionButton.new(); selection.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		panel.add_child(selection)
		for item in alternatives: selection.add_item(item.label)
		selection.select(index)
	if alternatives[index].args.has("cell"): request.call_deferred("event_target",str(alternatives[index].args.cell))
	var cost: String=costs(option)
	var button := W.button(panel,option.name+(" · "+cost if cost!="" else ""),func():
		var picked: Dictionary=alternatives[selection.selected if selection!=null else index]
		if picked.reason!="": return
		var args: Dictionary=picked.args.duplicate(true)
		if cost!="" or args.has("cell") or option.has("battle"):
			var dialog := ConfirmationDialog.new(); add_child(dialog)
			dialog.title=option.name; dialog.dialog_text=option.description+("\n目标："+picked.label if picked.label!="" else "")
			dialog.ok_button_text="确认选择"; dialog.cancel_button_text="取消"
			dialog.confirmed.connect(func(): send("option",args); dialog.queue_free())
			dialog.canceled.connect(func(): dialog.queue_free())
			dialog.popup_centered(Vector2i(500,240))
		else: send("option",args)
	,alternatives[index].reason!="",option.description+"\n"+alternatives[index].reason)
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",15)
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y=50
	if selection!=null:
		selection.item_selected.connect(func(selected):
			button.disabled=alternatives[selected].reason!=""
			if alternatives[selected].args.has("cell"): request("event_target",str(alternatives[selected].args.cell))
			button.tooltip_text=option.description+"\n"+alternatives[selected].reason)
func build() -> void:
	add_theme_constant_override("separation",6)
	if not context.get("scene",{}).is_empty(): campaign_story(); return
	W.text(self,context.node.name,24,W.GOLD)
	var panel = choices_panel(self,{"intro":"海上遭遇","choice":"作出选择","result":"事件结果"}.get(context.story_step,"当前事件"))
	if context.story_step!="choice":
		W.text(panel,context.result_text if context.story_step=="result" else context.node.description,20)
	match context.story_step:
		"intro":
			choice(panel,"继续","advance"); choice(panel,"跳过文字","skip")
		"choice":
			var previous: String=context.get("encounter",{}).get("last_result","")
			if previous!="": W.text(panel,previous,15,W.GOLD)
			if context.node.has("monster"):
				var enemy: Dictionary = preload("res://core/difficulty_rules.gd").enemy(catalog,context,context.node.monster)
				W.text(panel,"%s · 生命%d\n%s" % [enemy.name,enemy.hp,enemy.intent],17)
				choice(panel,"迎战","fight"); choice(panel,"离开遭遇","leave_encounter")
			if context.node.kind == "shop": choice(panel,"进入商店","shop_enter")
			for option in context.get("event_options",[]): event_option(panel,option)
		"result": choice(panel,"结束节点","advance")
func campaign_story() -> void:
	var scene: Dictionary = context.scene
	W.text(self,scene.name,28,W.GOLD)
	var panel = choices_panel(self,{"intro":"继续剧情","choice":"作出选择","result":"已记录结果"}.get(context.story_step,"当前事件"))
	if context.story_step!="choice":
		W.text(panel,context.result_text if context.story_step=="result" else scene.text,20)
	match context.story_step:
		"intro":
			W.text(panel,"%d / %d" % [scene.index+1,scene.line_count],16,W.MUTED)
			choice(panel,"继续","advance"); choice(panel,"跳过文字","skip")
		"choice":
			if scene.combat: choice(panel,"迎战","fight",{},"","实际赢下教学战斗后继续。")
			for option in scene.choices:
				choice(panel,option.name,"option",{"id":option.id},option.disabled_reason,option.description)
		"result": choice(panel,"继续剧情" if scene.id == "ST.L1.F15" else "完成这段剧情","advance")
