extends "res://pages/flow_base.gd"
const PHASES := {"navigation":"航行导航","preparation":"航行准备","story":"当前事件","interaction":"商店交易","battle":"战斗进行中","aftermath":"航行收尾","discard":"轮末整理","finished":"航程结束","nightHub":"夜间安排","chapterComplete":"第一层结束"}
const ItemCard = preload("res://presentation/item_card.gd")
const HAND_HEADER_HEIGHT := 56.0
const HAND_HEADER_BOTTOM := -226.0

func rect(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.anchor_left = anchors.x; control.anchor_top = anchors.y
	control.anchor_right = anchors.z; control.anchor_bottom = anchors.w
	control.offset_left = offsets.x; control.offset_top = offsets.y
	control.offset_right = offsets.z; control.offset_bottom = offsets.w

func build() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var stage := Control.new(); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(stage)
	var navigation=preload("res://presentation/nautical_frame.gd").new()
	navigation.name="VoyageNavigationBar"; navigation.ornaments=false; stage.add_child(navigation)
	rect(navigation,Vector4(0,0,1,0),Vector4(24,24,-176,80))
	var compass=TextureRect.new(); compass.name="VoyageCompass"; compass.texture=assets.texture("texture.hud.nautical.compass")
	compass.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; compass.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	compass.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	compass.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(compass)
	rect(compass,Vector4.ZERO,Vector4(16,10,100,94))
	var menu_frame=preload("res://presentation/nautical_frame.gd").new(); menu_frame.ornaments=false; stage.add_child(menu_frame)
	rect(menu_frame,Vector4(1,0,1,0),Vector4(-166,24,-16,80))
	var menu=HBoxContainer.new(); menu.name="VoyageMenu"; stage.add_child(menu)
	rect(menu,Vector4(1,0,1,0),Vector4(-166,27,-24,77))
	var help=W.button(menu,"玩法",func(): request("local_panel","help")); help.tooltip_text="玩法"
	var settings=W.button(menu,"设置",func(): request("local_panel","settings")); settings.tooltip_text="设置"
	var home=W.button(menu,"返回首页",func(): send("home")); home.tooltip_text="返回首页"; home.name="HomeEntry"
	for entry in menu.get_children():
		entry.custom_minimum_size=Vector2(40,40); entry.clip_text=true
		for state in ["normal","hover","pressed","disabled","focus"]: entry.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var focus=StyleBoxFlat.new(); focus.bg_color=Color.TRANSPARENT; focus.border_color=W.GOLD; focus.set_border_width_all(1)
		entry.add_theme_stylebox_override("focus",focus)
		for color in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]: entry.add_theme_color_override(color,Color.TRANSPARENT)
		var icon=preload("res://presentation/nautical_menu_icon.gd").new()
		icon.kind="help" if entry==help else ("settings" if entry==settings else "home")
		entry.add_child(icon); icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		entry.mouse_entered.connect(icon.queue_redraw); entry.mouse_exited.connect(icon.queue_redraw)
	var title=Control.new(); title.mouse_filter=Control.MOUSE_FILTER_IGNORE; navigation.add_child(title)
	rect(title,Vector4(0,0,.42,1),Vector4(85,0,-12,0))
	var reset_view:=W.button(stage,"",func():request("camera_reset"))
	reset_view.name="ResetRaftView"; reset_view.tooltip_text="视角复位\n"+str(context.get("camera_help","平滑恢复默认视角、缩放与位置"))
	reset_view.accessibility_name="视角复位"
	reset_view.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	rect(reset_view,Vector4(0,0.4,0,0.4),Vector4(58,-28,114,28))
	W.UtilityButtonArt.apply(reset_view, "reset")
	var top_view: bool=context.get("camera_mode","oblique")=="top"
	var toggle_view:=W.button(stage,"",func():request("camera_toggle"))
	toggle_view.name="ToggleRaftView"
	toggle_view.accessibility_name="切换木筏视角"
	toggle_view.tooltip_text="当前：%s\n点击切换为%s，并设为默认复位视角" % ["俯视" if top_view else "斜俯视","斜俯视" if top_view else "俯视"]
	rect(toggle_view,Vector4(0,.4,0,.4),Vector4(58,-96,114,-40))
	W.UtilityButtonArt.apply(toggle_view,"view")
	var view_icon:=TextureRect.new(); view_icon.name="ViewModeIcon"
	view_icon.texture=assets.texture("icon.camera.oblique" if top_view else "icon.camera.top")
	view_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; view_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; toggle_view.add_child(view_icon)
	rect(view_icon,Vector4(0,0,1,1),Vector4(6,6,-6,-6))
	var voyage_line=HBoxContainer.new(); voyage_line.name="VoyageHeading"; voyage_line.mouse_filter=Control.MOUSE_FILTER_IGNORE; title.add_child(voyage_line)
	rect(voyage_line,Vector4(0,0,1,1),Vector4(0,0,0,0))
	var voyage_label=W.text(voyage_line,"第 %d / %d 次航行  %s" % [context.voyage,context.length,PHASES[context.phase]],19,W.INK)
	voyage_label.autowrap_mode=TextServer.AUTOWRAP_OFF; voyage_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	voyage_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var environments=Control.new(); environments.name="VoyageEnvironmentNames"; environments.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(environments)
	rect(environments,Vector4(0,0,1,0),Vector4(108,87,-200,115))
	build_environment_names(environments)
	var status=preload("res://presentation/hud/status_hud.gd").new(); status.name="SurgeStatusHUD"; status.minimum_row_width=0
	navigation.add_child(status)
	rect(status,Vector4(.42,0,1,1),Vector4(4,0,-22,0))
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

	var topbar=preload("res://presentation/nautical_frame.gd").new(); topbar.name="VoyageHandTopBar"; stage.add_child(topbar)
	# Both vertical anchors follow the bottom edge: width may stretch, height may not.
	# The window's canvas/UI scale is the only transform that scales its thickness.
	rect(topbar,Vector4(0,1,1,1),Vector4(64,HAND_HEADER_BOTTOM-HAND_HEADER_HEIGHT,-292,HAND_HEADER_BOTTOM))
	if context.phase not in ["chapterComplete","finished"]:
		var ap = preload("res://presentation/hud/action_points_hud.gd").new(); ap.name = "SurgeActionPointHUD"; topbar.add_child(ap)
		rect(ap, Vector4(0,1,0,1), Vector4(0, -90, 360, 0))
		ap.pivot_offset = Vector2.ZERO
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
	rect(frame,Vector4(1,0,1,1),Vector4(-352,108,-24,-316))
	var operation := VBoxContainer.new(); frame.add_child(operation)
	operation.add_theme_constant_override("separation",9)
	frame.visible = context.phase != "story" and context.phase != "battle"
	operation_content(operation)
	var spacer := Control.new(); spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL; operation.add_child(spacer)
	var actions := VBoxContainer.new(); actions.name="VoyageOperationActions"
	actions.add_theme_constant_override("separation",9); operation.add_child(actions)
	for child in operation.get_children():
		if child == actions or child == spacer: continue
		if child is Button or not child.find_children("*","Button",true,false).is_empty():
			child.reparent(actions)
	style_operation_buttons(actions)
	var fit_operation=func():
		frame.offset_top=minf(108.0,maxf(96.0,stage.size.y-316.0-frame.get_combined_minimum_size().y))
		frame.offset_bottom=-316.0
	stage.resized.connect(fit_operation)
	frame.minimum_size_changed.connect(fit_operation)
	fit_operation.call_deferred()
	var battle_view = null
	if context.phase == "battle":
		battle_view = preload("res://pages/battle_hud_view.gd").new()
		battle_view.name = "BattleHUDView"
		stage.add_child(battle_view)
		battle_view.setup(self, context, catalog, assets, session)
	var tray := Control.new(); tray.name="VoyageHandTray"; tray.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(tray)
	rect(tray,Vector4(0,1,1,1),Vector4(64,HAND_HEADER_BOTTOM,-292,-18))
	hand(tray)
	if context.phase != "story":
		var salvage_disabled: bool = int(context.battle.get("ap",0)) < 1 if context.phase == "battle" else not context.can_base or context.ap < 1 or context.get("tutorial_operation","") != ""
		var salvage := W.button(stage, "打捞 · AP1", func(): send("salvage"), salvage_disabled)
		salvage.name = "SalvageEntry"
		salvage.tooltip_text = catalog.entry("equipment","fishingNet").description
		salvage.add_theme_font_size_override("font_size", 16)
		rect(salvage, Vector4(1,1,1,1), Vector4(-252, -250, -28, -192))
		preload("res://presentation/nautical_button_art.gd").apply(salvage)
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
	rect(craft,Vector4(1,1,1,1),Vector4(-228,-184,-52,-8))
	preload("res://presentation/nautical_button_art.gd").apply(craft,true)
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

func build_environment_names(parent: Control) -> void:
	var row := HBoxContainer.new(); row.name="EnvironmentBuffs"; parent.add_child(row)
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",16)
	var items: Array=context.get("environments",[]).duplicate(true)
	# Include the existing non-environment voyage buff in the same status strip.
	if int(context.get("flags",{}).get("rested_until",0))>=int(context.voyage):
		items.append({"name":"休整余裕","description":"基地AP上限+1。","negative":false,"pending":false,"remaining":int(context.flags.rested_until)-int(context.voyage)+1,"pending_refresh":0})
	for item in items:
		var label := Label.new(); row.add_child(label)
		label.text=str(item.name)+( " · 待生效" if item.pending else "")
		label.add_theme_font_size_override("font_size",15)
		label.add_theme_color_override("font_color",Color("ef9c8b") if item.negative else Color("b9d9c5"))
		label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.95)); label.add_theme_constant_override("shadow_offset_x",1); label.add_theme_constant_override("shadow_offset_y",2)
		label.mouse_filter=Control.MOUSE_FILTER_STOP
		label.tooltip_text=str(item.description)+"\n"+("下一航次生效；" if item.pending else "当前生效；")+"剩余%d次航行。" % int(item.remaining)
		if int(item.pending_refresh)>0: label.tooltip_text+="\n本轮结束后刷新为%d次航行。" % int(item.pending_refresh)

func operation_content(box: Node) -> void:
	if context.phase=="story": return
	W.text(box,PHASES[context.phase],25,W.GOLD)
	if context.mode=="story" and (not context.known_quests.is_empty() or not context.known_clues.is_empty()): action(box,"任务与线索","panel",{"id":"journal"})
	match context.phase:
		"navigation":
			W.text(box,"选择目的地；出发扣精神，轮末弃牌后扣食水。",16,W.MUTED)
			var chance: float=float(context.get("navigation",{}).get("wrong_direction_chance",0))
			if chance>0:
				var heading := HBoxContainer.new(); box.add_child(heading)
				W.text(heading,"偏航 %d%%" % roundi(chance*100),15,W.GOLD)
				action(heading,"定向 · 木头1","fix_heading",{},amount("wood")<1,"花木头1、0 AP，防止本次启航偏航")
			elif context.get("navigation",{}).get("heading_locked",false): W.text(box,"本次航向已固定",15,W.MUTED)
			for node in context.candidates:
				var route := HBoxContainer.new(); box.add_child(route)
				var button := W.button(route,"出发 · "+node.name,func(): send("voyage",{"id":node.visit_id}))
				button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				button.custom_minimum_size.y=40
				button.tooltip_text = node.get("description","")
				if node.get("visibility","full")!="full":
					action(route,"侦察 · SAN8","scout",{"id":node.visit_id},int(context.player.sanity)<=8,"揭示此候选，不改变其内容")
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
			W.text(box,"轮末弃牌后食水各扣%d，归零各扣1生命。" % int(context.get("survival_settlement",{}).get("food_water_cost",30)),16,W.MUTED)
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
	fan.custom_minimum_size.y=0
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
