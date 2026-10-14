extends "res://pages/flow_base.gd"
const PHASES := {"navigation":"航行导航","preparation":"航行准备","story":"当前事件","interaction":"商店交易","battle":"战斗进行中","aftermath":"航行收尾","discard":"轮末整理","finished":"航程结束","nightHub":"夜间安排","chapterComplete":"第一层结束"}
const ItemCard = preload("res://presentation/item_card.gd")

func rect(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.anchor_left = anchors.x; control.anchor_top = anchors.y
	control.anchor_right = anchors.z; control.anchor_bottom = anchors.w
	control.offset_left = offsets.x; control.offset_top = offsets.y
	control.offset_right = offsets.z; control.offset_bottom = offsets.w

func build() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var stage := Control.new(); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(stage)
	var title := VBoxContainer.new(); title.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(title); rect(title,Vector4.ZERO,Vector4(28,20,820,168))
	W.text(title,"深 潮",46,W.INK)
	W.text(title,"D E E P   S U R G E  ·  第一层"+("  /  测试剧情" if context.mode == "story" else "  /  挑战"),14,W.MUTED)
	var menu := HBoxContainer.new(); menu.mouse_filter=Control.MOUSE_FILTER_IGNORE; title.add_child(menu)
	if context.can_base and context.get("tutorial_operation","") in ["","craft"]: action(menu,"合成","panel",{"id":"craft"})
	action(menu,"木筏详情","panel",{"id":"raft"})
	action(menu,"航行日志","panel",{"id":"logs"})
	if context.mode == "story" and (not context.known_quests.is_empty() or not context.known_clues.is_empty()): action(menu,"任务与线索","panel",{"id":"journal"})
	W.button(menu,"玩法",func(): request("local_panel","help"))
	W.button(menu,"设置",func(): request("local_panel","settings"))
	action(menu,"返回首页","home")
	for child in menu.get_children(): child.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	W.text(title,"第 %d / %d 次航行    %s" % [context.voyage,context.length,PHASES[context.phase]],17,W.GOLD)
	var status = preload("res://addons/deep_surge_status/status_hud.gd").new(); status.name = "SurgeStatusHUD"; stage.add_child(status)
	rect(status,Vector4(1,0,1,0),Vector4(-1248,14,-24,94))
	for key in {"hp":"health","hunger":"satiety","hydration":"water","sanity":"sanity"}:
		status.set_stat({"hp":"health","hunger":"satiety","hydration":"water","sanity":"sanity"}[key],context.player[key],context.player[key+"_max"])
	if context.phase not in ["chapterComplete","finished"]:
		var ap = preload("res://addons/deep_surge_status/action_points_hud.gd").new(); ap.name = "SurgeActionPointHUD"; stage.add_child(ap)
		rect(ap,Vector4(0,1,0,1),Vector4(28,-386,328,-310))
		var night: Dictionary = context.get("night",{})
		if not night.is_empty() and night.voyage == context.voyage and context.phase in ["nightHub","story"]:
			ap.label_text = "今晚机会"; ap.set_ap(night.budget,maxi(1,night.budget)); ap.show_numbers = true
		else: ap.set_ap(context.battle.ap if context.phase == "battle" else context.ap,context.player.battle_ap if context.phase == "battle" else context.player.base_ap)
	var frame = preload("res://presentation/hud_frame.gd").new()
	frame.name = "VoyageOperationFrame"; stage.add_child(frame)
	frame.add_theme_stylebox_override("panel",compact_style())
	rect(frame,Vector4(1,0,1,0),Vector4(-356,108,-24,108))
	var operation := VBoxContainer.new(); frame.add_child(operation)
	operation.add_theme_constant_override("separation",9)
	frame.visible=context.phase!="story" or context.ui_state.get("card","")!=""
	operation_content(operation)
	style_operation_buttons(operation)
	var tray := VBoxContainer.new(); tray.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(tray); tray.add_theme_constant_override("separation",7)
	rect(tray,Vector4(0,1,1,1),Vector4(28,-302,-28,-18))
	hand(tray)

func compact_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = Color(0.035,0.065,0.09,0.94); style.border_color = Color("887e64"); style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 20; style.content_margin_right = 20; style.content_margin_top = 20; style.content_margin_bottom = 18
	return style

func style_operation_buttons(box: Node) -> void:
	for child in box.get_children():
		if not child is Button: continue
		child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		child.custom_minimum_size.y = 38
		for state in ["normal","hover","pressed","disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("182934") if state == "normal" else Color("263b47")
			style.border_color = Color("817961") if state == "normal" else Color("ddcaa2")
			if state == "disabled": style.bg_color = Color("111c23"); style.border_color = Color("424c4e")
			style.set_border_width_all(1); style.set_corner_radius_all(3)
			style.content_margin_left = 12; style.content_margin_right = 12
			style.content_margin_top = 7; style.content_margin_bottom = 7
			child.add_theme_stylebox_override(state,style)
		child.add_theme_color_override("font_color",Color("eee3cd"))
		child.add_theme_color_override("font_hover_color",Color("fff8e9"))
		child.add_theme_color_override("font_pressed_color",Color("fff8e9"))

func operation_content(box: Node) -> void:
	var selected: String = context.ui_state.get("card","")
	if selected != "":
		for card in context.hand:
			if card.uid != selected: continue
			W.text(box,card.definition.name,25,W.GOLD)
			W.text(box,card.definition.description,18)
			if context.can_base and card.definition.kind == "survival": action(box,"使用 · "+card.definition.name,"play",{"uid":card.uid})
			if card.definition.kind in ["equipment","action"]: action(box,"在木筏上使用","panel",{"id":"raft"},not context.can_base)
			W.button(box,"返回当前阶段",func(): request("card",""))
			return
	if context.phase=="story": return
	W.text(box,PHASES[context.phase],25,W.GOLD)
	match context.phase:
		"navigation":
			W.text(box,"选择本轮目的地，出发时支付航耗。",16,W.MUTED)
			for node in context.candidates:
				var button := W.button(box,"出发 · "+node.name,func(): send("voyage",{"id":node.visit_id}))
				button.tooltip_text = node.description
		"preparation":
			W.text(box,"已抵达："+context.node.name,18)
			W.text(box,"可使用物资、制造与管理设备。",16,W.MUTED)
			var reason: String = context.get("tutorial_reason","")
			if reason != "": W.text(box,reason,17,W.GOLD)
			action(box,"进入节点","enter",{},reason != "",reason)
			W.primary(box.get_child(box.get_child_count()-1))
		"story","interaction","battle":
			W.text(box,context.node.name,20)
			W.text(box,"处理完当前事件后再结束航行。",16,W.MUTED)
			action(box,"处理当前事件","event")
			W.primary(box.get_child(box.get_child_count()-1))
		"aftermath":
			W.text(box,"节点已完成，可继续使用剩余AP。",17,W.MUTED)
			action(box,"结束白天" if context.mode == "story" and context.voyage >= 5 and context.voyage < 15 else "结束航行","end_voyage")
			W.primary(box.get_child(box.get_child_count()-1))
		"discard": W.text(box,"手牌超限，选择要弃置的物资；达标后自动进入导航。",18)
		"nightHub":
			W.text(box,"今晚的服务、事件或主要行动尚待完成。",18)
			action(box,"处理夜间安排","event")
		"chapterComplete":
			var resolution: Dictionary = context.campaign_summary.resolution
			W.text(box,{"A":"成功封闭","B":"付出代价后处理","C":"紧急撤离","SOLO":"独航出口"}.get(resolution.outcome,"已完成"),23,W.GOLD)
			W.text(box,"本章成果已保存。第二层尚未开放。",18)
			W.text(box,"继续游戏可查看当前木筏、日志与任务。",16,W.MUTED)
			action(box,"返回首页","home")
		"finished":
			W.text(box,{"survived":"灯火未熄","withdrawn":"离开潮眼","dead":"沉入深潮","mad":"迷失潮声","abandon":"返回岸边"}.get(context.result,context.result),24,W.GOLD)
			W.text(box,"完成 %d 个节点" % context.completed,18)
			W.text(box,"本局涌潮点 %d" % context.completed,16,W.MUTED)

func hand(parent: Node) -> void:
	var header := HBoxContainer.new(); parent.add_child(header)
	W.text(header,"手牌 %d/%d   ·   贝币 %d" % [context.capacity,context.player.limit,context.coins],16,W.MUTED)
	var fan = load("res://presentation/hand_fan.gd").new(); parent.add_child(fan)
	fan.set_meta("presentation_role","voyage"); fan.create(assets,context.hand,context)
	fan.activated.connect(func(card):
		if context.phase == "discard": send("discard",{"uid":card.uid})
		elif context.can_base and card.definition.kind == "survival": send("play",{"uid":card.uid})
		else: request("card",card.uid))
	if context.phase == "discard" and context.coins > 0: action(header,"弃置全部贝币（%d）" % context.coins,"discard",{"uid":"coins"})
