extends "res://pages/flow_base.gd"
const PHASES := {"navigation":"航行导航","preparation":"航行准备","story":"当前事件","interaction":"商店交易","battle":"战斗进行中","aftermath":"航行收尾","discard":"轮末整理","finished":"航程结束","chapterComplete":"第一层结束"}
const ItemCard = preload("res://presentation/item_card.gd")
const HAND_HEADER_HEIGHT := 56.0
const HAND_HEADER_BOTTOM := -226.0
## Persistent HUD stays above the node-event plate (z 1 in flow_app).
const ABOVE_EVENT := 2
## Top offset of the right-hand operation frame. Fixed so the panel never resizes.
const OPERATION_TOP := 96.0
# Live references for the partial refresh paths. A destination choice only rebuilds
# the navigation texts and rows; a departure updates the regions that really changed.
var _operation_frame: Control
var _operation_box: VBoxContainer
var _operation_spacer: Control
var _operation_actions: VBoxContainer
var _heading_label: Label
var _status_hud: Control
var _action_points: Control
var _capacity_label: Label
var _environment_host: Control
var _nav_header_nodes: Array = []
var _nav_row_nodes: Array = []
var _environment_signature := ""

func refresh_camera_mode(mode: String) -> void:
	context.camera_mode=mode
	var toggle:=find_child("ToggleRaftView",true,false) as Button
	var icon:=find_child("ViewModeIcon",true,false) as TextureRect
	var top: bool=mode=="top"
	if toggle!=null: toggle.tooltip_text="当前：%s\n点击切换为%s，并设为默认复位视角" % ["俯视" if top else "斜俯视","斜俯视" if top else "俯视"]
	if icon!=null: icon.texture=assets.texture("icon.camera.oblique" if top else "icon.camera.top")

func refresh_battle_selection(value: String) -> void:
	context.ui_state.battle_selection=value

## Update the stable battle presentation after a dispatched action. Structural
## changes deliberately fall back to a full render at the application boundary.
func refresh_after_battle(view: Dictionary) -> bool:
	if context.get("phase","")!="battle" or view.get("phase","")!="battle": return false
	if str(context.get("battle",{}).get("id",""))!=str(view.get("battle",{}).get("id","")): return false
	if int(view.get("battle",{}).get("hp",0))<=0: return false
	if JSON.stringify(context.get("cells",[]))!=JSON.stringify(view.get("cells",[])): return false
	if JSON.stringify(context.get("hand",[]))!=JSON.stringify(view.get("hand",[])): return false
	if JSON.stringify(context.get("boost_cards",[]))!=JSON.stringify(view.get("boost_cards",[])): return false
	var battle_view:=find_child("BattleHUDView",true,false)
	if not is_instance_valid(battle_view) or not battle_view.has_method("refresh_after_action"): return false
	_merge_view(view)
	refresh_heading()
	refresh_status()
	refresh_capacity()
	refresh_battle_shields()
	var salvage:=find_child("SalvageEntry",true,false) as Button
	if is_instance_valid(salvage): salvage.disabled=int(context.battle.get("ap",0))<1
	return battle_view.refresh_after_action(view)

func refresh_battle_shields() -> void:
	var badge:=find_child("BattleShieldSummary",true,false) as PanelContainer
	if not is_instance_valid(badge): return
	var row:=badge.get_child(0) as HBoxContainer if badge.get_child_count()>0 else null
	if not is_instance_valid(row): return
	var shields: Array=context.get("battle",{}).get("shields",[])
	var total:=0
	for shield in shields: total+=int(shield.get("amount",0))
	for child in row.get_children(): row.remove_child(child); child.queue_free()
	var style:=compact_style(); style.set_corner_radius_all(10)
	style.content_margin_left=8; style.content_margin_right=8
	style.content_margin_top=2; style.content_margin_bottom=2
	if total>0:
		style.bg_color=Color(0.06,0.18,0.32,0.85); style.border_color=Color(0.35,0.75,1.0,0.8)
	badge.add_theme_stylebox_override("panel",style)
	var turn:=int(context.battle.get("turn",1))
	var ShieldIcon=preload("res://presentation/shield_icon.gd")
	if total>0:
		for shield in shields:
			for _i in range(int(shield.get("amount",0))):
				row.add_child(ShieldIcon.new(int(shield.get("expires_turn",0))<=turn,false))
	else: row.add_child(ShieldIcon.new(true,true))
	var value:=Label.new(); value.name="ShieldValue"; value.text=str(total); value.visible=false; row.add_child(value)
	badge.visible=context.phase=="battle" or total>0
	var width:=maxi(40,16+total*22)
	badge.anchor_left=1; badge.anchor_right=1
	badge.offset_left=-width-14; badge.offset_right=-14

func rect(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.anchor_left = anchors.x; control.anchor_top = anchors.y
	control.anchor_right = anchors.z; control.anchor_bottom = anchors.w
	control.offset_left = offsets.x; control.offset_top = offsets.y
	control.offset_right = offsets.z; control.offset_bottom = offsets.w

func build() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Story events dim the world and its utilities instead of removing them.
	var event_covered: bool = context.phase == "story"
	var stage := Control.new(); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(stage)
	var navigation=preload("res://presentation/nautical_frame.gd").new()
	navigation.name="VoyageNavigationBar"; navigation.ornaments=false; stage.add_child(navigation)
	navigation.z_index=ABOVE_EVENT
	rect(navigation,Vector4(0,0,1,0),Vector4(24,24,-176,80))
	var compass=TextureRect.new(); compass.name="VoyageCompass"; compass.texture=assets.texture("texture.hud.nautical.compass")
	compass.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; compass.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	compass.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	compass.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(compass); compass.z_index=ABOVE_EVENT
	rect(compass,Vector4.ZERO,Vector4(16,10,100,94))
	var menu_frame=preload("res://presentation/nautical_frame.gd").new(); menu_frame.ornaments=false; stage.add_child(menu_frame); menu_frame.z_index=ABOVE_EVENT
	rect(menu_frame,Vector4(1,0,1,0),Vector4(-166,24,-16,80))
	var menu=HBoxContainer.new(); menu.name="VoyageMenu"; stage.add_child(menu); menu.z_index=ABOVE_EVENT
	rect(menu,Vector4(1,0,1,0),Vector4(-166,27,-24,77))
	if context.get("mobile",false):
		rect(menu,Vector4(1,0,1,0),Vector4(-216,18,-16,78))
		rect(menu_frame,Vector4(1,0,1,0),Vector4(-224,14,-8,82))
		rect(navigation,Vector4(0,0,1,0),Vector4(24,24,-234,80))
		menu.add_theme_constant_override("separation",10)
	var help=W.button(menu,"游戏说明",func(): request("local_panel","help"))
	help.name="GameHelpEntry"; help.tooltip_text="游戏说明 · 操作指南与游戏流程"; help.accessibility_name="游戏说明"
	var settings=W.button(menu,"设置",func(): request("local_panel","settings")); settings.tooltip_text="设置"
	var home=W.button(menu,"返回首页",func(): send("home")); home.tooltip_text="返回首页"; home.name="HomeEntry"
	for entry in menu.get_children():
		entry.custom_minimum_size=Vector2(40,40); entry.clip_text=true
		if context.get("mobile",false): entry.custom_minimum_size=Vector2(60,60)
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
	var camera_utilities_visible: bool = context.phase != "battle"
	var collection:=W.button(stage,"",func():send("panel",{"id":"collectibles"}))
	collection.name="CollectiblesEntry"; collection.z_index=ABOVE_EVENT
	collection.accessibility_name="潮汐遗物"; collection.tooltip_text="潮汐遗物 · 已持有 %d 件" % context.get("collectibles",[]).size()
	rect(collection,Vector4(0,.4,0,.4),Vector4(58,40,114,96))
	W.UtilityButtonArt.apply(collection,"view")
	var treasure:=TextureRect.new(); treasure.name="TreasureIcon"; treasure.texture=assets.texture("icon.treasure")
	treasure.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; treasure.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	treasure.mouse_filter=Control.MOUSE_FILTER_IGNORE; collection.add_child(treasure)
	rect(treasure,Vector4(0,0,1,1),Vector4(10,10,-10,-10))
	reset_view.visible = camera_utilities_visible
	toggle_view.visible = camera_utilities_visible
	# The event plate is drawn above these utilities: keep them visible but untouchable.
	reset_view.focus_mode = Control.FOCUS_NONE if event_covered or not camera_utilities_visible else Control.FOCUS_ALL
	toggle_view.focus_mode = Control.FOCUS_NONE if event_covered or not camera_utilities_visible else Control.FOCUS_ALL
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
	_heading_label=voyage_label
	var environments=Control.new(); environments.name="VoyageEnvironmentNames"; environments.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(environments); environments.z_index=ABOVE_EVENT
	rect(environments,Vector4(0,0,1,0),Vector4(108,87,-200,115))
	_environment_host=environments
	build_environment_names(environments)
	var status=preload("res://presentation/hud/status_hud.gd").new(); status.name="SurgeStatusHUD"; status.minimum_row_width=0
	if context.get("mobile",false): status.font_size=22
	navigation.add_child(status)
	_status_hud=status
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

	var topbar=preload("res://presentation/nautical_frame.gd").new(); topbar.name="VoyageHandTopBar"; stage.add_child(topbar); topbar.z_index=ABOVE_EVENT
	# Both vertical anchors follow the bottom edge: width may stretch, height may not.
	# The window's canvas/UI scale is the only transform that scales its thickness.
	rect(topbar,Vector4(0,1,1,1),Vector4(64,HAND_HEADER_BOTTOM-HAND_HEADER_HEIGHT,-292,HAND_HEADER_BOTTOM))
	if context.phase not in ["chapterComplete","finished"]:
		var ap = preload("res://presentation/hud/action_points_hud.gd").new(); ap.name = "SurgeActionPointHUD"; topbar.add_child(ap)
		rect(ap, Vector4(0,1,0,1), Vector4(0, -90, 360, 0))
		ap.pivot_offset = Vector2.ZERO
		ap.z_index = 2
		_action_points = ap
		ap.label_text="行动·战意%d" % int(context.battle.get("origin_ap",0)) if context.phase=="battle" and context.origin=="zealot" else "行动点"
		ap.set_ap(context.battle.ap if context.phase == "battle" else context.ap,context.player.battle_ap if context.phase == "battle" else context.player.base_ap)
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
	_capacity_label = count_label
	count_label.tooltip_text=str(context.get("origin_status",""))
	count_label.mouse_filter=Control.MOUSE_FILTER_STOP
	counter.tooltip_text=count_label.tooltip_text

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
	var operation_style:=compact_style()
	if context.get("mobile",false):
		operation_style.content_margin_top=12; operation_style.content_margin_bottom=12
	frame.add_theme_stylebox_override("panel",operation_style)
	# Fixed operation frame: one rect for every phase, so adding a title or an extra
	# line of detail never resizes the panel. Text grows downwards inside it instead.
	rect(frame,Vector4(1,0,1,1),Vector4(-352,OPERATION_TOP,-24,-294 if context.get("mobile",false) else -316))
	var operation := VBoxContainer.new()
	if context.get("mobile",false):
		var scroll := ScrollContainer.new(); scroll.name="MobileOperationScroll"
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		frame.add_child(scroll); scroll.add_child(operation)
		operation.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		operation.size_flags_vertical=Control.SIZE_EXPAND_FILL
	else: frame.add_child(operation)
	operation.add_theme_constant_override("separation",6 if context.get("mobile",false) else 9)
	_operation_frame = frame; _operation_box = operation
	frame.visible = context.phase != "story" and context.phase != "battle"
	operation_content(operation)
	var spacer := Control.new(); spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL; operation.add_child(spacer)
	_operation_spacer = spacer
	var actions := VBoxContainer.new(); actions.name="VoyageOperationActions"
	actions.add_theme_constant_override("separation",9); operation.add_child(actions)
	_operation_actions = actions
	for child in operation.get_children():
		if child == actions or child == spacer: continue
		if child is Button or not child.find_children("*","Button",true,false).is_empty():
			child.reparent(actions)
	style_operation_buttons(actions)
	var battle_view = null
	if context.phase == "battle":
		battle_view = preload("res://pages/battle_hud_view.gd").new()
		battle_view.name = "BattleHUDView"
		stage.add_child(battle_view)
		battle_view.setup(self, context, catalog, assets, session)
	var tray := Control.new(); tray.name="VoyageHandTray"; tray.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.add_child(tray); tray.z_index=ABOVE_EVENT
	rect(tray,Vector4(0,1,1,1),Vector4(64,HAND_HEADER_BOTTOM,-292,-18))
	hand(tray)
	# Phones stretch the event page over the hand area, so the frozen hand strip
	# and its header bar step aside there. Desktop keeps them visible above the
	# 328-offset event page.
	if event_covered and context.get("mobile",false):
		tray.hide()
		topbar.hide()	# Keep salvage in the tree during events: it is dimmed by the plate, not deleted.
	var salvage_disabled: bool
	if context.phase == "battle":
		salvage_disabled = int(context.battle.get("ap",0)) < 1
	else:
		var teaching := str(context.get("tutorial_operation",""))
		salvage_disabled = (not bool(context.get("can_base",false))) or int(context.get("ap",0)) < 1 or teaching not in ["","salvage"]
	var salvage := W.button(stage, "打捞 · AP1", func(): send("salvage"), salvage_disabled)
	salvage.name = "SalvageEntry"
	salvage.set_meta("salvage_disabled",salvage_disabled)
	salvage.set_meta("tutorial_operation",str(context.get("tutorial_operation","")))
	salvage.tooltip_text = catalog.entry("equipment","fishingNet").description
	salvage.add_theme_font_size_override("font_size", 18 if context.get("mobile",false) else 16)
	rect(salvage, Vector4(1,1,1,1), Vector4(-252, -262 if context.get("mobile",false) else -250, -28, -192))
	preload("res://presentation/nautical_button_art.gd").apply(salvage)
	salvage.focus_mode = Control.FOCUS_NONE if event_covered else Control.FOCUS_ALL
	var craft: Button
	if context.phase == "battle":
		craft = W.button(stage,"迎击",func():
			var bv = find_child("BattleHUDView", true, false)
			if is_instance_valid(bv): bv.confirm_action()
		, true)
		craft.name = "ConfirmBattleAction"
	else:
		craft = W.button(stage,"合成/转化",func(): send("panel",{"id":"craft"}),not context.can_base)
		craft.name = "CraftEntry"
	craft.add_theme_font_size_override("font_size",21)
	craft.z_index = ABOVE_EVENT
	rect(craft,Vector4(1,1,1,1),Vector4(-228,-184,-52,-8))
	preload("res://presentation/nautical_button_art.gd").apply(craft,true)
	# The workbench entry sits in the bottom-right corner, which phones cover with
	# the taller event page; desktop keeps it.
	if event_covered and context.get("mobile",false): craft.hide()
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
		child.custom_minimum_size.y = 60 if context.get("mobile",false) else 38
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

func environment_items() -> Array:
	var items: Array=context.get("environments",[]).duplicate(true)
	# Include the existing non-environment voyage buff in the same status strip.
	if int(context.get("flags",{}).get("rested_until",0))>=int(context.voyage):
		items.append({"name":"休整余裕","description":"基地AP上限+1。","negative":false,"pending":false,"remaining":int(context.flags.rested_until)-int(context.voyage)+1,"pending_refresh":0})
	return items

func build_environment_names(parent: Control) -> void:
	var row := HBoxContainer.new(); row.name="EnvironmentBuffs"; parent.add_child(row)
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",16)
	var items: Array=environment_items()
	_environment_signature = JSON.stringify(items)
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
	match context.phase:
		"navigation":
			# Destination choice is a pure interface decision, so the whole panel can be
			# rebuilt in place later without touching the rest of the HUD.
			navigation_content(box,box)
		"preparation":
			W.text(box,"已抵达："+context.node.name,18)
			W.text(box,"可使用物资、制造与管理设备。",16,W.MUTED)
			action(box,"进入节点","enter")
			W.primary(box.get_child(box.get_child_count()-1))
		"story","interaction","battle":
			W.text(box,context.node.name,20)
			W.text(box,"处理完当前事件后再结束航行。",16,W.MUTED)
			action(box,"处理当前事件","event")
			W.primary(box.get_child(box.get_child_count()-1))
		"aftermath":
			W.text(box,"节点已完成，可继续使用剩余AP。",17,W.MUTED)
			W.text(box,"轮末弃牌后食水各扣%d，归零各扣1生命。" % int(context.get("survival_settlement",{}).get("food_water_cost",30)),16,W.MUTED)
			action(box,"结束航行","end_voyage")
			W.primary(box.get_child(box.get_child_count()-1))
		"discard": W.text(box,"手牌超限，选择要弃置的物资；达标后自动进入导航。",18)
		"chapterComplete":
			W.text(box,"第一层完成",23,W.GOLD)
			W.text(box,"本章成果已保存。第二层尚未开放。",18)
			W.text(box,"章节成果可从结算页回看。",16,W.MUTED)
		"finished":
			W.text(box,{"survived":"灯火未熄","withdrawn":"离开潮眼","dead":"沉入深潮","mad":"迷失潮声","abandon":"返回岸边"}.get(context.result,context.result),24,W.GOLD)
			W.text(box,"完成 %d 个节点" % context.completed,18)
			W.text(box,"本局涌潮点 %d" % context.completed,16,W.MUTED)

## Destination step: header texts above the spacer, one row per candidate below it.
## Called once per full build (rows are then reparented into the action stack) and
## again whenever only the chosen destination changed.
func navigation_content(header_parent: Node, row_parent: Node) -> void:
	_nav_header_nodes = []
	_nav_row_nodes = []
	# Two-step departure: pick a destination first, then confirm inside that row.
	var selected: Dictionary = {}
	var picked: String = str(context.get("ui_state",{}).get("nav_select",""))
	if picked != "":
		for candidate in context.get("candidates",[]):
			if str(candidate.get("visit_id","")) == picked: selected = candidate; break
	if selected.is_empty():
		_nav_track(W.text(header_parent,"选择目的地；出发扣精神，轮末弃牌后扣食水。",16,W.MUTED),false)
	else:
		var title := W.text(header_parent,str(selected.name),21,W.INK)
		title.name = "NavigationDestinationTitle"
		_nav_track(title,false)
		var detail := W.text(header_parent,str(selected.get("description","")),16,W.MUTED)
		detail.name = "NavigationDestinationDetail"
		_nav_track(detail,false)
	var chance: float=float(context.get("navigation",{}).get("wrong_direction_chance",0))
	if chance>0:
		var heading := HBoxContainer.new(); row_parent.add_child(heading)
		W.text(heading,"偏航 %d%%" % roundi(chance*100),15,W.GOLD)
		action(heading,"定向 · 木头1","fix_heading",{},amount("wood")<1,"花木头1、0 AP，防止本次启航偏航")
		_nav_track(heading,true)
	elif context.get("navigation",{}).get("heading_locked",false):
		_nav_track(W.text(header_parent,"本次航向已固定",15,W.MUTED),false)
	for node in context.get("candidates",[]):
		var route := HBoxContainer.new(); row_parent.add_child(route)
		var chosen: bool = not selected.is_empty() and str(node.get("visit_id","")) == str(selected.get("visit_id",""))
		if chosen:
			var depart := W.button(route,"出发",func(): send("voyage",{"id":node.visit_id}))
			depart.name = "NavigationDepart"
			depart.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; depart.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			depart.custom_minimum_size.y=60 if context.get("mobile",false) else 40
			depart.tooltip_text = "驶向"+str(node.name)
			W.primary(depart)
		else:
			var option := W.button(route,str(node.name),func(): request("nav_select",str(node.visit_id)))
			option.name = "NavigationOption"
			option.set_meta("visit_id",str(node.visit_id))
			option.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; option.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			option.custom_minimum_size.y=60 if context.get("mobile",false) else 40
			option.tooltip_text = str(node.get("description",""))
		_nav_track(route,true)
		if node.get("visibility","full")!="full":
			var scout_cost: int=int(context.get("navigation",{}).get("scout_cost",8))
			action(route,"侦察 · SAN%d" % scout_cost,"scout",{"id":node.visit_id},int(context.player.sanity)<=scout_cost,"揭示此候选，不改变其内容")

## Mark a node as part of the rebuildable navigation content.
func _nav_track(node: Node, is_row: bool) -> Node:
	node.set_meta("nav_dynamic",true)
	if is_row: _nav_row_nodes.append(node)
	else: _nav_header_nodes.append(node)
	return node

func _nav_nodes() -> Array:
	return _nav_header_nodes + _nav_row_nodes

func _nav_owns(node: Node) -> bool:
	var current: Node = node
	while current != null and current != self:
		if current.has_meta("nav_dynamic"): return true
		current = current.get_parent()
	return false

func _clear_navigation_nodes() -> void:
	for node in _nav_nodes():
		if not is_instance_valid(node): continue
		var parent: Node = node.get_parent()
		if parent != null: parent.remove_child(node)
		node.queue_free()
	_nav_header_nodes = []
	_nav_row_nodes = []

## Merge a fresh rule view into the live page context so every surviving control
## sends its next command with the current revision and state.
func _merge_view(view: Dictionary) -> void:
	for key in view: context[key] = view[key]

func _live_operation() -> bool:
	if not is_instance_valid(_operation_frame) or not _operation_frame.visible: return false
	if not is_instance_valid(_operation_box) or not is_instance_valid(_operation_actions): return false
	return is_instance_valid(_operation_spacer)

## Destination choice: rebuild only the navigation texts and rows. The operation
## frame, hand, status bar and raft interaction instances stay alive.
func refresh_navigation(view: Dictionary) -> bool:
	if context.get("phase","") != "navigation" or not _live_operation(): return false
	var focus := get_viewport().gui_get_focus_owner()
	var keep_focus := is_instance_valid(focus) and _nav_owns(focus)
	_merge_view(view)
	_clear_navigation_nodes()
	navigation_content(_operation_box,_operation_actions)
	for node in _nav_header_nodes:
		_operation_box.move_child(node,_operation_spacer.get_index())
	if keep_focus:
		var target: Control = find_child("NavigationDepart",true,false)
		if not is_instance_valid(target):
			for option in find_children("NavigationOption","Button",true,false):
				if str(option.get_meta("visit_id","")) == str(context.get("ui_state",{}).get("nav_select","")): target = option; break
		if is_instance_valid(target): target.grab_focus()
	return true

## Ordinary navigation -> preparation departure: refresh only the regions that
## changed. The hand and its tray keep their instances because the projection,
## capacity and limit are unchanged (the caller verifies that beforehand).
func refresh_after_departure(view: Dictionary) -> bool:
	if not _live_operation(): return false
	_merge_view(view)
	_clear_navigation_nodes()
	refresh_heading()
	refresh_status()
	refresh_capacity()
	refresh_environments()
	# The phase title and the available actions changed, so the whole panel content
	# is rebuilt inside the same frame; nothing outside it is replaced.
	for child in _operation_box.get_children():
		if child == _operation_spacer or child == _operation_actions: continue
		_operation_box.remove_child(child); child.queue_free()
	for child in _operation_actions.get_children():
		_operation_actions.remove_child(child); child.queue_free()
	operation_content(_operation_box)
	for child in _operation_box.get_children():
		if child == _operation_spacer or child == _operation_actions: continue
		if child is Button or not child.find_children("*","Button",true,false).is_empty(): child.reparent(_operation_actions)
		else: _operation_box.move_child(child,_operation_spacer.get_index())
	style_operation_buttons(_operation_actions)
	return true

## Same-phase operation refresh. The caller verifies that no board topology or
## panel transition occurred; only value labels, policy and the hand projection
## are reconciled here.
func refresh_after_operation(view: Dictionary) -> bool:
	if not _live_operation() or context.get("phase","") != view.get("phase",""): return false
	if context.get("panel","") != view.get("panel","") or view.get("phase","") in ["battle", "story", "aftermath", "finished", "chapterComplete"]: return false
	if JSON.stringify(context.get("cells",[])) != JSON.stringify(view.get("cells",[])): return false
	var fan:=find_child("hand_fan",true,false)
	var hand_changed:=JSON.stringify(context.get("hand",[])) != JSON.stringify(view.get("hand",[]))
	if hand_changed and (not is_instance_valid(fan) or not fan.has_method("refresh_entries")): return false
	_merge_view(view)
	refresh_heading(); refresh_status(); refresh_capacity(); refresh_environments()
	if hand_changed and not fan.refresh_entries(context.hand,context): return false
	var salvage:=find_child("SalvageEntry",true,false) as Button
	if is_instance_valid(salvage): salvage.disabled=not bool(context.get("can_base",false)) or int(context.get("ap",0))<1
	var craft:=find_child("CraftEntry",true,false) as Button
	if is_instance_valid(craft): craft.disabled=not bool(context.get("can_base",false))
	return true

func refresh_heading() -> void:
	if is_instance_valid(_heading_label):
		_heading_label.text = "第 %d / %d 次航行  %s" % [context.voyage,context.length,PHASES.get(context.phase,context.phase)]

func refresh_status() -> void:
	if not is_instance_valid(_status_hud): return
	for key in {"hp":"health","hunger":"satiety","hydration":"water","sanity":"sanity"}:
		_status_hud.set_stat({"hp":"health","hunger":"satiety","hydration":"water","sanity":"sanity"}[key],context.player[key],context.player[key+"_max"])

func refresh_capacity() -> void:
	if is_instance_valid(_capacity_label):
		_capacity_label.text = "%d/%d" % [int(context.get("capacity",0)),int(context.player.limit)]
		_capacity_label.tooltip_text=str(context.get("origin_status",""))
		_capacity_label.get_parent().tooltip_text=_capacity_label.tooltip_text
	if not is_instance_valid(_action_points): return
	_action_points.label_text = "行动·战意%d" % int(context.battle.get("origin_ap",0)) if context.phase=="battle" and context.origin=="zealot" else "行动点"
	_action_points.set_ap(context.battle.ap if context.phase == "battle" else context.ap,context.player.battle_ap if context.phase == "battle" else context.player.base_ap)

func refresh_environments() -> void:
	if not is_instance_valid(_environment_host): return
	if _environment_signature == JSON.stringify(environment_items()): return
	var row := _environment_host.get_node_or_null("EnvironmentBuffs")
	if is_instance_valid(row): _environment_host.remove_child(row); row.queue_free()
	build_environment_names(_environment_host)

func refresh_hand_preferences() -> void:
	var old_hand:=find_child("hand_fan",true,false)
	if not is_instance_valid(old_hand): return
	var saved: Dictionary=old_hand.capture_visual()
	var parent:=old_hand.get_parent()
	parent.remove_child(old_hand); old_hand.queue_free()
	hand(parent)
	var replacement:=parent.get_node("hand_fan")
	replacement.restore_visual(saved)

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
	fan.inspected.connect(func(card):
		if context.phase == "battle":
			var bview = find_child("BattleHUDView", true, false)
			if is_instance_valid(bview): bview.on_card_clicked(card)
		else: request("card",card.uid))
