extends Control
## Four supplied panels: monster, enemy intent, action preview, combat log.
## Presentation only; legal actions continue through the existing HUD dispatcher.

const Battle = preload("res://core/battle_rules.gd")
const W = preload("res://presentation/widgets.gd")
const RESOURCES := ["wood","iron","rope","plastic","cloth"]

var hud: Control
var context: Dictionary
var catalog: RefCounted
var assets: RefCounted
var session: RefCounted
var mobile := false

var selected_action := ""
var selected_resource_uid := ""
var selected_card_uid := ""
var selected_buff_uid := ""

var monster_hp_label: Label
var monster_hp_bar: ProgressBar
var monster_shield_label: Label
var intent_label: Label
var preview_summary_label: Label
var preview_detail_label: Label
var turn_label: Label
var shield_summary_label: Label
var log_box: VBoxContainer
var log_scroll: ScrollContainer
var confirm_button: Button

func setup(parent_hud: Control, view: Dictionary, cat: RefCounted, art: RefCounted, sess: RefCounted) -> void:
	hud = parent_hud
	context = view
	mobile = bool(view.get("mobile",false))
	catalog = cat
	assets = art
	session = sess
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	build_ui()

var panel_layout: Control

func build_ui() -> void:
	# Art is fitted as one composition; each texture keeps its original aspect.
	var backdrop := Control.new()
	backdrop.name = "BattleBackdrop"
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(backdrop)
	panel_layout = Control.new()
	panel_layout.name = "ModalSurface"
	panel_layout.mouse_filter = MOUSE_FILTER_IGNORE
	backdrop.add_child(panel_layout)
	var monster := art_panel("MonsterPanel", "texture.battle.panel.monster")
	var intent := art_panel("EnemyIntentPanel", "texture.battle.panel.intent")
	var preview := art_panel("ActionPreviewPanel", "texture.battle.panel.preview")
	var log_panel := art_panel("CombatLogPanel", "texture.battle.panel.log")
	build_monster_panel(monster)
	build_action_preview_panel(content_area(intent, Vector4(0.06,0.08,0.94,0.87)), content_area(preview, Vector4(0.06,0.08,0.94,0.88)))
	build_combat_log_panel(content_area(log_panel, Vector4(0.15,0.07,0.91,0.91)))
	if mobile: adapt_mobile_controls(panel_layout)
	resized.connect(layout_panels)
	layout_panels()
	restore_saved_selection()
	update_preview()

func art_panel(id: String, asset_id: String) -> Control:
	var panel := Control.new()
	panel.name = id
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel_layout.add_child(panel)
	var art: Control
	if mobile and id != "MonsterPanel":
		# Keep decorative corners at a stable size while the inner panel expands.
		var patch := NinePatchRect.new()
		patch.texture = assets.texture(asset_id)
		patch.patch_margin_left = 128; patch.patch_margin_right = 128
		patch.patch_margin_top = 80; patch.patch_margin_bottom = 48
		patch.scale = Vector2.ONE * 0.65
		panel.resized.connect(func(): patch.size = panel.size / 0.65)
		art = patch
	else:
		var image := TextureRect.new()
		image.texture = assets.texture(asset_id)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art = image
	art.name = "PanelArt"
	art.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(art)
	if art is TextureRect: art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return panel

func content_area(parent: Control, bounds: Vector4) -> MarginContainer:
	var area := MarginContainer.new()
	area.name = "PanelContent"
	area.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(area)
	area.anchor_left = bounds.x; area.anchor_top = bounds.y
	area.anchor_right = bounds.z; area.anchor_bottom = bounds.w
	if mobile and parent.name != "MonsterPanel":
		area.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		area.offset_left=24; area.offset_right=-24
		area.offset_top=14; area.offset_bottom=-14
	return area

func layout_panels() -> void:
	if mobile:
		layout_mobile_panels()
		return
	# Use the actual HUD boundaries rather than a fixed low starting position.
	# Work in this view's coordinates so canvas/UI scaling is applied only once.
	var to_view := get_global_transform().affine_inverse()
	var navigation := hud.find_child("VoyageNavigationBar",true,false) as Control
	var action_points := hud.find_child("SurgeActionPointHUD",true,false) as Control
	var top := 96.0
	var bottom := size.y-316.0-8.0
	if navigation != null:
		top = (to_view * navigation.get_global_rect().end).y + 16.0
	var environment := hud.find_child("VoyageEnvironmentNames",true,false) as Control
	if environment != null:
		var row := environment.get_node_or_null("EnvironmentBuffs")
		if row != null and row.get_child_count() > 0:
			top = maxf(top,(to_view * environment.get_global_rect().end).y + 8.0)
	if action_points != null:
		bottom = (to_view * action_points.get_global_rect().position).y - 8.0
	var available := Vector2(maxf(1.0,size.x-64.0), maxf(1.0,bottom-top))
	# Scale compact layouts' content together with the original panel artwork.
	var content_scale := minf(1.0, available.y/414.0)
	panel_layout.scale = Vector2.ONE*content_scale
	var fit := minf(available.x/(1534.0*content_scale), available.y/(511.0*content_scale))
	panel_layout.position = Vector2((size.x-1534.0*fit*content_scale)*0.5, top)
	panel_layout.size = Vector2(1534,511)*fit
	var rects := [Rect2(0,0,415,511), Rect2(431,0,686,255), Rect2(431,294,687,217), Rect2(1134,0,400,505)]
	for i in range(rects.size()):
		var panel: Control = panel_layout.get_child(i)
		panel.position = rects[i].position*fit
		panel.size = rects[i].size*fit

func layout_mobile_panels() -> void:
	# Use the space between the status strip and hand instead of scaling text.
	var top := 112.0
	var height := maxf(1.0,size.y-282.0-24.0-top)
	var width := maxf(1.0,size.x-28.0-28.0)
	var gap := 16.0
	var portrait_width := height * 415.0/511.0
	var log_width := clampf(width*.25,280.0,400.0)
	var middle_width := maxf(1.0,width-portrait_width-log_width-gap*2)
	# The taller touch reset button needs a deeper preview body. Intent text
	# keeps its own scroll region for unusually long enemy/status descriptions.
	var intent_height := height*.4
	var preview_height := height-gap-intent_height
	panel_layout.scale = Vector2.ONE
	panel_layout.position = Vector2(28,top)
	panel_layout.size = Vector2(width,height)
	var rects := [Rect2(0,0,portrait_width,height), Rect2(portrait_width+gap,0,middle_width,intent_height), Rect2(portrait_width+gap,intent_height+gap,middle_width,preview_height), Rect2(width-log_width,0,log_width,height)]
	for i in range(rects.size()):
		var panel: Control = panel_layout.get_child(i)
		panel.position=rects[i].position; panel.size=rects[i].size

func adapt_mobile_controls(node: Node) -> void:
	if node is Label: node.add_theme_font_size_override("font_size",maxi(18,node.get_theme_font_size("font_size")))
	if node is BaseButton:
		node.custom_minimum_size.y=maxf(56,node.custom_minimum_size.y)
		node.add_theme_font_size_override("font_size",18)
	for child in node.get_children(): adapt_mobile_controls(child)

func scrollable_content(parent: Control, id: String) -> Node:
	if not mobile: return parent
	var scroll := ScrollContainer.new()
	scroll.name=id; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=SIZE_EXPAND_FILL; scroll.size_flags_horizontal=SIZE_EXPAND_FILL
	parent.add_child(scroll)
	return scroll

func build_monster_panel(parent: Control) -> void:
	var enemy_id: String = str(context.battle.get("id", "biter"))
	var enemy: Dictionary = preload("res://core/difficulty_rules.gd").enemy(catalog,context,enemy_id)
	var header := content_area(parent, Vector4(0.15,0.12,0.85,0.20))
	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", 0)
	header.add_child(title)
	var cur_hp: int = int(context.battle.get("hp", enemy.hp))
	var max_hp: int = int(enemy.get("hp", cur_hp))
	monster_hp_label = W.text(title, "%s  ·  %d/%d" % [enemy.name,cur_hp,max_hp], 17, W.GOLD)
	monster_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	monster_hp_bar = ProgressBar.new()
	monster_hp_bar.custom_minimum_size.y = 5
	monster_hp_bar.show_percentage = false
	monster_hp_bar.max_value = float(maxi(1,max_hp))
	monster_hp_bar.value = float(cur_hp)
	var fill := StyleBoxFlat.new(); fill.bg_color = Color("ac514c")
	var bg := StyleBoxFlat.new(); bg.bg_color = Color("142026")
	monster_hp_bar.add_theme_stylebox_override("fill",fill)
	monster_hp_bar.add_theme_stylebox_override("background",bg)
	title.add_child(monster_hp_bar)
	# The source has a transparent round opening; keep raft labels behind it.
	var round_backing := Panel.new()
	round_backing.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(round_backing)
	round_backing.anchor_left = 0.14; round_backing.anchor_right = 0.86
	round_backing.anchor_top = 0.285; round_backing.anchor_bottom = 0.87
	var round_style := StyleBoxFlat.new()
	round_style.bg_color = Color("081725")
	round_style.set_corner_radius_all(256)
	round_backing.add_theme_stylebox_override("panel", round_style)
	var portrait := content_area(parent, Vector4(0.16,0.31,0.84,0.79))
	var image := TextureRect.new()
	image.name = "MonsterPortrait"
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = assets.texture("enemy." + enemy_id)
	image.mouse_filter = MOUSE_FILTER_IGNORE
	portrait.add_child(image)
	var shield_area := content_area(parent, Vector4(0.28,0.80,0.72,0.86))
	monster_shield_label = W.text(shield_area, "", 15, Color("79b7dd"))
	monster_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.tooltip_text = str(enemy.get("description", ""))

func build_action_preview_panel(parent: Control, preview_parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal=SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)

	# --- TOP HALF: Monster Action & Intent ---
	var top_box := VBoxContainer.new()
	top_box.size_flags_vertical = SIZE_EXPAND_FILL
	top_box.add_theme_constant_override("separation", 6)
	vbox.add_child(top_box)

	var top_header := HBoxContainer.new()
	top_header.add_theme_constant_override("separation", 8)
	var top_spacer := Control.new(); top_spacer.custom_minimum_size.x = 52
	top_header.add_child(top_spacer)
	top_box.add_child(top_header)
	W.text(top_header, "敌方行动 · 威胁预告", 16, Color("e0a58a"))

	var intent_frame := PanelContainer.new()
	intent_frame.size_flags_vertical = SIZE_EXPAND_FILL
	intent_frame.size_flags_horizontal = SIZE_EXPAND_FILL
	var if_style := StyleBoxFlat.new()
	if_style.bg_color = Color.TRANSPARENT
	if_style.border_color = Color("5a322c")
	if_style.set_border_width_all(0)
	if_style.set_corner_radius_all(3)
	if_style.content_margin_left = 0; if_style.content_margin_right = 0
	if_style.content_margin_top = 8; if_style.content_margin_bottom = 8
	intent_frame.add_theme_stylebox_override("panel", if_style)
	scrollable_content(top_box,"MobileIntentScroll").add_child(intent_frame)

	var enemy_id: String = str(context.battle.get("id", "biter"))
	var enemy: Dictionary = preload("res://core/difficulty_rules.gd").enemy(catalog,context,enemy_id)
	var intent: Dictionary = context.battle.get("intent", {})
	var intent_lines: PackedStringArray = []
	
	if intent.get("type","") == "biter_bite":
		var cell_id: String = str(context.battle.get("raft_target_cell", intent.get("target_cell","")))
		var cell: Dictionary = {}
		for c in context.get("cells", []):
			if c.id == cell_id: cell = c; break
		var loc_str := "无可攻击的外围筏格" if cell.is_empty() else "筏格 %d,%d" % [int(cell.x)+1, int(cell.y)+1]
		intent_lines.append("【破坏预告】啃咬锁定：%s（将造成 1 点结构损耗）" % loc_str)
	var direct_dmg: int = int(context.battle.get("enemy_direct_damage",enemy.get("damage", 3)))
	intent_lines.append("【直接攻击】意图对玩家造成 %d 点伤害（可通过护盾格挡）" % direct_dmg)
	
	if enemy.get("buff","") == "poisoned":
		intent_lines.append("【毒刺特性】攻击附带剧毒污染，持续造成伤害")
	if enemy.get("buff","") == "fearful":
		intent_lines.append("【恐惧震慑】削弱玩家的反击攻击力")
	if context.battle.get("poison_until", 0) >= context.battle.get("turn", 1):
		intent_lines.append("【当前异常】玩家处于中毒状态（回合末结算失血）")

	intent_label = W.text(intent_frame, "\n".join(intent_lines), 16, Color("eee3cd"))
	intent_label.name = "BattleIntentTarget"
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var preview_vbox_root := VBoxContainer.new()
	preview_vbox_root.size_flags_horizontal=SIZE_EXPAND_FILL
	preview_vbox_root.add_theme_constant_override("separation", 6)
	preview_parent.add_child(preview_vbox_root)

	# --- BOTTOM HALF: Hand Card Combo Preview & Validity ---
	var bot_box := VBoxContainer.new()
	bot_box.size_flags_vertical = SIZE_EXPAND_FILL
	bot_box.add_theme_constant_override("separation", 6)
	preview_vbox_root.add_child(bot_box)

	var bot_header := HBoxContainer.new()
	var bot_spacer := Control.new(); bot_spacer.custom_minimum_size.x = 52
	bot_header.add_child(bot_spacer)
	bot_box.add_child(bot_header)
	var preview_title := W.text(bot_header, "出招 · 效果预览", 16, W.GOLD)
	preview_title.size_flags_horizontal = SIZE_EXPAND_FILL

	var cancel_btn := W.button(bot_header, "重置已选", func(): clear_selection())
	cancel_btn.name = "CancelBattleSelection"
	cancel_btn.custom_minimum_size = Vector2(80, 26)
	cancel_btn.size_flags_horizontal = SIZE_SHRINK_END
	cancel_btn.add_theme_font_size_override("font_size", 13)
	var details_parent: Node = bot_box
	if mobile:
		var details := VBoxContainer.new()
		details.size_flags_horizontal = SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation",6)
		scrollable_content(bot_box,"MobilePreviewScroll").add_child(details)
		details_parent = details

	var battle_buffs: Array = context.get("boost_cards", []).filter(func(buff): return buff.get("id","") in ["power","barrier"])
	if not battle_buffs.is_empty():
		var buff_row := HBoxContainer.new()
		buff_row.add_theme_constant_override("separation", 8)
		details_parent.add_child(buff_row)
		W.text(buff_row, "独立发电机增益", 14, W.GOLD)
		var boost_select := OptionButton.new()
		boost_select.name = "BattleBoostSelect"
		buff_row.add_child(boost_select)
		for buff in battle_buffs:
			var bname: String = str(buff.get("definition",{}).get("name", {"power":"动力强化","barrier":"屏障强化"}.get(buff.id, buff.id)))
			boost_select.add_item(bname)
			boost_select.set_item_metadata(boost_select.item_count-1, str(buff.uid))
			if str(selected_buff_uid) == str(buff.uid): boost_select.select(boost_select.item_count-1)
		boost_select.item_selected.connect(func(index):
			selected_buff_uid = str(boost_select.get_item_metadata(index))
			update_preview(true)
		)

	var preview_frame := PanelContainer.new()
	preview_frame.name = "BattlePreview"
	preview_frame.size_flags_vertical = SIZE_EXPAND_FILL
	var pf_style := StyleBoxFlat.new()
	pf_style.bg_color = Color.TRANSPARENT
	pf_style.border_color = Color("4b5c46")
	pf_style.set_border_width_all(0)
	pf_style.set_corner_radius_all(3)
	pf_style.content_margin_left = 0; pf_style.content_margin_right = 0
	pf_style.content_margin_top = 4 if mobile else 8; pf_style.content_margin_bottom = 4 if mobile else 8
	preview_frame.add_theme_stylebox_override("panel", pf_style)
	details_parent.add_child(preview_frame)

	var preview_vbox := VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 4)
	preview_frame.add_child(preview_vbox)

	preview_summary_label = W.text(preview_vbox, "请从下方手牌中点击选择「攻击」或「防御」卡牌出招；也可额外选择材料卡组合增强招式。", 16, Color("9ab0be"))
	preview_summary_label.name = "BattlePreviewSummary"
	preview_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	preview_detail_label = W.text(preview_vbox, "", 15, Color("ddcaa2"))
	preview_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func build_combat_log_panel(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)

	# 1. Top bar: Turn number & Player shields
	var header := PanelContainer.new()
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color.TRANSPARENT
	h_style.border_color = Color("48758e")
	h_style.set_border_width_all(0)
	h_style.set_corner_radius_all(3)
	h_style.content_margin_left = 12; h_style.content_margin_right = 12
	h_style.content_margin_top = 6; h_style.content_margin_bottom = 6
	header.add_theme_stylebox_override("panel", h_style)
	vbox.add_child(header)

	var h_row := HBoxContainer.new()
	header.add_child(h_row)

	var hourglass_spacer := Control.new(); hourglass_spacer.custom_minimum_size.x = 32
	h_row.add_child(hourglass_spacer)
	turn_label = W.text(h_row, "第 %d 回合" % int(context.battle.get("turn", 1)), 21, W.GOLD)
	turn_label.size_flags_horizontal = SIZE_EXPAND_FILL

	# 2. Main Body: Combat Log
	var log_header := HBoxContainer.new()
	vbox.add_child(log_header)
	W.text(log_header, "战斗记录", 14, W.MUTED)

	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = SIZE_EXPAND_FILL
	var lp_style := StyleBoxFlat.new()
	lp_style.bg_color = Color(0.015,0.03,0.045,0.35)
	lp_style.border_color = Color("2d4857")
	lp_style.set_border_width_all(0)
	lp_style.set_corner_radius_all(3)
	lp_style.content_margin_left = 8; lp_style.content_margin_right = 8
	lp_style.content_margin_top = 6; lp_style.content_margin_bottom = 6
	log_panel.add_theme_stylebox_override("panel", lp_style)
	vbox.add_child(log_panel)

	log_scroll = ScrollContainer.new()
	log_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	log_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	log_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	log_panel.add_child(log_scroll)

	log_box = VBoxContainer.new()
	log_box.size_flags_horizontal = SIZE_EXPAND_FILL
	log_box.add_theme_constant_override("separation", 4)
	log_scroll.add_child(log_box)

	populate_combat_logs()

	# 3. Bottom bar: 2 Buttons: Skip Turn (battle_end) & Abandon / Retreat
	var btn_row: BoxContainer = VBoxContainer.new() if mobile else HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var skip_btn := W.button(btn_row, "跳过当前回合", func(): hud.send("battle_end"))
	skip_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	skip_btn.custom_minimum_size.y = 34
	skip_btn.add_theme_font_size_override("font_size", 14)
	skip_btn.name = "BattleSkipTurn"
	W.primary(skip_btn)

	var can_retreat: bool = int(context.battle.get("turn", 1)) >= 2 and not context.get("scene", {}).get("combat", false)
	var retreat_btn := W.button(btn_row, "放弃战斗", func(): hud.send("retreat"), not can_retreat, "第二回合起可撤退" if not can_retreat else "")
	retreat_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	retreat_btn.custom_minimum_size.y = 34
	retreat_btn.add_theme_font_size_override("font_size", 14)
	retreat_btn.name = "BattleRetreat"

func populate_combat_logs() -> void:
	for child in log_box.get_children():
		child.queue_free()
	
	var raw_logs: Array = context.get("logs", [])
	var enemy_id: String = str(context.battle.get("id", "biter"))
	var enemy_name: String = str(preload("res://core/difficulty_rules.gd").enemy(catalog,context,enemy_id).get("name", "敌人"))
	
	# Find start index of current combat encounter
	var start_idx := -1
	for i in range(raw_logs.size() - 1, -1, -1):
		var entry_str: String = str(raw_logs[i])
		if entry_str.contains("迎战"):
			start_idx = i
			break
	
	var recent_logs: Array = []
	if start_idx >= 0:
		for i in range(start_idx, raw_logs.size()):
			var text: String = str(raw_logs[i])
			if is_combat_log(text):
				recent_logs.append(clean_log_text(text))
	else:
		# Fallback: strictly include only combat-related logs
		for l in raw_logs:
			var text: String = str(l)
			if is_combat_log(text):
				recent_logs.append(clean_log_text(text))
	
	if recent_logs.is_empty():
		recent_logs.append("迎战 " + enemy_name + "，战斗开始。")
		recent_logs.append("第 %d 回合开始，当前战斗 AP：%d" % [int(context.battle.get("turn", 1)), int(context.battle.get("ap", 0))])

	for item in recent_logs:
		var col: Color = Color("eee3cd")
		if item.contains("攻击") or item.contains("伤害"): col = Color("e0a58a")
		elif item.contains("格挡") or item.contains("护盾"): col = Color("8bc7e5")
		elif item.contains("胜利"): col = W.GOLD
		elif item.contains("迎战") or item.contains("回合"): col = Color("c4a24d")
		var lbl := W.text(log_box, "• " + item, 14, col)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Scroll to bottom
	call_deferred("_scroll_logs_bottom")

func is_combat_log(text: String) -> bool:
	if text.contains("制造") or text.contains("安装") or text.contains("生产") or text.contains("打捞") \
		or text.contains("出发") or text.contains("航行") or text.contains("饱食") or text.contains("水分") \
		or text.contains("老化") or text.contains("夜间"):
		return false
	if text.contains("迎战") or text.contains("执行攻击") or text.contains("执行格挡") \
		or text.contains("战斗") or text.contains("受击") or text.contains("撤退") \
		or text.contains("使用") or text.contains("咬击") or text.contains("毒刺") \
		or text.contains("反击"):
		return true
	return false

func clean_log_text(text: String) -> String:
	var idx := text.find(" · ")
	if idx != -1:
		return text.substr(idx + 3)
	return text

func _scroll_logs_bottom() -> void:
	if is_instance_valid(log_scroll):
		log_scroll.scroll_vertical = 99999

func on_card_clicked(card: Dictionary) -> void:
	var uid: String = str(card.get("uid", ""))
	var kind: String = str(card.get("definition", {}).get("kind", ""))
	var id: String = str(card.get("id", ""))
	var act_id: String = str(card.get("action_id", ""))
	
	if uid == "virtual_action_attack" or id == "action_attack" or act_id == "attack":
		if selected_action == "attack": selected_action = ""
		else:
			selected_action = "attack"
			selected_card_uid = ""
	elif uid == "virtual_action_block" or id == "action_block" or act_id == "block":
		if selected_action == "block": selected_action = ""
		else:
			selected_action = "block"
			selected_card_uid = ""
	elif kind == "resource" or id in RESOURCES:
		var stack_uids: Array = card.get("stack_uids", [uid])
		if selected_resource_uid in stack_uids:
			selected_resource_uid = ""
		else:
			selected_resource_uid = uid
			selected_card_uid = ""
	elif kind in ["combat", "survival"]:
		if selected_card_uid == uid: selected_card_uid = ""
		else:
			selected_card_uid = uid
			selected_action = ""
			selected_resource_uid = ""
	
	sync_selection_to_hud()
	update_preview(true)

func sync_selection_to_hud() -> void:
	if not is_inside_tree(): return
	var raised_uids: Array = []
	if selected_action == "attack": raised_uids.append("virtual_action_attack")
	if selected_action == "block": raised_uids.append("virtual_action_block")
	if selected_resource_uid != "": raised_uids.append(selected_resource_uid)
	if selected_card_uid != "": raised_uids.append(selected_card_uid)
	
	var fan = null
	if is_instance_valid(hud):
		fan = hud.find_child("hand_fan", true, false)
		if fan == null:
			for f in hud.find_children("*", "", true, false):
				if f.has_method("set_selected_uids"): fan = f; break
	if is_instance_valid(fan) and fan.has_method("set_selected_uids"):
		fan.set_selected_uids(raised_uids)

func update_preview(dispatch_to_app: bool = false) -> void:
	var cur_ap: int = int(context.battle.get("ap", 0))
	var is_valid := false
	var preview_data: Dictionary = {}
	var title_text := ""
	var detail_text := ""

	if selected_card_uid != "":
		# Tactial card play
		var card_def: Dictionary = {}
		for c in context.get("hand", []):
			if str(c.uid) == selected_card_uid: card_def = c.definition; break
		var cost: int = int(card_def.get("cost", 1))
		title_text = "打出战术手牌 · %s (消耗 %d AP)" % [card_def.get("name", "战术牌"), cost]
		var args: Dictionary = {"uid": selected_card_uid}
		if selected_buff_uid != "": args["buff_uid"] = selected_buff_uid
		preview_data = Battle.preview(session, args)
		if cost > cur_ap:
			title_text = "【AP不足】需要 %d 战斗AP（当前剩余 %d 点）" % [cost, cur_ap]
			detail_text = "无法出牌。可点击卡牌取消选择，或点击右侧「跳过当前回合」。"
			is_valid = false
		elif preview_data.get("valid", false):
			is_valid = true
			detail_text = format_preview_effects(preview_data)
		else:
			is_valid = false
			detail_text = "无法执行：%s" % preview_data.get("error", "无效组合")
	elif selected_action != "":
		var action_name_str := "基础攻击" if selected_action == "attack" else "基础防御"
		var res_name := ""
		var res_id := ""
		if selected_resource_uid != "":
			for c in context.get("hand", []):
				if str(c.uid) == selected_resource_uid:
					res_name = catalog.entry("cards", c.id).name
					res_id = c.id
					break
		
		if cur_ap < 1:
			title_text = "【AP不足】需要 1 战斗AP（当前剩余 0 点）"
			detail_text = "无法出牌。可点击卡牌取消选择，或点击右侧「跳过当前回合」。"
			is_valid = false
		elif res_id != "" and (not Battle.COMBO.has(res_id) or not Battle.COMBO[res_id].has(selected_action)):
			title_text = "【无效组合】材料与行动不匹配"
			detail_text = "「%s」无法与「%s」组合出招！请更换其它资源或取消该资源。" % [res_name, "攻击" if selected_action=="attack" else "防御"]
			is_valid = false
		else:
			var args: Dictionary = {"action": selected_action}
			if selected_resource_uid != "": args["resource_uid"] = selected_resource_uid
			if selected_buff_uid != "": args["buff_uid"] = selected_buff_uid
			preview_data = Battle.preview(session, args)
			if preview_data.get("valid", false):
				is_valid = true
				var combo_title := action_name_str
				if res_name != "":
					combo_title = "%s · 附加 %s" % [action_name_str, res_name]
				title_text = "拟出招：%s (消耗 1 AP%s)" % [combo_title, " + 1 " + res_name if res_name!="" else ""]
				detail_text = format_preview_effects(preview_data)
			else:
				is_valid = false
				title_text = "【无效组合】"
				detail_text = "无法执行：%s" % preview_data.get("error", "组合不合法")
	elif selected_resource_uid != "":
		var res_name := ""
		for c in context.get("hand", []):
			if str(c.uid) == selected_resource_uid: res_name = catalog.entry("cards", c.id).name; break
		title_text = "【未完成组合】已选择材料：「%s」" % res_name
		detail_text = "请继续点击右侧最下方的「攻击」或「防御」卡牌组合出招！"
		is_valid = false
	else:
		title_text = "从下方手牌选择「攻击」或「防御」。"
		detail_text = "可附加材料卡，增强攻击、护盾或施加异常。"
		if context.get("mode","")=="tutorial":
			var lesson_id: String=str(context.get("tutorial_hint",{}).get("id",""))
			if lesson_id in ["attack2a","attack2b"]:
				title_text="当前教学：使用手牌『矛击』。"
				detail_text="按住0.05秒，向上拖出手牌区松开；滑回取消。" if mobile else "双击『矛击』，消耗1战斗AP，造成3点伤害。"
			elif lesson_id=="endturn2":
				title_text="攻击已完成，请结束当前回合。"
				detail_text="点右侧『跳过当前回合』，观察敌人反击。"
		is_valid = false

	# Update UI text
	if is_instance_valid(preview_summary_label):
		preview_summary_label.text = title_text
		if not is_valid and (selected_action != "" or selected_resource_uid != "" or selected_card_uid != ""):
			preview_summary_label.add_theme_color_override("font_color", Color("df8b80"))
		elif is_valid:
			preview_summary_label.add_theme_color_override("font_color", W.GOLD)
		else:
			preview_summary_label.add_theme_color_override("font_color", Color("9ab0be"))
	
	if is_instance_valid(preview_detail_label):
		preview_detail_label.text = detail_text
		preview_detail_label.visible = detail_text != ""

	# Sync ui_state.battle_selection for tests and session
	var record := {}
	if selected_action != "": record["action"] = selected_action
	if selected_resource_uid != "": record["resource_uid"] = selected_resource_uid
	if selected_buff_uid != "": record["buff_uid"] = selected_buff_uid
	if selected_card_uid != "":
		record["card_uid"] = selected_card_uid
		var play_args: Dictionary = {"uid": selected_card_uid}
		if selected_buff_uid != "": play_args["buff_uid"] = selected_buff_uid
		record["play_args"] = play_args
	record["preview"] = preview_data
	
	var json_str := JSON.stringify(record) if not record.is_empty() else ""
	if context.has("ui_state"):
		context.ui_state["battle_selection"] = json_str
	if dispatch_to_app and is_instance_valid(hud):
		hud.request("battle_selection", json_str)

	# Update the big confirmation button
	update_confirm_button(is_valid)

func format_preview_effects(preview_data: Dictionary) -> String:
	var after_battle: Dictionary = preview_data.get("battle", {})
	var after_player: Dictionary = preview_data.get("player", {})
	var cur_battle: Dictionary = context.get("battle", {})
	
	var parts: PackedStringArray = []
	var dmg: int = int(cur_battle.get("hp", 0)) - int(after_battle.get("hp", 0))
	if dmg > 0: parts.append("对敌方造成 %d 点伤害" % dmg)
	
	var total_shield := 0; var this_turn := 0; var next_turn := 0
	for s in after_battle.get("shields", []):
		var amt := int(s.get("amount", 0)); total_shield += amt
		if int(s.get("expires_turn", 0)) <= int(after_battle.get("turn", 1)): this_turn += amt
		else: next_turn += amt
	var old_shields: int = cur_battle.get("shields", []).size()
	if total_shield > 0 and after_battle.get("shields",[]).size() > old_shields:
		parts.append("获得护盾（总计 %d 点 · 本轮%d · 下轮%d）" % [total_shield, this_turn, next_turn])
	
	if after_battle.get("bound_effect", false) and not cur_battle.get("bound_effect", false):
		var enemy_id: String = str(cur_battle.get("id", ""))
		parts.append("束缚敌方（取消啃咬/毒刺效果）" if enemy_id == "biter" else "束缚生效")
	
	if after_battle.get("counter_ready", false) and not cur_battle.get("counter_ready", false):
		parts.append("获得反击就绪（受击反击 1 点）")
	
	if int(after_battle.get("enemy_damage_delta", 0)) < int(cur_battle.get("enemy_damage_delta", 0)):
		parts.append("削弱敌方下次伤害 %d 点" % absi(int(after_battle.get("enemy_damage_delta", 0))))
	
	if int(cur_battle.get("poison_until", 0)) >= int(cur_battle.get("turn", 1)) and int(after_battle.get("poison_until", 0)) < int(cur_battle.get("turn", 1)):
		parts.append("清除中毒状态")
		
	return "预计效果：" + (" · ".join(parts) if not parts.is_empty() else "施展基础行动")

func update_confirm_button(is_valid: bool) -> void:
	if not is_instance_valid(confirm_button):
		confirm_button = hud.find_child("CraftEntry", true, false)
		if confirm_button == null:
			confirm_button = hud.find_child("ConfirmBattleAction", true, false)
	
	if is_instance_valid(confirm_button):
		confirm_button.name = "ConfirmBattleAction"
		confirm_button.text = "迎击"
		confirm_button.disabled = not is_valid
		if is_valid:
			confirm_button.add_theme_color_override("font_color", Color("fff8e9"))
		else:
			confirm_button.add_theme_color_override("font_color", Color("8a9da8"))

func on_action_double_clicked(card: Dictionary) -> void:
	var act_id: String = str(card.get("action_id", ""))
	if act_id == "":
		if str(card.get("uid", "")) == "virtual_action_attack" or str(card.get("id", "")) == "action_attack":
			act_id = "attack"
		elif str(card.get("uid", "")) == "virtual_action_block" or str(card.get("id", "")) == "action_block":
			act_id = "block"
	if act_id == "attack" or act_id == "block":
		selected_action = act_id
		selected_card_uid = ""
		sync_selection_to_hud()
		update_preview(false)
		
		var cur_ap: int = int(context.battle.get("ap", 0))
		if cur_ap < 1:
			flash_invalid_feedback("战斗AP不足（当前为 0 点），无法迎击！")
			return
		
		var res_name := ""
		var res_id := ""
		if selected_resource_uid != "":
			for c in context.get("hand", []):
				if str(c.uid) == selected_resource_uid:
					res_name = catalog.entry("cards", c.id).name
					res_id = c.id
					break
		
		if res_id != "" and (not Battle.COMBO.has(res_id) or not Battle.COMBO[res_id].has(selected_action)):
			flash_invalid_feedback("「%s」无法与「%s」组合出招！" % [res_name, "攻击" if selected_action == "attack" else "防御"])
			return
		
		var args: Dictionary = {"action": selected_action}
		if selected_resource_uid != "": args["resource_uid"] = selected_resource_uid
		if selected_buff_uid != "": args["buff_uid"] = selected_buff_uid
		var preview_data: Dictionary = Battle.preview(session, args)
		if not preview_data.get("valid", false):
			var err_msg: String = str(preview_data.get("error", "无效组合"))
			flash_invalid_feedback("无法出招：%s" % err_msg)
			return
		
		confirm_action()
		return

	# Independent playable card (e.g. arrow, spear, survival items)
	var def: Dictionary = card.get("definition", {})
	if def.is_empty() and card.has("id") and is_instance_valid(catalog):
		def = catalog.entry("cards", card.id)
	var kind: String = str(def.get("kind", ""))
	if kind in ["combat", "survival", "negative"] and card.get("id", "") not in ["coin", "corpse"]:
		var cur_ap: int = int(context.battle.get("ap", 0))
		var cost: int = int(def.get("cost", 1))
		if cost > cur_ap:
			flash_invalid_feedback("战斗AP不足（需要 %d 点，当前剩余 %d 点）！" % [cost, cur_ap])
			return
		var args: Dictionary = {"uid": card.uid}
		if selected_buff_uid != "" and kind == "combat":
			args["buff_uid"] = selected_buff_uid
		if is_instance_valid(session):
			var preview_data: Dictionary = Battle.preview(session, args)
			if not preview_data.get("valid", false):
				var err_msg: String = str(preview_data.get("error", "无法出牌"))
				flash_invalid_feedback(err_msg)
				return
		clear_selection()
		hud.send("play", args)
		return

func flash_invalid_feedback(reason: String) -> void:
	if is_instance_valid(preview_summary_label):
		preview_summary_label.text = "【无法出招】" + reason
		preview_summary_label.add_theme_color_override("font_color", Color("ff4d4d"))
	if is_instance_valid(preview_detail_label):
		preview_detail_label.text = "当前组合无效或条件不满足，请调整组合后再试。"
		preview_detail_label.visible = true
	
	var pf = find_child("BattlePreview", true, false)
	if is_instance_valid(pf):
		var tween = create_tween()
		pf.modulate = Color(1.8, 0.45, 0.45, 1.0)
		tween.tween_property(pf, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func confirm_action() -> void:
	var action := selected_action
	var res_uid := selected_resource_uid
	var buff_uid := selected_buff_uid
	var card_uid := selected_card_uid
	clear_selection()
	if action != "":
		var args: Dictionary = {"action": action}
		if res_uid != "": args["resource_uid"] = res_uid
		if buff_uid != "": args["buff_uid"] = buff_uid
		hud.send("battle_action", args)
	elif card_uid != "":
		hud.send("play", {"uid": card_uid})

func clear_selection() -> void:
	selected_action = ""
	selected_resource_uid = ""
	selected_card_uid = ""
	selected_buff_uid = ""
	sync_selection_to_hud()
	update_preview(true)

func restore_saved_selection() -> void:
	var raw: String = str(context.get("ui_state", {}).get("battle_selection", ""))
	if raw.is_empty(): return
	var val = JSON.parse_string(raw)
	if val is Dictionary:
		selected_action = str(val.get("action", ""))
		selected_resource_uid = str(val.get("resource_uid", ""))
		selected_card_uid = str(val.get("card_uid", ""))
		selected_buff_uid = str(val.get("buff_uid", ""))
		sync_selection_to_hud()
