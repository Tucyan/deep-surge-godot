extends "res://pages/flow_base.gd"
func build() -> void:
	heading("第%d晚" % context.voyage,"休息或调查 · 每晚一次主要行动")
	var row := HBoxContainer.new(); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(row)
	var info := W.panel(row); var choices := W.panel(row)
	var night: Dictionary = context.night
	var route: String = context.campaign_summary.route
	match night.stage:
		"services":
			W.text(info,"分队服务" if route == "scholar" else "独航补给",26,W.GOLD)
			W.text(info,"每晚最多交换一次：基础材料1 → 食物、淡水、余温各1。",18)
			var materials := OptionButton.new(); var ids: Array = []
			for id in ["wood","iron","plastic","rope","cloth"]:
				if context.hand.filter(func(c): return c.id == id).is_empty(): continue
				ids.append(id); materials.add_item(catalog.entry("cards",id).name)
			info.add_child(materials)
			W.button(info,"交换补给",func(): send("night_exchange",{"material":ids[materials.selected]}),night.exchanged or ids.is_empty())
			if route == "scholar":
				var q: Dictionary = catalog.entry("story_config","first_layer").ordinary_quest
				W.text(choices,q.name,25,W.GOLD); W.text(choices,q.description,18)
				var known: Array = context.known_quests.filter(func(k): return k.name == q.name)
				if known.is_empty(): action(choices,"接受委托","accept_quest")
				elif known[0].status == "active": action(choices,"提交绳索2","submit_quest",{},amount("rope") < 2,"交付后仅奖励一次")
				else: W.text(choices,"委托已完成",18,W.MUTED)
			if context.voyage == 5:
				W.text(choices,"今晚没有主要行动。",18,W.MUTED)
				action(choices,"完成今晚，整理手牌","finish_night")
			else: action(choices,"安排今晚行动","night_actions")
		"awaitAction":
			W.text(info,"选择一次主要行动",26,W.GOLD)
			W.text(info,"休息恢复生存状态；调查确认不同方向的线索。已完成的调查不能重复。",20)
			W.text(info,"今晚机会  %d / 1" % night.budget,22,W.GOLD)
			for entry in context.night_actions:
				action(choices,entry.name,"night_action",{"id":entry.id},entry.reason != "",entry.reason if entry.reason != "" else entry.description)
				W.text(choices,entry.description,16,W.MUTED)
		"result":
			W.text(info,"行动结果",26,W.GOLD); W.text(info,night.result,21)
			action(choices,"记下今晚结果","night_ack")
		"complete":
			W.text(info,"今晚已完成",26,W.GOLD)
			W.text(info,"接下来处理筏格老化，超限时整理手牌；下一轮开始时设备生产。",20)
			action(choices,"完成今晚，整理手牌","finish_night")
