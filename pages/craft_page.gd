extends "res://pages/flow_base.gd"
const PAGE_SIZE := 8
const READY := Color("8dd6b6")
const MISSING := Color("df968b")

class FusionDiagram extends Container:
	var slot1: PanelContainer
	var slot2: PanelContainer
	var slot3: PanelContainer
	var center_box: PanelContainer
	var is_active: bool = false

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			_update_layout()
			queue_redraw()

	func _update_layout() -> void:
		if not is_instance_valid(slot1) or not is_instance_valid(center_box): return
		var w := size.x if size.x > 20.0 else 460.0
		var h := size.y if size.y > 20.0 else 300.0
		
		# Input slots (Top, Bottom-Left, Bottom-Right)
		var sw := minf(130.0, w * 0.28)
		var sh := 62.0
		fit_child_in_rect(slot1, Rect2(Vector2(w * 0.50 - sw * 0.5, h * 0.16 - sh * 0.5), Vector2(sw, sh)))
		fit_child_in_rect(slot2, Rect2(Vector2(w * 0.18 - sw * 0.5, h * 0.84 - sh * 0.5), Vector2(sw, sh)))
		fit_child_in_rect(slot3, Rect2(Vector2(w * 0.82 - sw * 0.5, h * 0.84 - sh * 0.5), Vector2(sw, sh)))
		
		# Center output slot (middle)
		var cw := minf(164.0, w * 0.36)
		var ch := 88.0
		fit_child_in_rect(center_box, Rect2(Vector2((w - cw) * 0.5, h * 0.50 - ch * 0.5), Vector2(cw, ch)))

	func _draw() -> void:
		if not is_instance_valid(slot1) or not is_instance_valid(center_box): return
		var c := center_box.position + center_box.size * 0.5
		var p1 := slot1.position + slot1.size * 0.5
		var p2 := slot2.position + slot2.size * 0.5
		var p3 := slot3.position + slot3.size * 0.5
		
		var col_line := Color("47796f") if is_active else Color("253e48")
		var col_inner := Color("8dd6b6") if is_active else Color("3a6369")
		
		var points: Array[Vector2] = [p1, p2, p3]
		for p in points:
			draw_line(p, c, col_line, 4.0, true)
			draw_line(p, c, col_inner, 2.0, true)
			var dir: Vector2 = (c - p).normalized()
			var mid: Vector2 = p + (c - p) * 0.60
			var perp: Vector2 = Vector2(-dir.y, dir.x) * 6.0
			draw_line(mid - dir * 8.0 + perp, mid, col_inner, 2.0, true)
			draw_line(mid - dir * 8.0 - perp, mid, col_inner, 2.0, true)

func box_style(background: Color, border: Color, margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background; style.border_color = border
	style.set_border_width_all(1); style.set_corner_radius_all(7)
	style.content_margin_left = margin; style.content_margin_right = margin
	style.content_margin_top = margin; style.content_margin_bottom = margin
	return style

func badge(parent: Node, text: String, color: Color) -> void:
	var panel := PanelContainer.new(); parent.add_child(panel)
	panel.add_theme_stylebox_override("panel", box_style(Color("172d35"), Color("33565b"), 5))
	var label := W.text(panel, text, 15, color); label.autowrap_mode = TextServer.AUTOWRAP_OFF

func build() -> void:
	add_theme_constant_override("separation", 10)
	var tab: String = context.ui_state.get("craft_tab", "craft")
	if tab not in ["craft", "transmute"]: tab = "craft"
	
	# Top bar with title and tabs
	var header := HBoxContainer.new(); header.name = "CraftHeader"; add_child(header)
	header.add_theme_constant_override("separation", 16)
	header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.custom_minimum_size.y = 40
	
	var title_lbl := W.text(header, "工具台", 27, W.INK)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_lbl.custom_minimum_size.x = 90
	
	var tab_row := HBoxContainer.new(); header.add_child(tab_row)
	tab_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tab_row.add_theme_constant_override("separation", 8)
	var craft_tab_btn := W.button(tab_row, "配方合成", func(): request("craft_tab", "craft"))
	craft_tab_btn.name = "CraftTabButton"
	craft_tab_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var transmute_tab_btn := W.button(tab_row, "资源转化", func(): request("craft_tab", "transmute"))
	transmute_tab_btn.name = "TransmuteTabButton"
	transmute_tab_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for btn in [craft_tab_btn, transmute_tab_btn]:
		btn.custom_minimum_size = Vector2(110, 36)
	var active_tab_btn: Button = craft_tab_btn if tab == "craft" else transmute_tab_btn
	active_tab_btn.add_theme_color_override("font_color", W.GOLD)
	
	# Spacer pushes tabs to the left and prevents header content from reaching the top-right corner
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	
	# Dedicated reservation for CloseX button
	var close_spacer := Control.new()
	close_spacer.custom_minimum_size = Vector2(64, 36)
	close_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(close_spacer)
	
	if tab == "craft":
		# Material inventory bar for recipe craft
		var inventory := PanelContainer.new(); inventory.name = "CraftInventory"; add_child(inventory)
		inventory.add_theme_stylebox_override("panel", box_style(Color("0c1d26"), Color("2c4652"), 8))
		var stock := HBoxContainer.new(); inventory.add_child(stock)
		W.text(stock, "材料库存", 18, W.GOLD).autowrap_mode = TextServer.AUTOWRAP_OFF
		badge(stock, "当前 AP: %d" % context.ap, READY)
		for id in ["wood", "iron", "plastic", "cloth", "rope"]:
			badge(stock, "%s %d" % [catalog.entry("cards", id).name, amount(id)], W.INK if amount(id) > 0 else W.MUTED)
		if amount("corpse") > 0:
			badge(stock, "%s %d" % [catalog.entry("cards", "corpse").name, amount("corpse")], W.INK)
		
		build_recipe_grid()
	else:
		build_transmute_panel()

func build_recipe_grid() -> void:
	var page_size: int = PAGE_SIZE
	var ids: Array = catalog.table("recipes").keys()
	var pages := maxi(1, ceili(float(ids.size()) / page_size))
	var index := clampi(int(context.ui_state.get("list_page", 0)), 0, pages - 1)
	var grid := GridContainer.new(); grid.name = "RecipeGrid"; grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	for id in ids.slice(index * page_size, mini(ids.size(), (index + 1) * page_size)): recipe_tile(grid, id)
	var footer := HBoxContainer.new(); add_child(footer)
	W.text(footer, "合成消耗 AP；设备安装不消耗 AP。", 15, W.MUTED)
	var previous := W.button(footer, "上一页", func(): request("list_page", str(index - 1)), index == 0); previous.name = "CraftRecipePreviousPage"
	W.counter(footer, "%d / %d" % [index + 1, pages])
	var next := W.button(footer, "下一页", func(): request("list_page", str(index + 1)), index == pages - 1); next.name = "CraftRecipeNextPage"

func recipe_tile(grid: Node, id: String) -> void:
	var recipe: Dictionary = catalog.entry("recipes", id)
	var output: Dictionary = catalog.entry("cards", recipe.output)
	var reason := ""
	for material in recipe.ingredients:
		if amount(material) < recipe.ingredients[material]: reason = "缺少材料"
	if context.ap < recipe.cost: reason = "AP 不足"
	if id == "spearRack" and "spear" not in context.profile.tech: reason = "需解锁科技"
	if context.get("tutorial_operation", "") not in ["", "craft"]:
		reason = "先完成教学操作"
	elif context.get("tutorial_operation", "") == "craft" and id != "filter":
		reason = "教学需先合成滤水器"
	if not context.can_base: reason = "当前阶段不可合成"
	var tile := PanelContainer.new(); tile.set_meta("recipe_id", id)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", box_style(Color("192f37"), Color("47796f") if reason == "" else Color("2c424b")))
	grid.add_child(tile)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 8); tile.add_child(column)
	var title := HBoxContainer.new(); column.add_child(title)
	W.text(title, output.name, 22, W.INK)
	badge(title, "%d AP" % recipe.cost, W.GOLD)
	var description := W.text(column, output.description, 17, W.MUTED)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var materials := HFlowContainer.new(); column.add_child(materials)
	materials.add_theme_constant_override("h_separation", 5); materials.add_theme_constant_override("v_separation", 5)
	for material in recipe.ingredients:
		var owned: int = amount(material); var needed: int = recipe.ingredients[material]
		badge(materials, "%s %d/%d" % [catalog.entry("cards", material).name, owned, needed], READY if owned >= needed else MISSING)
	var button := W.button(column, "合成" if reason == "" else reason, func(): send("craft", {"id": id}), reason != "", reason)
	button.name = "CraftRecipeButton"; button.set_meta("recipe_id", id)
	button.custom_minimum_size.y = 42; button.accessibility_name = recipe.name + " · %d AP" % recipe.cost
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, box_style(Color("32685e") if state == "normal" else Color("44897b"), Color("64a995"), 7))

func _create_material_icon(id: String, icon_size: Vector2 = Vector2(32, 32)) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = icon_size
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a171f")
	style.border_color = Color("28434e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 2; style.content_margin_right = 2
	style.content_margin_top = 2; style.content_margin_bottom = 2
	frame.add_theme_stylebox_override("panel", style)
	
	if id != "" and id != "none":
		var tex_rect := TextureRect.new()
		tex_rect.texture = assets.texture("card." + id)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = icon_size - Vector2(4, 4)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		frame.add_child(tex_rect)
		if assets.show_label("card." + id):
			var center := CenterContainer.new()
			center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			center.mouse_filter = Control.MOUSE_FILTER_PASS
			tex_rect.add_child(center)
			var sub_lbl := W.text(center, assets.label("card." + id).substr(0, 1), 14, W.GOLD)
			sub_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			sub_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		var q_lbl := W.text(frame, "?", 16, Color("3a5563"))
		q_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	return frame

func build_transmute_panel() -> void:
	var container := VBoxContainer.new(); container.name = "TransmutePanel"
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL; container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 10)
	add_child(container)
	
	# Current target
	var current_target: String = context.ui_state.get("transmute_target", "wood")
	if current_target not in ["wood", "iron", "plastic", "rope", "cloth"]: current_target = "wood"
	var target_def: Dictionary = catalog.entry("cards", current_target)
	
	# All available resource cards in hand
	var resource_cards: Array = context.hand.filter(func(c): return not c.temporary and catalog.entry("cards", c.id).kind == "resource")
	var total_resources: int = resource_cards.size()
	
	# Batch count calculation
	var max_by_res: int = total_resources / 3
	var max_by_ap: int = context.ap
	var max_batches: int = maxi(1, mini(max_by_ap, max_by_res))
	var count: int = maxi(1, int(context.ui_state.get("transmute_count", 1)))
	if max_batches > 0 and count > max_batches:
		count = max_batches
	var needed: int = count * 3
	
	# Selected input UIDs
	var raw_uids: String = context.ui_state.get("transmute_uids", "")
	var selected_uids: Array = []
	if raw_uids == "none":
		selected_uids = []
	elif raw_uids != "":
		for uid in raw_uids.split(","):
			if uid != "" and resource_cards.any(func(c): return c.uid == uid) and uid not in selected_uids:
				selected_uids.append(uid)
	
	if raw_uids == "":
		var non_target: Array = resource_cards.filter(func(c): return c.id != current_target)
		var same_target: Array = resource_cards.filter(func(c): return c.id == current_target)
		var candidates: Array = non_target + same_target
		selected_uids = candidates.slice(0, mini(needed, candidates.size())).map(func(c): return c.uid)
	
	# Top tip banner
	var tip_bar := HBoxContainer.new(); container.add_child(tip_bar)
	tip_bar.add_theme_constant_override("separation", 12)
	W.text(tip_bar, "消耗基地 AP 与手牌中任意 3 张资源牌，转化为指定的 2 张同类资源（支持多批次连续转化）。", 15, W.MUTED)
	
	# Three-Column Layout Container
	var columns := HBoxContainer.new(); columns.name = "TransmuteColumns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	container.add_child(columns)
	
	# ==========================================
	# LEFT COLUMN: 现有材料 (Existing Materials)
	# ==========================================
	var left_panel := PanelContainer.new(); left_panel.name = "TransmuteInventory"
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.0
	left_panel.custom_minimum_size = Vector2(340, 0)
	left_panel.add_theme_stylebox_override("panel", box_style(Color("0c1d26"), Color("2c4652"), 12))
	columns.add_child(left_panel)
	
	var left_vbox := VBoxContainer.new(); left_panel.add_child(left_vbox)
	left_vbox.add_theme_constant_override("separation", 10)
	
	var left_hdr := HBoxContainer.new(); left_vbox.add_child(left_hdr)
	var left_title := W.text(left_hdr, "现有材料", 20, W.GOLD)
	left_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	left_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge(left_hdr, "AP: %d" % context.ap, READY if context.ap >= count else MISSING)
	badge(left_hdr, "手牌资源: %d" % total_resources, W.INK if total_resources >= needed else MISSING)
	
	# Selection status header
	var sel_hdr := HBoxContainer.new(); left_vbox.add_child(sel_hdr)
	sel_hdr.add_theme_constant_override("separation", 8)
	var sel_title := W.text(sel_hdr, "投入材料配比", 16, W.GOLD)
	sel_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	sel_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge(sel_hdr, "已选 %d / %d 张" % [selected_uids.size(), needed], READY if selected_uids.size() == needed else MISSING)
	
	# Helper buttons row
	var helper_row := HBoxContainer.new(); left_vbox.add_child(helper_row)
	helper_row.add_theme_constant_override("separation", 8)
	var auto_btn := W.button(helper_row, "智能推荐", func(): request("transmute_uids", ""))
	auto_btn.custom_minimum_size = Vector2(90, 30)
	auto_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var clear_btn := W.button(helper_row, "清空选择", func(): request("transmute_uids", "none"))
	clear_btn.custom_minimum_size = Vector2(80, 30)
	clear_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	# Material allocation grid (rectangular cards)
	var mat_list := GridContainer.new(); mat_list.name = "TransmuteMaterialList"
	mat_list.columns = 2
	mat_list.add_theme_constant_override("h_separation", 8)
	mat_list.add_theme_constant_override("v_separation", 8)
	mat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(mat_list)
	
	var all_res_types: Array = ["wood", "iron", "plastic", "rope", "cloth"]
	if amount("corpse") > 0: all_res_types.append("corpse")
	
	for id in all_res_types:
		var def: Dictionary = catalog.entry("cards", id)
		var my_cards: Array = resource_cards.filter(func(c): return c.id == id)
		var my_uids: Array = my_cards.map(func(c): return c.uid)
		var owned: int = my_cards.size()
		var allocated: int = selected_uids.filter(func(uid): return uid in my_uids).size()
		
		var m_panel := PanelContainer.new(); m_panel.name = "MatItem_" + id
		var is_allocated: bool = allocated > 0
		m_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_panel.custom_minimum_size = Vector2(150, 72)
		m_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var can_plus: bool = (allocated < owned) and (selected_uids.size() < needed)
		var plus_reason := ""
		if allocated >= owned: plus_reason = "拥有数量不足"
		elif selected_uids.size() >= needed: plus_reason = "已选满所需原料总数"
		var can_minus: bool = allocated > 0
		
		var normal_style := box_style(
			Color("16313d") if is_allocated else (Color("102028") if owned > 0 else Color("0c171e")),
			Color("5da898") if is_allocated else (Color("2e4956") if owned > 0 else Color("1c2b33")),
			6
		)
		var hover_style := box_style(
			Color("1e3e4d") if is_allocated else (Color("142c38") if owned > 0 else Color("0c171e")),
			Color("8dd6b6") if is_allocated else (Color("4a7487") if owned > 0 else Color("1c2b33")),
			6
		)
		m_panel.add_theme_stylebox_override("panel", normal_style)
		
		if owned > 0:
			m_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_plus else Control.CURSOR_ARROW
			m_panel.mouse_entered.connect(func(): m_panel.add_theme_stylebox_override("panel", hover_style))
			m_panel.mouse_exited.connect(func(): m_panel.add_theme_stylebox_override("panel", normal_style))
			m_panel.tooltip_text = "点击投入 1 张%s（右键撤回）" % def.name if can_plus else plus_reason
		else:
			m_panel.tooltip_text = "暂无此材料"
		
		# Click card body to auto +1 (or right-click to -1)
		m_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if can_plus:
						var next_uids: Array = selected_uids.duplicate()
						for uid in my_uids:
							if uid not in next_uids:
								next_uids.append(uid)
								break
						request("transmute_uids", ",".join(next_uids))
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					if can_minus:
						var next_uids: Array = selected_uids.duplicate()
						for uid in my_uids:
							if uid in next_uids:
								next_uids.erase(uid)
								break
						request("transmute_uids", ",".join(next_uids) if not next_uids.is_empty() else "none")
		)
		
		mat_list.add_child(m_panel)
		
		var card_hbox := HBoxContainer.new()
		card_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
		card_hbox.add_theme_constant_override("separation", 6)
		m_panel.add_child(card_hbox)
		
		# Material Icon
		var mat_icon := _create_material_icon(id, Vector2(34, 34))
		card_hbox.add_child(mat_icon)
		
		# Info VBox
		var info_vbox := VBoxContainer.new()
		info_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		card_hbox.add_child(info_vbox)
		
		# Top Row: Name and Allocation Badge
		var top_row := HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_PASS
		top_row.add_theme_constant_override("separation", 4)
		info_vbox.add_child(top_row)
		
		var name_lbl := W.text(top_row, def.name, 15, W.GOLD if is_allocated else (W.INK if owned > 0 else W.MUTED))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var alloc_badge := PanelContainer.new()
		alloc_badge.name = "MatAllocBadge_" + id
		alloc_badge.mouse_filter = Control.MOUSE_FILTER_PASS
		alloc_badge.custom_minimum_size = Vector2(36, 18)
		alloc_badge.add_theme_stylebox_override("panel", box_style(
			Color("16313d") if is_allocated else Color("0c1a21"),
			Color("47796f") if is_allocated else Color("253842"),
			2
		))
		top_row.add_child(alloc_badge)
		var alloc_lbl := W.text(alloc_badge, str(allocated), 12, READY if allocated > 0 else W.MUTED)
		alloc_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		alloc_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		alloc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Bottom Row: Owned count + Steppers [-] [+]
		var bot_row := HBoxContainer.new()
		bot_row.mouse_filter = Control.MOUSE_FILTER_PASS
		bot_row.add_theme_constant_override("separation", 3)
		info_vbox.add_child(bot_row)
		
		var owned_lbl := W.text(bot_row, "存:%d" % owned, 12, W.MUTED if owned > 0 else Color("5a6d75"))
		owned_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		owned_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		owned_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var minus_m := W.button(bot_row, "-", func():
			var next_uids: Array = selected_uids.duplicate()
			for uid in my_uids:
				if uid in next_uids:
					next_uids.erase(uid)
					break
			request("transmute_uids", ",".join(next_uids) if not next_uids.is_empty() else "none")
		, not can_minus, "未选择投入该材料" if not can_minus else "减少 1 张")
		minus_m.name = "MatMinus_" + id
		minus_m.custom_minimum_size = Vector2(22, 20)
		minus_m.size_flags_horizontal = Control.SIZE_SHRINK_END
		
		var plus_m := W.button(bot_row, "+", func():
			var next_uids: Array = selected_uids.duplicate()
			for uid in my_uids:
				if uid not in next_uids:
					next_uids.append(uid)
					break
			request("transmute_uids", ",".join(next_uids))
		, not can_plus, plus_reason if not can_plus else "投入 1 张")
		plus_m.name = "MatPlus_" + id
		plus_m.custom_minimum_size = Vector2(22, 20)
		plus_m.size_flags_horizontal = Control.SIZE_SHRINK_END
	
	# ==========================================
	# CENTER COLUMN: 三元融合图示 + 开始转化
	# ==========================================
	var center_panel := PanelContainer.new(); center_panel.name = "TransmuteCore"
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_stretch_ratio = 1.4
	center_panel.custom_minimum_size = Vector2(460, 0)
	center_panel.add_theme_stylebox_override("panel", box_style(Color("0c1d26"), Color("2c4652"), 14))
	columns.add_child(center_panel)
	
	var center_vbox := VBoxContainer.new(); center_panel.add_child(center_vbox)
	center_vbox.add_theme_constant_override("separation", 8)
	
	var core_hdr := HBoxContainer.new(); center_vbox.add_child(core_hdr)
	var core_title := W.text(core_hdr, "三元转化核心", 22, W.GOLD)
	core_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	core_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var core_sub := W.text(core_hdr, "3 份原料  ➔  2 份目标产物", 14, W.MUTED)
	core_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	# Reason calculation
	var reason := ""
	if not context.can_base: reason = "当前阶段不可转化"
	elif context.ap < count: reason = "基地 AP 不足 (需 %d AP)" % count
	elif total_resources < needed: reason = "手牌可用资源不足 %d 张" % needed
	elif selected_uids.size() != needed: reason = "请选择正好 %d 张资源牌 (当前 %d 张)" % [needed, selected_uids.size()]
	
	# Fusion Diagram Node
	var diagram := FusionDiagram.new(); diagram.name = "FusionDiagram"
	diagram.custom_minimum_size = Vector2(0, 300)
	diagram.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diagram.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	diagram.clip_contents = true
	diagram.is_active = (reason == "")
	center_vbox.add_child(diagram)
	
	# Diagram slots
	var slot1 := PanelContainer.new(); slot1.name = "DiagramSlot1"; diagram.add_child(slot1)
	var slot2 := PanelContainer.new(); slot2.name = "DiagramSlot2"; diagram.add_child(slot2)
	var slot3 := PanelContainer.new(); slot3.name = "DiagramSlot3"; diagram.add_child(slot3)
	var center_box := PanelContainer.new(); center_box.name = "DiagramOutputSlot"; diagram.add_child(center_box)
	
	diagram.slot1 = slot1; diagram.slot2 = slot2; diagram.slot3 = slot3; diagram.center_box = center_box
	
	# Slot contents
	for s in [slot1, slot2, slot3]:
		s.add_theme_stylebox_override("panel", box_style(Color("13242c"), Color("2c4652"), 6))
	center_box.add_theme_stylebox_override("panel", box_style(Color("162e37"), W.GOLD, 8))
	
	var slot_labels: Array = ["原料 ①", "原料 ②", "原料 ③"]
	var selected_cards: Array = []
	for uid in selected_uids:
		var found = resource_cards.filter(func(c): return c.uid == uid)
		if not found.is_empty():
			var card_id: String = found[0].id
			var entry: Dictionary = catalog.entry("cards", card_id)
			selected_cards.append({"id": card_id, "name": entry.get("name", card_id)})
	
	for i in range(3):
		var s: PanelContainer = [slot1, slot2, slot3][i]
		var s_row := HBoxContainer.new()
		s_row.alignment = BoxContainer.ALIGNMENT_CENTER
		s_row.add_theme_constant_override("separation", 6)
		s.add_child(s_row)
		
		var cur_card_id := ""
		var cur_card_name := ""
		if count == 1:
			if selected_cards.size() > i:
				cur_card_id = selected_cards[i].id
				cur_card_name = selected_cards[i].name
		else:
			var rep_idx := i * count
			if selected_cards.size() > rep_idx:
				cur_card_id = selected_cards[rep_idx].id
				cur_card_name = selected_cards[rep_idx].name
		
		var s_icon = _create_material_icon(cur_card_id, Vector2(28, 28))
		s_row.add_child(s_icon)
		
		var col := VBoxContainer.new(); col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 1)
		s_row.add_child(col)
		var s_lbl := W.text(col, slot_labels[i], 11, W.GOLD)
		s_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var val_str: String = ""
		var is_filled: bool = false
		if count == 1:
			if selected_cards.size() > i:
				val_str = selected_cards[i].name
				is_filled = true
			else:
				val_str = "待选原料"
		else:
			if selected_cards.size() >= (i + 1) * count:
				val_str = (cur_card_name if cur_card_name != "" else "原料") + (" ×%d" % count)
				is_filled = true
			elif selected_cards.size() > i * count:
				val_str = "%d/%d 张" % [selected_cards.size() - i * count, count]
				is_filled = true
			else:
				val_str = "待选原料"
		var val_lbl := W.text(col, val_str, 13, READY if is_filled else W.MUTED)
		val_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Output slot content
	var out_row := HBoxContainer.new()
	out_row.alignment = BoxContainer.ALIGNMENT_CENTER
	out_row.add_theme_constant_override("separation", 8)
	center_box.add_child(out_row)
	
	var out_icon := _create_material_icon(current_target, Vector2(44, 44))
	out_row.add_child(out_icon)
	
	var out_col := VBoxContainer.new(); out_col.alignment = BoxContainer.ALIGNMENT_CENTER
	out_col.add_theme_constant_override("separation", 1)
	out_row.add_child(out_col)
	var out_name := W.text(out_col, target_def.name, 18, W.GOLD)
	out_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	out_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var out_val := W.text(out_col, "+ %d 张" % (count * 2), 16, READY)
	out_val.autowrap_mode = TextServer.AUTOWRAP_OFF
	out_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var out_tag := W.text(out_col, "(目标产物)", 11, W.MUTED)
	out_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	out_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	diagram._update_layout()
	
	# Cost & yield summary banner
	var summary_box := PanelContainer.new(); center_vbox.add_child(summary_box)
	summary_box.add_theme_stylebox_override("panel", box_style(Color("102129"), Color("2c4652"), 8))
	var sum_col := VBoxContainer.new(); summary_box.add_child(sum_col)
	sum_col.add_theme_constant_override("separation", 3)
	W.text(sum_col, "转化汇率：每 3 张任意基础资源 + 1 AP  ➔  2 张 %s" % target_def.name, 14, W.GOLD)
	var sum_status := "当前转化：消耗 %d 张手牌原料 & %d 点 AP  ➔  获得 %d 张 %s" % [needed, count, count * 2, target_def.name]
	W.text(sum_col, sum_status, 14, W.INK if reason == "" else MISSING)
	
	# Core Primary Button: "开始转化"
	var exec_text := "开始转化" if reason == "" else "开始转化 (%s)" % reason
	var exec_btn := W.button(center_vbox, exec_text, func():
		send("transmute", {"target": current_target, "uids": selected_uids, "count": count})
	, reason != "", reason)
	exec_btn.name = "TransmuteExecuteButton"
	exec_btn.custom_minimum_size.y = 48
	for state in ["normal", "hover", "pressed"]:
		exec_btn.add_theme_stylebox_override(state, box_style(
			Color("32685e") if state == "normal" else Color("44897b"),
			Color("64a995"),
			7
		))
	if reason == "":
		exec_btn.add_theme_color_override("font_color", W.GOLD)
	
	# Secondary Auto Button
	var quick_reason := ""
	if not context.can_base: quick_reason = "当前阶段不可转化"
	elif context.ap < count: quick_reason = "AP 不足"
	elif total_resources < needed: quick_reason = "资源不足"
	var quick_btn := W.button(center_vbox, "快捷转化 (系统自动选料并执行)", func():
		send("transmute", {"target": current_target, "count": count})
	, quick_reason != "", quick_reason)
	quick_btn.name = "QuickTransmuteButton"
	quick_btn.custom_minimum_size.y = 36
	
	# ==========================================
	# RIGHT COLUMN: 转化数量 (上) + 目标材料 (下)
	# ==========================================
	var right_vbox := VBoxContainer.new(); right_vbox.name = "TransmuteRightCol"
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.0
	right_vbox.custom_minimum_size = Vector2(340, 0)
	right_vbox.add_theme_constant_override("separation", 10)
	columns.add_child(right_vbox)
	
	# Top Section: 选择转化数量 (Stepper)
	var step_panel := PanelContainer.new(); step_panel.name = "TransmuteCountSection"
	step_panel.add_theme_stylebox_override("panel", box_style(Color("0c1d26"), Color("2c4652"), 10))
	right_vbox.add_child(step_panel)
	var step_vbox := VBoxContainer.new(); step_panel.add_child(step_vbox)
	step_vbox.add_theme_constant_override("separation", 6)
	
	var step_hdr := HBoxContainer.new(); step_vbox.add_child(step_hdr)
	var step_title := W.text(step_hdr, "选择转化数量", 18, W.GOLD)
	step_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	step_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge(step_hdr, "最多 %d 批" % max_batches, READY if max_batches >= count else MISSING)
	
	var step_row := HBoxContainer.new(); step_row.name = "TransmuteStepper"
	step_row.add_theme_constant_override("separation", 8); step_vbox.add_child(step_row)
	
	var minus_btn := W.button(step_row, " - ", func(): request("transmute_count", str(count - 1)), count <= 1, "已是最小数量")
	minus_btn.name = "TransmuteCountMinus"
	minus_btn.custom_minimum_size = Vector2(40, 34)
	minus_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	var count_lbl := W.text(step_row, "%d 批次" % count, 20, W.GOLD)
	count_lbl.name = "TransmuteCountLabel"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var plus_btn := W.button(step_row, " + ", func(): request("transmute_count", str(count + 1)), count >= max_batches, "资源或 AP 不足，无法增加更多批次")
	plus_btn.name = "TransmuteCountPlus"
	plus_btn.custom_minimum_size = Vector2(40, 34)
	plus_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	var max_btn := W.button(step_row, "最大", func(): request("transmute_count", str(max_batches)), count >= max_batches, "已是当前最大可转化批次")
	max_btn.name = "TransmuteCountMax"
	max_btn.custom_minimum_size = Vector2(56, 34)
	max_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	var cost_detail := PanelContainer.new(); step_vbox.add_child(cost_detail)
	cost_detail.add_theme_stylebox_override("panel", box_style(Color("11222b"), Color("243a44"), 6))
	var cd_vbox := VBoxContainer.new(); cost_detail.add_child(cd_vbox)
	cd_vbox.add_theme_constant_override("separation", 3)
	W.text(cd_vbox, "• 消耗原料：%d 张手牌基础资源" % needed, 13, W.MUTED if total_resources >= needed else MISSING)
	W.text(cd_vbox, "• 消耗行动：%d 点基地 AP" % count, 13, W.MUTED if context.ap >= count else MISSING)
	W.text(cd_vbox, "• 转化产出：%d 张 %s" % [count * 2, target_def.name], 13, READY)
	
	# Bottom Section: 选择转化的目标材料
	var target_panel := PanelContainer.new(); target_panel.name = "TransmuteTargetSection"
	target_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	target_panel.add_theme_stylebox_override("panel", box_style(Color("0c1d26"), Color("2c4652"), 10))
	right_vbox.add_child(target_panel)
	var target_vbox := VBoxContainer.new(); target_panel.add_child(target_vbox)
	target_vbox.add_theme_constant_override("separation", 6)
	
	var target_title := W.text(target_vbox, "选择转化的目标材料", 18, W.GOLD)
	target_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	var targets_list := VBoxContainer.new(); targets_list.name = "TransmuteTargets"
	targets_list.add_theme_constant_override("separation", 5); target_vbox.add_child(targets_list)
	
	for id in ["wood", "iron", "plastic", "rope", "cloth"]:
		var def: Dictionary = catalog.entry("cards", id)
		var is_selected: bool = (id == current_target)
		
		var item_panel := PanelContainer.new(); item_panel.name = "TargetItem_" + id
		var t_normal_style := box_style(
			Color("1f404d") if is_selected else Color("13242c"),
			W.GOLD if is_selected else Color("2c4652"),
			6
		)
		var t_hover_style := box_style(
			Color("234b5a") if is_selected else Color("162c36"),
			W.GOLD if is_selected else Color("476e7d"),
			6
		)
		item_panel.add_theme_stylebox_override("panel", t_normal_style)
		item_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if not is_selected:
			item_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			item_panel.mouse_entered.connect(func(): item_panel.add_theme_stylebox_override("panel", t_hover_style))
			item_panel.mouse_exited.connect(func(): item_panel.add_theme_stylebox_override("panel", t_normal_style))
			item_panel.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					request("transmute_target", id)
					request("transmute_uids", "")
			)
		targets_list.add_child(item_panel)
		
		var item_row := HBoxContainer.new(); item_row.add_theme_constant_override("separation", 8)
		item_row.mouse_filter = Control.MOUSE_FILTER_PASS
		item_panel.add_child(item_row)
		
		var t_icon := _create_material_icon(id, Vector2(28, 28))
		item_row.add_child(t_icon)
		
		var name_lbl := W.text(item_row, def.name, 17, W.GOLD if is_selected else W.INK)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name_lbl.custom_minimum_size.x = 44
		name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		
		badge(item_row, "+%d" % (count * 2), READY if is_selected else Color("5a8a7a"))
		
		var stock_lbl := W.text(item_row, "库存: %d" % amount(id), 13, W.MUTED)
		stock_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		stock_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stock_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var sel_btn := W.button(item_row, "✓ 选中" if is_selected else "设为产物", func():
			request("transmute_target", id)
			request("transmute_uids", "")
		, is_selected)
		sel_btn.name = "SelectTarget_" + id
		sel_btn.custom_minimum_size = Vector2(76, 28)
		sel_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		if is_selected:
			sel_btn.add_theme_color_override("font_color", W.GOLD)
