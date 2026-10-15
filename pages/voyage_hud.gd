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
	var enlarged: bool=context.get("ui_scale",1.0)>1.0
	for region in [0,1]:
		var topbar:=TextureRect.new(); topbar.name="VoyageInfoPlate" if region==0 else "VoyageStatsPlate"; topbar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var topbar_atlas:=AtlasTexture.new(); topbar_atlas.atlas=load("res://assets/textures/voyage-topbar-v1.png")
		topbar_atlas.region=Rect2(0,185,2172,360); topbar.texture=topbar_atlas
		topbar.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; topbar.stretch_mode=TextureRect.STRETCH_SCALE
		topbar.modulate=Color(1,1,1,0.72); stage.add_child(topbar)
		rect(topbar,Vector4.ZERO,Vector4(12,8,620,184)) if region==0 else rect(topbar,Vector4(0,0,1,0),Vector4(540 if enlarged else 632,8,-12,184))
	var title := VBoxContainer.new(); title.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(title); rect(title,Vector4.ZERO,Vector4(58,22,576,172))
	W.text(title,"深 潮",32,W.INK)
	W.text(title,"D E E P   S U R G E  ·  第一层"+("  /  测试剧情" if context.mode == "story" else "  /  挑战"),14,W.MUTED)
	var menu := HBoxContainer.new(); menu.mouse_filter=Control.MOUSE_FILTER_IGNORE; title.add_child(menu)
	action(menu,"木筏详情","panel",{"id":"raft"})
	W.button(menu,"玩法",func(): request("local_panel","help"))
	W.button(menu,"设置",func(): request("local_panel","settings"))
	action(menu,"返回首页","home")
	for child in menu.get_children(): child.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	W.text(title,"第 %d / %d 次航行    %s" % [context.voyage,context.length,PHASES[context.phase]],17,W.GOLD)
	var status = preload("res://addons/deep_surge_status/status_hud.gd").new(); status.name = "SurgeStatusHUD"; status.two_columns=false; status.minimum_row_width=400; stage.add_child(status)
	rect(status,Vector4(0,0,1,0),Vector4(560,56,-32,138)) if enlarged else rect(status,Vector4(0,0,1,0),Vector4(660,56,-32,138))
	for key in {"hp":"health","hunger":"satiety","hydration":"water","sanity":"sanity"}:
		status.set_stat({"hp":"health","hunger":"satiety","hydration":"water","sanity":"sanity"}[key],context.player[key],context.player[key+"_max"])
	if context.phase not in ["chapterComplete","finished"]:
		var ap = preload("res://addons/deep_surge_status/action_points_hud.gd").new(); ap.name = "SurgeActionPointHUD"; stage.add_child(ap)
		rect(ap,Vector4(0,1,0,1),Vector4(32,-254,332,-178))
		ap.scale=Vector2.ONE*0.75
		var night: Dictionary = context.get("night",{})
		if not night.is_empty() and night.voyage == context.voyage and context.phase in ["nightHub","story"]:
			ap.label_text = "今晚机会"; ap.set_ap(night.budget,maxi(1,night.budget)); ap.show_numbers = true
		else: ap.set_ap(context.battle.ap if context.phase == "battle" else context.ap,context.player.battle_ap if context.phase == "battle" else context.player.base_ap)
	var frame = preload("res://presentation/hud_frame.gd").new()
	frame.name = "VoyageOperationFrame"; stage.add_child(frame)
	frame.add_theme_stylebox_override("panel",compact_style())
	rect(frame,Vector4(1,0,1,1),Vector4(-356,182,-24,-280)) if enlarged else rect(frame,Vector4(1,0,1,1),Vector4(-356,200,-24,-302))
	var operation := VBoxContainer.new(); frame.add_child(operation)
	operation.add_theme_constant_override("separation",9)
	frame.visible=context.phase!="story" or context.ui_state.get("card","")!=""
	operation_content(operation)
	style_operation_buttons(operation)
	var tray := Control.new(); tray.name="VoyageHandTray"; tray.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(tray)
	rect(tray,Vector4(0,1,1,1),Vector4(292,-238,-64,-18))
	hand(tray)
	var craft := W.button(stage,"合成",func(): send("panel",{"id":"craft"}),not context.can_base or context.get("tutorial_operation","") not in ["","craft"])
	craft.name="CraftEntry"; craft.add_theme_font_size_override("font_size",25)
	rect(craft,Vector4(0,1,0,1),Vector4(76,-182,204,-54))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var circle:=StyleBoxFlat.new(); circle.bg_color=Color("18303c") if state=="normal" else Color("254957")
		if state=="disabled": circle.bg_color=Color("14242c")
		circle.border_color=W.GOLD if state=="focus" else Color("41616c")
		circle.set_border_width_all(2); circle.set_corner_radius_all(64)
		craft.add_theme_stylebox_override(state,circle)
	var counter := PanelContainer.new(); counter.name="HandCapacityBadge"; tray.add_child(counter)
	rect(counter,Vector4(0.5,0,0.5,0),Vector4(-52,-44,52,-4))
	var count_style:=compact_style(); count_style.set_corner_radius_all(12)
	count_style.content_margin_left=12; count_style.content_margin_right=12; count_style.content_margin_top=4; count_style.content_margin_bottom=4
	counter.add_theme_stylebox_override("panel",count_style)
	var count_label:=W.text(counter,"%d/%d" % [context.capacity,context.player.limit],20,W.INK)
	count_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	count_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; count_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER

static func compact_style() -> StyleBoxFlat:
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
			if card.id == "coin": W.text(box,"持有 %d 贝币；在商店购买时支付。" % card.quantity,18,W.GOLD)
			if context.can_base and card.definition.kind == "survival": action(box,"使用 · "+card.definition.name,"play",{"uid":card.uid})
			if card.definition.kind in ["equipment","action"]: action(box,"在木筏上使用","panel",{"id":"raft"},not context.can_base)
			W.corner_close(box.get_parent(),func(): request("card",""))
			return
	if context.phase=="story": return
	W.text(box,PHASES[context.phase],25,W.GOLD)
	if context.mode=="story" and (not context.known_quests.is_empty() or not context.known_clues.is_empty()): action(box,"任务与线索","panel",{"id":"journal"})
	match context.phase:
		"navigation":
			W.text(box,"可先使用手牌与合成，再选择目的地；出发时支付航耗。",16,W.MUTED)
			action(box,"海面打捞 · AP1","salvage",{},not context.can_base or context.ap < 1 or context.get("tutorial_operation","") != "","消耗 1 AP 打捞漂流物资")
			for node in context.candidates:
				var button := W.button(box,"出发 · "+node.name,func(): send("voyage",{"id":node.visit_id}))
				button.tooltip_text = node.description
		"preparation":
			W.text(box,"已抵达："+context.node.name,18)
			W.text(box,"可使用物资、制造与管理设备。",16,W.MUTED)
			var reason: String = context.get("tutorial_reason","")
			if reason != "": W.text(box,reason,17,W.GOLD)
			action(box,"海面打捞 · AP1","salvage",{},not context.can_base or context.ap < 1 or context.get("tutorial_operation","") != "","消耗 1 AP 打捞漂流物资")
			action(box,"进入节点","enter",{},reason != "",reason)
			W.primary(box.get_child(box.get_child_count()-1))
		"story","interaction","battle":
			W.text(box,context.node.name,20)
			W.text(box,"处理完当前事件后再结束航行。",16,W.MUTED)
			action(box,"处理当前事件","event")
			W.primary(box.get_child(box.get_child_count()-1))
		"aftermath":
			W.text(box,"节点已完成，可继续使用剩余AP。",17,W.MUTED)
			action(box,"海面打捞 · AP1","salvage",{},not context.can_base or context.ap < 1 or context.get("tutorial_operation","") != "","消耗 1 AP 打捞漂流物资")
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
			W.text(box,"章节成果可从结算页回看。",16,W.MUTED)
		"finished":
			W.text(box,{"survived":"灯火未熄","withdrawn":"离开潮眼","dead":"沉入深潮","mad":"迷失潮声","abandon":"返回岸边"}.get(context.result,context.result),24,W.GOLD)
			W.text(box,"完成 %d 个节点" % context.completed,18)
			W.text(box,"本局涌潮点 %d" % context.completed,16,W.MUTED)

func hand(parent: Node) -> void:
	var fan = load("res://presentation/hand_fan.gd").new(); parent.add_child(fan)
	context.hand_reserved_left = 0.0
	fan.set_meta("presentation_role","voyage"); fan.create(assets,context.hand,context)
	fan.custom_minimum_size.y=218
	fan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fan.reordered.connect(func(): request("hand_reordered"))
	fan.equipment_double_clicked.connect(func(card): send("install",{"uid":card.uid,"auto":true}))
	fan.activated.connect(func(card):
		if context.phase == "discard": send("discard",{"uid":card.uid})
		elif context.can_base and card.definition.kind == "survival": send("play",{"uid":card.uid})
		else: request("card",card.uid))
