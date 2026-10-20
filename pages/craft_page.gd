extends "res://pages/flow_base.gd"
const PAGE_SIZE := 8
const READY := Color("8dd6b6")
const MISSING := Color("df968b")
var recipe_tooltip_layer: CanvasLayer
var recipe_tooltip_icon: Button

func recipe_tooltip_position(point: Vector2, tooltip_size: Vector2, bounds: Rect2) -> Vector2:
	var gap := 12.0
	var safe := bounds.grow(-8.0)
	# Prefer lower right, then lower left, upper right and upper left.
	for offset in [Vector2(gap, gap), Vector2(-tooltip_size.x - gap, gap), Vector2(gap, -tooltip_size.y - gap), -tooltip_size - Vector2(gap, gap)]:
		var candidate: Vector2 = point + offset
		if safe.encloses(Rect2(candidate, tooltip_size)): return candidate
	return Vector2(clampf(point.x + gap, safe.position.x, maxf(safe.position.x, safe.end.x - tooltip_size.x)), clampf(point.y + gap, safe.position.y, maxf(safe.position.y, safe.end.y - tooltip_size.y)))

func close_recipe_tooltip() -> void:
	if not is_instance_valid(recipe_tooltip_layer): return
	remove_child(recipe_tooltip_layer)
	recipe_tooltip_layer.queue_free()
	recipe_tooltip_layer = null
	recipe_tooltip_icon = null

func _input(event: InputEvent) -> void:
	if not is_instance_valid(recipe_tooltip_layer): return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		var replacement: Dictionary = {}
		var replacement_icon: Button
		var point: Vector2 = event.position
		var panel := recipe_tooltip_layer.find_child("RecipeTooltip", true, false) as Control
		var can_switch: bool = event is InputEventScreenTouch or event.button_index == MOUSE_BUTTON_LEFT
		# Respect the popup itself; only exposed icons can replace its description.
		if can_switch and not panel.get_global_rect().has_point(point):
			for icon in find_children("RecipeIcon", "Button", true, false):
				var local_point: Vector2 = icon.get_global_transform_with_canvas().affine_inverse() * point
				if icon.is_visible_in_tree() and Rect2(Vector2.ZERO, icon.size).has_point(local_point):
					var output: Dictionary = icon.get_meta("recipe_output")
					if icon != recipe_tooltip_icon:
						replacement = output
						replacement_icon = icon
					break
		close_recipe_tooltip()
		if not replacement.is_empty(): show_recipe_tooltip(replacement, point, replacement_icon)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		close_recipe_tooltip()
		get_viewport().set_input_as_handled()

func show_recipe_tooltip(output: Dictionary, point: Vector2, source_icon: Button) -> void:
	close_recipe_tooltip()
	recipe_tooltip_icon = source_icon
	recipe_tooltip_layer = CanvasLayer.new()
	recipe_tooltip_layer.layer = 100
	add_child(recipe_tooltip_layer)
	var shield := Control.new()
	shield.theme = W.theme()
	recipe_tooltip_layer.add_child(shield)
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new(); panel.name = "RecipeTooltip"
	panel.modulate.a = 0.0
	shield.add_child(panel)
	panel.add_theme_stylebox_override("panel", box_style(Color("08224b"), Color("f6ebda"), 16))
	var bounds := get_viewport_rect()
	panel.custom_minimum_size.x = minf(340.0, bounds.size.x - 16.0)
	var column := VBoxContainer.new(); panel.add_child(column)
	column.add_theme_constant_override("separation", 8)
	W.text(column, output.name, 23, W.INK)
	var description := W.text(column, output.description, 19, W.INK)
	description.name = "RecipeDescription"
	# Resolve wrapped text before measuring the popup's final height.
	panel.size = Vector2(panel.custom_minimum_size.x, 0)
	await get_tree().process_frame
	if not is_instance_valid(panel): return
	panel.size.y = panel.get_combined_minimum_size().y
	panel.position = recipe_tooltip_position(point, panel.size, bounds)
	panel.modulate.a = 1.0

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
		var h := size.y if size.y > 20.0 else 340.0

		# Keep the top input fixed; the remaining diagram uses the available height.
		var sw := minf(108.0, w * 0.28)
		var sh := 108.0
		fit_child_in_rect(slot1, Rect2(Vector2((w - sw) * 0.5, 8), Vector2(sw, sh)))
		fit_child_in_rect(slot2, Rect2(Vector2(w * 0.18 - sw * 0.5, h - sh - 8), Vector2(sw, sh)))
		fit_child_in_rect(slot3, Rect2(Vector2(w * 0.82 - sw * 0.5, h - sh - 8), Vector2(sw, sh)))
		var cw := minf(120.0, w * 0.30)
		var ch := 140.0
		# Leave at least 40 pixels of unobstructed green line beneath the top input.
		var output_y := maxf(8 + sh + 40, h * 0.5 - ch * 0.5)
		fit_child_in_rect(center_box, Rect2(Vector2((w - cw) * 0.5, output_y), Vector2(cw, ch)))

	func _draw() -> void:
		if not is_instance_valid(slot1) or not is_instance_valid(center_box): return
		var c := center_box.position + center_box.size * 0.5
		var p1 := slot1.position + slot1.size * 0.5
		var p2 := slot2.position + slot2.size * 0.5
		var p3 := slot3.position + slot3.size * 0.5

		var col_line := Color("47796f") if is_active else Color("253e48")
		var col_inner := Color("8dd6b6") if is_active else Color("3a6369")

		var points: Array[Vector2] = [p1, p2, p3]
		var slots: Array[PanelContainer] = [slot1, slot2, slot3]
		for i in range(points.size()):
			var p := points[i]
			var dir: Vector2 = (c - p).normalized()
			# Connect visible panel edges so arrowheads cannot disappear under a panel.
			var start := edge_point(p, slots[i].size * 0.5, dir)
			var end := edge_point(c, center_box.size * 0.5, -dir)
			draw_line(start, end, col_line, 4.0, true)
			draw_line(start, end, col_inner, 2.0, true)
			var mid := start.lerp(end, 0.65)
			var perp := Vector2(-dir.y, dir.x) * 6.0
			draw_line(mid - dir * 8.0 + perp, mid, col_inner, 2.0, true)
			draw_line(mid - dir * 8.0 - perp, mid, col_inner, 2.0, true)

	func edge_point(center: Vector2, half_size: Vector2, direction: Vector2) -> Vector2:
		var distance_x := half_size.x / maxf(absf(direction.x), 0.0001)
		var distance_y := half_size.y / maxf(absf(direction.y), 0.0001)
		return center + direction * minf(distance_x, distance_y)

func box_style(background: Color, border: Color, margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background; style.border_color = border
	style.set_border_width_all(1); style.set_corner_radius_all(7)
	style.content_margin_left = margin; style.content_margin_right = margin
	style.content_margin_top = margin; style.content_margin_bottom = margin
	return style

func badge(parent: Node, text: String, color: Color) -> Label:
	var panel := PanelContainer.new(); parent.add_child(panel)
	panel.add_theme_stylebox_override("panel", box_style(Color("172d35"), Color("33565b"), 5))
	var label := W.text(panel, text, 15, color); label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

func build() -> void:
	add_theme_constant_override("separation", 10)
	var ui_state: Dictionary = context.get("ui_state", {})
	var is_build_mode: bool = context.get("panel", "") == "build" or ui_state.get("craft_mode", "") == "build"
	var tab: String = ui_state.get("craft_tab", "craft")
	if is_build_mode: tab = "craft"
	elif tab not in ["craft", "transmute"]: tab = "craft"

	# Top bar with title and tabs
	var header := HBoxContainer.new(); header.name = "CraftHeader"; add_child(header)
	header.add_theme_constant_override("separation", 16)
	header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.custom_minimum_size.y = 48

	var title_text: String = "建造设备" if is_build_mode else "工具台"
	var title_lbl := W.text(header, title_text, 30, W.INK)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_lbl.custom_minimum_size.x = 120 if is_build_mode else 90

	if not is_build_mode:
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
			btn.custom_minimum_size = Vector2(124, 44)
		var active_tab_btn: Button = craft_tab_btn if tab == "craft" else transmute_tab_btn
		active_tab_btn.add_theme_color_override("font_color", W.GOLD)

	# Spacer pushes tabs to the left and prevents header content from reaching the top-right corner
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	# Dedicated reservation for CloseX button
	var close_spacer := Control.new()
	close_spacer.custom_minimum_size = Vector2(128, 48)
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
	var ui_state: Dictionary = context.get("ui_state", {})
	var is_build_mode: bool = context.get("panel", "") == "build" or ui_state.get("craft_mode", "") == "build"
	var all_ids: Array = catalog.table("recipes").keys()
	var ids: Array = []
	if is_build_mode:
		for id in all_ids:
			var r: Dictionary = catalog.entry("recipes", id)
			var out_card: Dictionary = catalog.entry("cards", r.output)
			if out_card.get("kind", "") == "equipment":
				ids.append(id)
	else:
		ids = all_ids
	W.text(self, "制作设备消耗 AP；制作后可在木筏空格安装。" if is_build_mode else "合成消耗 AP；设备安装不消耗 AP。", 15, W.MUTED)
	var grid := GridContainer.new(); grid.name = "RecipeGrid"; grid.columns = 3 if context.get("mobile",false) else 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10)
	# Every recipe is rendered once and scrolled; paging split the list into
	# fixed pages that clipped the second row on short phone screens.
	var scroll:=ScrollContainer.new()
	scroll.name="MobileRecipeScroll" if context.get("mobile",false) else "RecipeScroll"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(scroll); scroll.add_child(grid)
	for id in ids: recipe_tile(grid, id)

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
	W.text(title, output.name, 25, W.INK)
	badge(title, "%d AP" % recipe.cost, W.GOLD)
	var icon := Button.new(); icon.name = "RecipeIcon"
	icon.set_meta("recipe_output", output)
	icon.flat = true
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.custom_minimum_size.y = 64 if context.get("mobile",false) else 80
	icon.accessibility_name = output.name + " · 点击查看说明"
	column.add_child(icon)
	var art := TextureRect.new()
	art.texture = assets.texture("card." + recipe.output)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			icon.set_meta("description_point", icon.get_global_transform_with_canvas() * event.position)
	)
	icon.pressed.connect(func(): show_recipe_tooltip(output, icon.get_meta("description_point", icon.get_global_rect().get_center()), icon))
	var materials := HFlowContainer.new(); column.add_child(materials)
	materials.add_theme_constant_override("h_separation", 5); materials.add_theme_constant_override("v_separation", 5)
	for material in recipe.ingredients:
		var owned: int = amount(material); var needed: int = recipe.ingredients[material]
		badge(materials, "%s %d/%d" % [catalog.entry("cards", material).name, owned, needed], READY if owned >= needed else MISSING)
	var button := W.button(column, "合成" if reason == "" else reason, func(): send("craft", {"id": id}), reason != "", reason)
	button.name = "CraftRecipeButton"; button.set_meta("recipe_id", id)
	button.custom_minimum_size.y = 48; button.accessibility_name = recipe.name + " · %d AP" % recipe.cost
	W.primary(button)

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
	var ui_state: Dictionary = context.get("ui_state", {})
	var current_target: String = ui_state.get("transmute_target", "wood")
	if current_target not in ["wood", "iron", "plastic", "rope", "cloth"]: current_target = "wood"

	# All available resource cards in hand
	var resource_cards: Array = context.hand.filter(func(c): return not c.temporary and catalog.entry("cards", c.id).kind == "resource")
	var total_resources: int = resource_cards.size()

	# This interface converts one batch at a time; core/Agent batch support is unchanged.
	var count := 1
	var needed := 3

	# Selected input UIDs
	var raw_uids: String = ui_state.get("transmute_uids", "")
	var selected_uids: Array = []
	if raw_uids == "none":
		selected_uids = []
	elif raw_uids != "":
		for uid in raw_uids.split(","):
			if uid != "" and resource_cards.any(func(c): return c.uid == uid) and uid not in selected_uids:
				selected_uids.append(uid)

	# Three-Column Layout Container. Phone keeps the same side-by-side columns as
	# desktop; the middle confirmation column is only narrowed so touch-sized
	# material cards and target rows still fit. A page scroll stays available for
	# short screens without changing the column order.
	var columns := HBoxContainer.new()
	columns.name = "TransmuteColumns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10 if context.get("mobile",false) else 14)
	if context.get("mobile",false):
		var scroll:=ScrollContainer.new(); scroll.name="MobileTransmutePageScroll"
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		container.add_child(scroll); scroll.add_child(columns)
		W.remember_scroll(scroll,context.ui_state,"transmute_scroll")
		scroll.get_v_scroll_bar().value_changed.connect(func(value):
			if not scroll.get_meta("restoring_scroll",false): request("transmute_scroll",str(int(value))))
	else: container.add_child(columns)

	# ==========================================
	# LEFT COLUMN: 现有材料 (Existing Materials)
	# ==========================================
	var left_panel := PanelContainer.new(); left_panel.name = "TransmuteInventory"
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.0
	left_panel.custom_minimum_size = Vector2(320, 0)
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
	# The partial refresh path updates this label by name, so it must be named.
	var selected_badge := badge(sel_hdr, "已选 %d / %d 张" % [selected_uids.size(), needed], READY if selected_uids.size() == needed else MISSING)
	selected_badge.name = "TransmuteSelectedCount"

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
		m_panel.custom_minimum_size = Vector2(150, 142)
		m_panel.mouse_filter = Control.MOUSE_FILTER_STOP

		var can_plus: bool = (allocated < owned) and (selected_uids.size() < needed)
		var plus_reason := ""
		if allocated >= owned: plus_reason = "拥有数量不足"
		elif selected_uids.size() >= needed: plus_reason = "已选满所需原料总数"

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
			m_panel.mouse_entered.connect(func(): _refresh_material_item_style(m_panel,id,true) if not context.get("mobile",false) else null)
			m_panel.mouse_exited.connect(func(): _refresh_material_item_style(m_panel,id,false))
			m_panel.tooltip_text = "点击投入 1 张%s" % def.name if can_plus else plus_reason
		else:
			m_panel.tooltip_text = "暂无此材料"

		# Card children pass pointer events to the full card surface: tapping the
		# icon adds one card, the selected slots in 开始转化 take one back.
		_request_tap(m_panel, func(): _request_add_material(id))

		mat_list.add_child(m_panel)

		var card_column := VBoxContainer.new()
		card_column.mouse_filter = Control.MOUSE_FILTER_PASS
		card_column.add_theme_constant_override("separation", 4)
		m_panel.add_child(card_column)
		var mat_icon := _create_material_icon(id, Vector2(96, 96))
		mat_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mat_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_column.add_child(mat_icon)
		var quantity := W.text(card_column, "%d/%d" % [allocated, owned], 24, READY if is_allocated else W.MUTED)
		quantity.name = "MatQuantity_" + id
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quantity.autowrap_mode = TextServer.AUTOWRAP_OFF
		quantity.mouse_filter = Control.MOUSE_FILTER_PASS
		# Touch has no hover tooltip, so the add affordance is drawn on the card.
		var plus := Label.new()
		plus.name = "MatTapHint_" + id
		plus.text = "＋"
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		plus.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		plus.add_theme_font_size_override("font_size", 22)
		plus.add_theme_color_override("font_color", W.GOLD if can_plus else W.MUTED)
		m_panel.add_child(plus)

	# ==========================================
	# CENTER COLUMN: 三元融合图示 + 开始转化
	# ==========================================
	var center_panel := PanelContainer.new(); center_panel.name = "TransmuteCore"
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Phone shares the row with the material and target columns, so its middle
	# column keeps only a slight width advantage over the side columns.
	center_panel.size_flags_stretch_ratio = 1.15 if context.get("mobile",false) else 1.4
	center_panel.custom_minimum_size = Vector2(320 if context.get("mobile",false) else 440, 0)
	center_panel.add_theme_stylebox_override("panel", box_style(Color("0c1d26"), Color("2c4652"), 14))
	columns.add_child(center_panel)

	var center_vbox := VBoxContainer.new()
	center_panel.add_child(center_vbox)
	center_vbox.add_theme_constant_override("separation", 8)

	var core_hdr := HBoxContainer.new(); center_vbox.add_child(core_hdr)
	var core_title := W.text(core_hdr, "开始转化", 26, W.GOLD)
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
	diagram.custom_minimum_size = Vector2(0, 340)
	diagram.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diagram.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

	for i in range(3):
		var slot: PanelContainer = [slot1, slot2, slot3][i]
		slot.set_meta("transmute_slot_index", i)
		if not slot.gui_input.is_connected(_on_transmute_slot_gui_input):
			slot.gui_input.connect(_on_transmute_slot_gui_input.bind(slot))
		# Empty slots have no instructions or placeholder text.
		if i >= selected_uids.size(): continue
		var uid: String = selected_uids[i]
		var card: Dictionary = resource_cards.filter(func(c): return c.uid == uid)[0]
		var icon := _create_material_icon(card.id, Vector2(88, 88))
		slot.add_child(icon)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.accessibility_name = "撤回已投入的" + catalog.entry("cards", card.id).name
		slot.tooltip_text = "点击撤回这张材料"

	# Output contains only an icon with the yield below it.
	var out_col := VBoxContainer.new()
	out_col.alignment = BoxContainer.ALIGNMENT_CENTER
	out_col.add_theme_constant_override("separation", 4)
	center_box.add_child(out_col)
	var out_icon := _create_material_icon(current_target, Vector2(88, 88))
	out_icon.name = "TransmuteOutputIcon"
	out_col.add_child(out_icon)
	var out_val := W.text(out_col, str(count * 2), 24, READY)
	out_val.name = "TransmuteOutputQuantity"
	out_val.autowrap_mode = TextServer.AUTOWRAP_OFF
	out_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	diagram._update_layout()

	# ==========================================
	# RIGHT COLUMN: 目标材料
	# ==========================================
	var right_vbox := VBoxContainer.new(); right_vbox.name = "TransmuteRightCol"
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.0
	right_vbox.custom_minimum_size = Vector2(320, 0)
	right_vbox.add_theme_constant_override("separation", 10)
	columns.add_child(right_vbox)
	if context.get("mobile",false):
		# Phone keeps the desktop order (materials, confirm, targets) so the
		# narrowed middle column stays the confirmation panel.
		left_panel.custom_minimum_size.x=0; right_vbox.custom_minimum_size.x=0

	# Bottom Section: 选择转化的目标材料
	var target_panel := PanelContainer.new(); target_panel.name = "TransmuteTargetSection"
	target_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	target_panel.add_theme_stylebox_override("panel", box_style(Color("0c1d26"), Color("2c4652"), 10))
	right_vbox.add_child(target_panel)
	var target_vbox := VBoxContainer.new(); target_panel.add_child(target_vbox)
	target_vbox.add_theme_constant_override("separation", 6)

	var target_title := W.text(target_vbox, "选择转化的目标材料", 18, W.GOLD)
	target_title.autowrap_mode = TextServer.AUTOWRAP_OFF

	# The list scrolls inside the box so 开始转化 can stay pinned to its bottom.
	var targets_scroll := ScrollContainer.new()
	targets_scroll.name = "TransmuteTargetScroll"
	targets_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	targets_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	target_vbox.add_child(targets_scroll)

	var targets_list := VBoxContainer.new(); targets_list.name = "TransmuteTargets"
	targets_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets_list.add_theme_constant_override("separation", 5); targets_scroll.add_child(targets_list)

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
			item_panel.mouse_entered.connect(func(): item_panel.add_theme_stylebox_override("panel", t_hover_style) if not context.get("mobile",false) else null)
			item_panel.mouse_exited.connect(func(): item_panel.add_theme_stylebox_override("panel", t_normal_style))
			item_panel.gui_input.connect(func(event: InputEvent):
				if not context.get("mobile",false) and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					request("transmute_target", id)
					request("transmute_uids", "")
			)
		targets_list.add_child(item_panel)

		var item_row := HBoxContainer.new(); item_row.add_theme_constant_override("separation", 8)
		item_row.mouse_filter = Control.MOUSE_FILTER_PASS
		item_panel.add_child(item_row)

		var t_icon := _create_material_icon(id, Vector2(40, 40))
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

		var sel_btn := W.button(item_row, "✓ 选中" if is_selected else "选择", func():
			request("transmute_target", id)
			request("transmute_uids", "")
		, is_selected)
		sel_btn.name = "SelectTarget_" + id
		sel_btn.custom_minimum_size = Vector2(64, 36)
		sel_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		if is_selected:
			sel_btn.add_theme_color_override("font_color", W.GOLD)

	# Primary action pinned to the bottom edge of the target box.
	var exec_btn := W.button(target_vbox, "开始转化", func(): _send_current_transmute(), reason != "", reason)
	exec_btn.name = "TransmuteExecuteButton"
	exec_btn.custom_minimum_size.y = 56
	exec_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exec_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	W.primary(exec_btn)
	if reason == "":
		exec_btn.add_theme_color_override("font_color", W.GOLD)

func _transmute_resources() -> Array:
	return context.get("hand", []).filter(func(card): return not card.temporary and catalog.entry("cards", card.id).kind == "resource")

func _refresh_material_item_style(item: PanelContainer, id: String, hovered: bool = false) -> void:
	var resources := _transmute_resources()
	var selected := _transmute_selected_uids(resources)
	var owned: Array=resources.filter(func(card): return card.id == id)
	var allocated: bool=owned.any(func(card): return card.uid in selected)
	var background: Color
	var border_color: Color
	if allocated:
		background=Color("1e3e4d") if hovered else Color("16313d")
		border_color=Color("8dd6b6") if hovered else Color("5da898")
	elif not owned.is_empty():
		background=Color("142c38") if hovered else Color("102028")
		border_color=Color("4a7487") if hovered else Color("2e4956")
	else:
		background=Color("0c171e")
		border_color=Color("1c2b33")
	item.add_theme_stylebox_override("panel",box_style(background,border_color,6))

func _transmute_selected_uids(resources: Array) -> Array:
	var raw: String = str(context.get("ui_state", {}).get("transmute_uids", ""))
	var selected: Array = []
	if raw not in ["", "none"]:
		for uid in raw.split(","):
			if uid != "" and uid not in selected and resources.any(func(card): return card.uid == uid): selected.append(uid)
	return selected

func _request_add_material(id: String) -> void:
	var resources := _transmute_resources()
	var selected := _transmute_selected_uids(resources)
	if selected.size() >= 3: return
	for card in resources:
		if card.id == id and card.uid not in selected:
			selected.append(card.uid)
			request("transmute_uids", ",".join(selected))
			return

func _request_remove_transmute(uid: String) -> void:
	var selected := _transmute_selected_uids(_transmute_resources())
	selected.erase(uid)
	request("transmute_uids", ",".join(selected) if not selected.is_empty() else "none")

func _request_remove_transmute_slot(index: int) -> void:
	var selected := _transmute_selected_uids(_transmute_resources())
	if index >= 0 and index < selected.size(): _request_remove_transmute(str(selected[index]))

func _on_transmute_slot_gui_input(event: InputEvent, slot: Control) -> void:
	_tap_event(slot, event, func(): _request_remove_transmute_slot(int(slot.get_meta("transmute_slot_index", -1))))

## Tap = press and release in nearly the same spot. Dragging the page from a card
## or a slot must never commit, so the action only fires on a short-distance release.
func _request_tap(control: Control, action: Callable) -> void:
	control.gui_input.connect(func(event: InputEvent): _tap_event(control, event, action))

func _tap_event(control: Control, event: InputEvent, action: Callable) -> void:
	var pressed := false
	var released := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
	if pressed:
		control.set_meta("tap_origin", event.position)
	elif released and control.has_meta("tap_origin"):
		if event.position.distance_to(control.get_meta("tap_origin")) <= 14.0: action.call()

## Quick transmute is gone: the single action always submits the picked cards.
func _send_current_transmute() -> void:
	var target := str(context.get("ui_state", {}).get("transmute_target", "wood"))
	send("transmute", {"target": target, "uids": _transmute_selected_uids(_transmute_resources()), "count": 1})

func refresh_craft_tab(view: Dictionary) -> bool:
	var next_tab := str(view.get("ui_state", {}).get("craft_tab", "craft"))
	if next_tab not in ["craft", "transmute"]: next_tab = "craft"
	var old_tab := str(context.get("ui_state", {}).get("craft_tab", "craft"))
	context = view.duplicate(true)
	if old_tab == next_tab:
		if next_tab == "transmute": return refresh_transmute_ui(view, "craft_tab")
		return false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	build()
	return true

func refresh_transmute_ui(view: Dictionary, action: String) -> bool:
	if not is_instance_valid(find_child("TransmutePanel", true, false)): return false
	context = view.duplicate(true)
	var resources := _transmute_resources()
	var selected := _transmute_selected_uids(resources)
	var target := str(context.get("ui_state", {}).get("transmute_target", "wood"))
	if target not in ["wood", "iron", "plastic", "rope", "cloth"]: target = "wood"
	var total := resources.size()
	var reason := ""
	if not context.get("can_base", false): reason = "当前阶段不可转化"
	elif context.get("ap", 0) < 1: reason = "基地 AP 不足 (需 1 AP)"
	elif total < 3: reason = "手牌可用资源不足 3 张"
	elif selected.size() != 3: reason = "请选择正好 3 张资源牌 (当前 %d 张)" % selected.size()
	var selected_label := find_child("TransmuteSelectedCount", true, false) as Label
	if is_instance_valid(selected_label):
		selected_label.text = "已选 %d / 3 张" % selected.size()
		selected_label.add_theme_color_override("font_color", READY if selected.size() == 3 else MISSING)
	for id in ["wood", "iron", "plastic", "rope", "cloth", "corpse"]:
		var item := find_child("MatItem_" + id, true, false) as PanelContainer
		if not is_instance_valid(item): continue
		var matching: Array = resources.filter(func(card): return card.id == id)
		var matching_uids: Array = matching.map(func(card): return card.uid)
		var allocated: int = selected.filter(func(uid): return uid in matching_uids).size()
		_refresh_material_item_style(item,id) if is_instance_valid(item) else null
		var quantity := find_child("MatQuantity_" + id, true, false) as Label
		if is_instance_valid(quantity):
			quantity.text = "%d/%d" % [allocated, matching.size()]
			quantity.add_theme_color_override("font_color", READY if allocated > 0 else W.MUTED)
		var can_add: bool = allocated < matching.size() and selected.size() < 3
		item.tooltip_text = "点击投入 1 张%s" % catalog.entry("cards", id).name if can_add else ("已选满所需原料总数" if selected.size() >= 3 else "拥有数量不足")
		var plus_label := find_child("MatTapHint_" + id, true, false) as Label
		if is_instance_valid(plus_label):
			plus_label.add_theme_color_override("font_color", W.GOLD if can_add else W.MUTED)
	for i in range(3):
		var slot := find_child("DiagramSlot%d" % (i + 1), true, false) as PanelContainer
		if not is_instance_valid(slot): return false
		for child in slot.get_children(): slot.remove_child(child); child.queue_free()
		if i < selected.size():
			var card: Dictionary = resources.filter(func(c): return c.uid == selected[i])[0]
			slot.add_child(_create_material_icon(card.id, Vector2(88, 88)))
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			slot.accessibility_name = "撤回已投入的" + catalog.entry("cards", card.id).name
			slot.tooltip_text = "点击撤回这张材料"
		else:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var output := find_child("TransmuteOutputIcon", true, false) as PanelContainer
	if not is_instance_valid(output): return false
	var textures := output.find_children("*", "TextureRect", true, false)
	var texture := textures[0] as TextureRect if not textures.is_empty() else null
	if is_instance_valid(texture): texture.texture = assets.texture("card." + target)
	var diagram := find_child("FusionDiagram", true, false) as FusionDiagram
	if is_instance_valid(diagram): diagram.is_active = reason.is_empty(); diagram.queue_redraw()
	var execute := find_child("TransmuteExecuteButton", true, false) as Button
	if is_instance_valid(execute):
		execute.disabled = not reason.is_empty()
		execute.tooltip_text = reason
	for id in ["wood", "iron", "plastic", "rope", "cloth"]:
		var owned: int = resources.filter(func(card): return card.id == id).size()
		var allocated: int = selected.filter(func(uid): return resources.any(func(card): return card.uid == uid and card.id == id)).size()
		var quantity := find_child("MatQuantity_" + id, true, false) as Label
		if is_instance_valid(quantity):
			quantity.text = "%d/%d" % [allocated, owned]
			quantity.add_theme_color_override("font_color", READY if allocated > 0 else W.MUTED)
		var item := find_child("TargetItem_" + id, true, false) as PanelContainer
		if not is_instance_valid(item): continue
		var is_selected: bool = id == target
		item.add_theme_stylebox_override("panel", box_style(Color("1f404d") if is_selected else Color("13242c"), W.GOLD if is_selected else Color("2c4652"), 6))
		var row := item.get_child(0)
		var button := row.find_child("SelectTarget_" + id, true, false) as Button
		if is_instance_valid(button):
			button.text = "✓ 选中" if is_selected else "选择"
			button.disabled = is_selected
			button.add_theme_color_override("font_color", W.GOLD if is_selected else W.INK)
	return true

func show_workbench_help() -> void:
	var dialog := AcceptDialog.new()
	dialog.name = "CraftHelpDialog"
	dialog.title = "工作台说明"
	dialog.dialog_text = "配方合成：选择已解锁的配方，消耗对应材料与基地 AP 制作物品。设备制成后可在木筏空格安装。\n\n资源转化：单击左侧材料卡片投入一张，点击中央已投入的图标撤回该张材料。数量 1/3 表示持有 3 张、已选 1 张。\n\n每次投入任意 3 张非临时资源牌，消耗 1 点基地 AP，获得右侧选定的 2 张同类资源。进入页面时不会自动选料。\n\n选择与撤回不消耗材料或 AP；点击“开始转化”后才执行。快捷转化会自动选料并立即执行，请确认目标材料后使用。"
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.get_label().custom_minimum_size = Vector2(600, 0)
	dialog.ok_button_text = "知道了"
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(680, 380))
