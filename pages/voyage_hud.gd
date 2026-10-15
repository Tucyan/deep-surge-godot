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
	# Calculate current shields & layers
	var shields: Array = []
	if context.phase == "battle" and context.has("battle") and context.battle is Dictionary:
		shields = context.battle.get("shields", [])
	elif context.has("shields") and context.shields is Array:
		shields = context.shields
	var total_shield := 0
	for s in shields:
		total_shield += int(s.get("amount", 0))

	var topbar := Panel.new(); topbar.name = "VoyageHandTopBar"; topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE; stage.add_child(topbar)
	rect(topbar, Vector4(0,1,1,1), Vector4(64, -282, -292, -226))
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.025, 0.055, 0.08, 0.88)
	bar_style.border_color = Color(0.65, 0.57, 0.36, 0.65)
	bar_style.set_border_width_all(1)
	bar_style.border_width_bottom = 0
	bar_style.corner_radius_top_left = 4
	bar_style.corner_radius_top_right = 4
	topbar.add_theme_stylebox_override("panel", bar_style)
	if context.phase not in ["chapterComplete","finished"]:
		var ap = preload("res://addons/deep_surge_status/action_points_hud.gd").new(); ap.name = "SurgeActionPointHUD"; topbar.add_child(ap)
		rect(ap, Vector4(0,1,0,1), Vector4(10, -62.8, 290, 12.2))
		ap.pivot_offset = Vector2.ZERO
		ap.scale = Vector2.ONE * 0.88
		ap.z_index = 2
		var night: Dictionary = context.get("night",{})
		if not night.is_empty() and night.voyage == context.voyage and context.phase in ["nightHub","story"]:
			ap.label_text = "今晚机会"; ap.set_ap(night.budget,maxi(1,night.budget)); ap.show_numbers = true
		else: ap.set_ap(context.battle.ap if context.phase == "battle" else context.ap,context.player.battle_ap if context.phase == "battle" else context.player.base_ap)
	var counter := PanelContainer.new(); counter.name = "HandCapacityBadge"; topbar.add_child(counter)
	counter.z_index = 2
	rect(counter, Vector4(0.5,0.5,0.5,0.5), Vector4(-52, -15, 52, 15))
	var count_style := compact_style(); count_style.set_corner_radius_all(10)
	count_style.content_margin_left = 12; count_style.content_margin_right = 12
	count_style.content_margin_top = 2; count_style.content_margin_bottom = 2
	counter.add_theme_stylebox_override("panel", count_style)
	var count_label := W.text(counter, "%d/%d" % [context.capacity, context.player.limit], 18, W.INK)
	count_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Shield badge at the far right of the card topbar (multiple small shield icons)
	var shield_badge := PanelContainer.new()
	shield_badge.name = "BattleShieldSummary"
	shield_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield_badge.z_index = 2
	topbar.add_child(shield_badge)
	
	var sb_style := compact_style(); sb_style.set_corner_radius_all(10)
	sb_style.content_margin_left = 8; sb_style.content_margin_right = 8
	sb_style.content_margin_top = 2; sb_style.content_margin_bottom = 2
	if total_shield > 0:
		sb_style.bg_color = Color(0.06, 0.18, 0.32, 0.85)
		sb_style.border_color = Color(0.35, 0.75, 1.0, 0.8)
	shield_badge.add_theme_stylebox_override("panel", sb_style)

	var cur_turn: int = int(context.get("battle", {}).get("turn", 1))
	var sb_row := HBoxContainer.new()
	sb_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sb_row.add_theme_constant_override("separation", 4)
	shield_badge.add_child(sb_row)

	var ShieldIcon = preload("res://presentation/shield_icon.gd")
	if total_shield > 0:
		for s in shields:
			var amt := int(s.get("amount", 0))
			var is_dashed: bool = int(s.get("expires_turn", 0)) <= cur_turn
			for j in range(amt):
				var icon = ShieldIcon.new(is_dashed, false)
				sb_row.add_child(icon)
	else:
		var empty_icon = ShieldIcon.new(true, true)
		sb_row.add_child(empty_icon)

	# Accessible ShieldValue label for testing / scripts
	var s_val := Label.new()
	s_val.name = "ShieldValue"
	s_val.text = str(total_shield)
	s_val.visible = false
	sb_row.add_child(s_val)

	var badge_w := maxi(40, 16 + total_shield * 22)
	rect(shield_badge, Vector4(1, 0.5, 1, 0.5), Vector4(-badge_w - 14, -15, -14, 15))

	shield_badge.visible = context.phase == "battle" or total_shield > 0
	var frame = preload("res://presentation/hud_frame.gd").new()
	frame.name = "VoyageOperationFrame"; stage.add_child(frame)
	frame.add_theme_stylebox_override("panel",compact_style())
	rect(frame,Vector4(1,0,1,1),Vector4(-356,182,-24,-280)) if enlarged else rect(frame,Vector4(1,0,1,1),Vector4(-356,200,-24,-302))
	var operation := VBoxContainer.new(); frame.add_child(operation)
	operation.add_theme_constant_override("separation",9)
	frame.visible = context.phase != "story" and context.phase != "battle"
	operation_content(operation)
	style_operation_buttons(operation)
	var battle_view = null
	if context.phase == "battle":
		battle_view = preload("res://pages/battle_hud_view.gd").new()
		battle_view.name = "BattleHUDView"
		stage.add_child(battle_view)
		battle_view.setup(self, context, catalog, assets, session)
	var tray := Control.new(); tray.name="VoyageHandTray"; tray.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(tray)
	rect(tray,Vector4(0,1,1,1),Vector4(64,-238,-292,-18))
	hand(tray)
	var craft: Button
	if context.phase == "battle":
		craft = W.button(stage,"迎击",func():
			var bv = find_child("BattleHUDView", true, false)
			if is_instance_valid(bv): bv.confirm_action()
		, true)
		craft.name = "ConfirmBattleAction"
	else:
		craft = W.button(stage,"合成/转化",func(): send("panel",{"id":"craft"}),not context.can_base or context.get("tutorial_operation","") not in ["","craft"])
		craft.name = "CraftEntry"
	craft.add_theme_font_size_override("font_size",21)
	rect(craft,Vector4(1,1,1,1),Vector4(-204,-182,-76,-54))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var circle:=StyleBoxFlat.new(); circle.bg_color=Color("18303c") if state=="normal" else Color("254957")
		if state=="disabled": circle.bg_color=Color("14242c")
		circle.border_color=W.GOLD if state=="focus" else Color("41616c")
		circle.set_border_width_all(2); circle.set_corner_radius_all(64)
		craft.add_theme_stylebox_override(state,circle)
	if is_instance_valid(battle_view):
		battle_view.confirm_button = craft
		battle_view.sync_selection_to_hud()
		battle_view.update_preview()

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
	var fan = load("res://presentation/hand_fan.gd").new()
	fan.name = "hand_fan"
	parent.add_child(fan)
	context.hand_reserved_left = 0.0
	fan.set_meta("presentation_role", "battle" if context.phase == "battle" else "voyage")
	fan.create(assets,context.hand,context)
	fan.custom_minimum_size.y=218
	fan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fan.reordered.connect(func(): request("hand_reordered"))
	fan.equipment_double_clicked.connect(func(card): send("install",{"uid":card.uid,"auto":true}))
	fan.battle_action_double_clicked.connect(func(card):
		var bview = find_child("BattleHUDView", true, false)
		if is_instance_valid(bview): bview.on_action_double_clicked(card)
	)
	fan.activated.connect(func(card):
		if context.phase == "battle":
			var bview = find_child("BattleHUDView", true, false)
			if is_instance_valid(bview): bview.on_card_clicked(card)
		elif context.phase == "discard": send("discard",{"uid":card.uid})
		elif context.can_base and card.definition.kind == "survival": send("play",{"uid":card.uid})
		else: request("card",card.uid))
