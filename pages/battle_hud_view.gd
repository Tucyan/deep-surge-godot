extends Control
## BattleHUDView: Inlined 3-column combat layout over darkened ocean backdrop.
## Left: Yellow monster panel (name, hp, portrait)
## Center: Red action panel (top: monster intent, bottom: card combo preview & validity)
## Right: Blue combat log & turn control panel (turn, player shields, logs, skip/retreat)

const Battle = preload("res://core/battle_rules.gd")
const W = preload("res://presentation/widgets.gd")
const RESOURCES := ["wood","iron","rope","plastic","cloth"]

var hud: Control
var context: Dictionary
var catalog: RefCounted
var assets: RefCounted
var session: RefCounted

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
	catalog = cat
	assets = art
	session = sess
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	build_ui()

func build_ui() -> void:
	# 1. Full-screen translucent backdrop covering ONLY the raft and ocean
	# Vertically between top plates (y=186) and hand tray topbar (y=616)
	var backdrop := Panel.new()
	backdrop.name = "BattleBackdrop"
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.anchor_left = 0.0; backdrop.anchor_top = 0.0
	backdrop.anchor_right = 1.0; backdrop.anchor_bottom = 0.0
	backdrop.offset_left = 24.0; backdrop.offset_top = 188.0
	backdrop.offset_right = -24.0; backdrop.offset_bottom = 612.0
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.015, 0.038, 0.065, 0.86)
	bg_style.border_color = Color(0.65, 0.57, 0.36, 0.45)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(6)
	backdrop.add_theme_stylebox_override("panel", bg_style)

	var layout_margin := MarginContainer.new()
	layout_margin.name = "ModalSurface"
	layout_margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layout_margin.add_theme_constant_override("margin_left", 14)
	layout_margin.add_theme_constant_override("margin_right", 14)
	layout_margin.add_theme_constant_override("margin_top", 12)
	layout_margin.add_theme_constant_override("margin_bottom", 12)
	backdrop.add_child(layout_margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	layout_margin.add_child(columns)

	# --- COLUMN 1: Yellow Monster Panel (Left, 370px wide) ---
	var yellow_panel := PanelContainer.new()
	yellow_panel.name = "MonsterPanel"
	yellow_panel.custom_minimum_size = Vector2(370, 0)
	yellow_panel.size_flags_horizontal = SIZE_SHRINK_BEGIN
	yellow_panel.size_flags_vertical = SIZE_EXPAND_FILL
	var yellow_style := create_card_box_style(Color("c4a24d"), Color(0.02, 0.04, 0.07, 0.94))
	yellow_panel.add_theme_stylebox_override("panel", yellow_style)
	columns.add_child(yellow_panel)
	build_monster_panel(yellow_panel)

	# --- COLUMN 2: Red Action & Preview Panel (Center, Flex width) ---
	var red_panel := PanelContainer.new()
	red_panel.name = "ActionPreviewPanel"
	red_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	red_panel.size_flags_vertical = SIZE_EXPAND_FILL
	var red_style := create_card_box_style(Color("a25c48"), Color(0.02, 0.04, 0.07, 0.94))
	red_panel.add_theme_stylebox_override("panel", red_style)
	columns.add_child(red_panel)
	build_action_preview_panel(red_panel)

	# --- COLUMN 3: Blue Turn & Log Panel (Right, 380px wide) ---
	var blue_panel := PanelContainer.new()
	blue_panel.name = "CombatLogPanel"
	blue_panel.custom_minimum_size = Vector2(380, 0)
	blue_panel.size_flags_horizontal = SIZE_SHRINK_BEGIN
	blue_panel.size_flags_vertical = SIZE_EXPAND_FILL
	var blue_style := create_card_box_style(Color("48758e"), Color(0.02, 0.04, 0.07, 0.94))
	blue_panel.add_theme_stylebox_override("panel", blue_style)
	columns.add_child(blue_panel)
	build_combat_log_panel(blue_panel)

	# Restore previous selection if present in ui_state
	restore_saved_selection()
	update_preview()

func create_card_box_style(border_col: Color, bg_col: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_color = border_col
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func build_monster_panel(parent: Control) -> void:
	var enemy_id: String = str(context.battle.get("id", "biter"))
	var enemy: Dictionary = catalog.entry("enemies", enemy_id)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)

	# 1. Top bar: Monster name, HP, Shield
	var header := PanelContainer.new()
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color(0.04, 0.08, 0.12, 0.88)
	h_style.border_color = Color("c4a24d")
	h_style.set_border_width_all(1)
	h_style.set_corner_radius_all(3)
	h_style.content_margin_left = 12; h_style.content_margin_right = 12
	h_style.content_margin_top = 6; h_style.content_margin_bottom = 6
	header.add_theme_stylebox_override("panel", h_style)
	vbox.add_child(header)

	var h_vbox := VBoxContainer.new()
	h_vbox.add_theme_constant_override("separation", 4)
	header.add_child(h_vbox)

	var title_row := HBoxContainer.new()
	h_vbox.add_child(title_row)

	var name_lbl := W.text(title_row, enemy.name, 21, W.GOLD)
	name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL

	monster_shield_label = W.text(title_row, "", 16, Color("79b7dd"))

	var cur_hp: int = int(context.battle.get("hp", enemy.hp))
	var max_hp: int = int(enemy.get("hp", cur_hp))
	monster_hp_label = W.text(title_row, "HP %d/%d" % [cur_hp, max_hp], 17, Color("eee3cd"))

	monster_hp_bar = ProgressBar.new()
	monster_hp_bar.custom_minimum_size.y = 8
	monster_hp_bar.show_percentage = false
	monster_hp_bar.min_value = 0.0
	monster_hp_bar.max_value = float(maxi(1, max_hp))
	monster_hp_bar.value = float(cur_hp)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("9c3832"); bar_fill.set_corner_radius_all(2)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("142026"); bar_bg.set_corner_radius_all(2)
	monster_hp_bar.add_theme_stylebox_override("fill", bar_fill)
	monster_hp_bar.add_theme_stylebox_override("background", bar_bg)
	h_vbox.add_child(monster_hp_bar)

	# 2. Main Body: Monster Portrait
	var portrait_container := PanelContainer.new()
	portrait_container.size_flags_vertical = SIZE_EXPAND_FILL
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.015, 0.03, 0.045, 0.75)
	p_style.set_corner_radius_all(3)
	portrait_container.add_theme_stylebox_override("panel", p_style)
	vbox.add_child(portrait_container)

	var tex_rect := TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture = assets.texture("enemy." + enemy_id)
	portrait_container.add_child(tex_rect)

	# Subtle enemy description or tags at bottom
	var tag_row := HBoxContainer.new()
	vbox.add_child(tag_row)
	var desc: String = str(enemy.get("description", ""))
	if desc != "":
		var desc_lbl := W.text(tag_row, desc, 13, W.MUTED)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func build_action_preview_panel(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	parent.add_child(vbox)

	# --- TOP HALF: Monster Action & Intent ---
	var top_box := VBoxContainer.new()
	top_box.size_flags_vertical = SIZE_EXPAND_FILL
	top_box.add_theme_constant_override("separation", 6)
	vbox.add_child(top_box)

	var top_header := HBoxContainer.new()
	top_box.add_child(top_header)
	W.text(top_header, "◆ 敌方当前行动与威胁预告 ◆", 16, Color("e0a58a"))

	var intent_frame := PanelContainer.new()
	intent_frame.size_flags_vertical = SIZE_EXPAND_FILL
	var if_style := StyleBoxFlat.new()
	if_style.bg_color = Color(0.02, 0.04, 0.06, 0.8)
	if_style.border_color = Color("5a322c")
	if_style.set_border_width_all(1)
	if_style.set_corner_radius_all(3)
	if_style.content_margin_left = 12; if_style.content_margin_right = 12
	if_style.content_margin_top = 8; if_style.content_margin_bottom = 8
	intent_frame.add_theme_stylebox_override("panel", if_style)
	top_box.add_child(intent_frame)

	var enemy_id: String = str(context.battle.get("id", "biter"))
	var enemy: Dictionary = catalog.entry("enemies", enemy_id)
	var intent: Dictionary = context.battle.get("intent", {})
	var intent_lines: PackedStringArray = []
	
	if intent.get("type","") == "biter_bite":
		var cell_id: String = str(context.battle.get("raft_target_cell", intent.get("target_cell","")))
		var cell: Dictionary = {}
		for c in context.get("cells", []):
			if c.id == cell_id: cell = c; break
		var loc_str := "无可攻击的外围筏格" if cell.is_empty() else "筏格 %d,%d" % [int(cell.x)+1, int(cell.y)+1]
		intent_lines.append("【破坏预告】啃咬锁定：%s（将造成 1 点结构损耗）" % loc_str)
	else:
		var direct_dmg: int = int(enemy.get("damage", 3))
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

	# Divider line
	var div := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color("7a5d3f")
	sep_style.thickness = 1
	div.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(div)

	# --- BOTTOM HALF: Hand Card Combo Preview & Validity ---
	var bot_box := VBoxContainer.new()
	bot_box.size_flags_vertical = SIZE_EXPAND_FILL
	bot_box.add_theme_constant_override("separation", 6)
	vbox.add_child(bot_box)

	var bot_header := HBoxContainer.new()
	bot_box.add_child(bot_header)
	W.text(bot_header, "◆ 选择手牌出招 · 效果预测 ◆", 16, W.GOLD)

	var cancel_btn := W.button(bot_header, "重置已选", func(): clear_selection())
	cancel_btn.name = "CancelBattleSelection"
	cancel_btn.custom_minimum_size = Vector2(80, 26)
	cancel_btn.add_theme_font_size_override("font_size", 13)

	var battle_buffs: Array = context.get("boost_cards", []).filter(func(buff): return buff.get("id","") in ["power","barrier"])
	if not battle_buffs.is_empty():
		var buff_row := HBoxContainer.new()
		buff_row.add_theme_constant_override("separation", 8)
		bot_box.add_child(buff_row)
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
	pf_style.bg_color = Color(0.02, 0.04, 0.06, 0.8)
	pf_style.border_color = Color("4b5c46")
	pf_style.set_border_width_all(1)
	pf_style.set_corner_radius_all(3)
	pf_style.content_margin_left = 12; pf_style.content_margin_right = 12
	pf_style.content_margin_top = 8; pf_style.content_margin_bottom = 8
	preview_frame.add_theme_stylebox_override("panel", pf_style)
	bot_box.add_child(preview_frame)

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
	h_style.bg_color = Color(0.04, 0.08, 0.12, 0.88)
	h_style.border_color = Color("48758e")
	h_style.set_border_width_all(1)
	h_style.set_corner_radius_all(3)
	h_style.content_margin_left = 12; h_style.content_margin_right = 12
	h_style.content_margin_top = 6; h_style.content_margin_bottom = 6
	header.add_theme_stylebox_override("panel", h_style)
	vbox.add_child(header)

	var h_row := HBoxContainer.new()
	header.add_child(h_row)

	turn_label = W.text(h_row, "第 %d 回合" % int(context.battle.get("turn", 1)), 21, W.GOLD)
	turn_label.size_flags_horizontal = SIZE_EXPAND_FILL

	# 2. Main Body: Combat Log
	var log_header := HBoxContainer.new()
	vbox.add_child(log_header)
	W.text(log_header, "战斗记录", 14, W.MUTED)

	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = SIZE_EXPAND_FILL
	var lp_style := StyleBoxFlat.new()
	lp_style.bg_color = Color(0.015, 0.03, 0.045, 0.85)
	lp_style.border_color = Color("2d4857")
	lp_style.set_border_width_all(1)
	lp_style.set_corner_radius_all(3)
	lp_style.content_margin_left = 8; lp_style.content_margin_right = 8
	lp_style.content_margin_top = 6; lp_style.content_margin_bottom = 6
	log_panel.add_theme_stylebox_override("panel", lp_style)
	vbox.add_child(log_panel)

	log_scroll = ScrollContainer.new()
	log_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	log_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	log_panel.add_child(log_scroll)

	log_box = VBoxContainer.new()
	log_box.size_flags_horizontal = SIZE_EXPAND_FILL
	log_box.add_theme_constant_override("separation", 4)
	log_scroll.add_child(log_box)

	populate_combat_logs()

	# 3. Bottom bar: 2 Buttons: Skip Turn (battle_end) & Abandon / Retreat
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var skip_btn := W.button(btn_row, "跳过当前回合", func(): hud.send("battle_end"))
	skip_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	skip_btn.custom_minimum_size.y = 40
	skip_btn.name = "BattleSkipTurn"
	W.primary(skip_btn)

	var can_retreat: bool = int(context.battle.get("turn", 1)) >= 2 and not context.get("scene", {}).get("combat", false)
	var retreat_btn := W.button(btn_row, "放弃战斗", func(): hud.send("retreat"), not can_retreat, "第二回合起可撤退" if not can_retreat else "")
	retreat_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	retreat_btn.custom_minimum_size.y = 40
	retreat_btn.name = "BattleRetreat"

func populate_combat_logs() -> void:
	for child in log_box.get_children():
		child.queue_free()
	
	var raw_logs: Array = context.get("logs", [])
	var enemy_id: String = str(context.battle.get("id", "biter"))
	var enemy_name: String = str(catalog.entry("enemies", enemy_id).get("name", "敌人"))
	
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
		title_text = "请从下方手牌中点击选择「攻击」或「防御」卡牌出招。"
		detail_text = "可额外选择木头、废铁、绳索等材料卡组合增强攻击力、护盾或施加异常。"
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
