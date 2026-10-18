extends "res://pages/flow_base.gd"
## Node event page: illustration | prose | options.
## Options are two-step (select -> confirm); advance/skip/result stay one-step.
const VoyagePage = preload("res://pages/voyage_hud.gd")
const Difficulty = preload("res://core/difficulty_rules.gd")

const COLUMN_GAP := 20.0
const CHOICES_WIDTH := 332.0
const ART_DEFAULT := "opening.image.05"
## Presentation-only art table: no node owns a dedicated illustration yet.
const ART_BY_KIND := {
	"ruin": "opening.image.02",
	"shop": "opening.image.03",
	"exchange": "opening.image.04",
	"environment": "opening.image.04",
	"battle": "opening.image.04",
}
const PRESELECT_HINT := "再次点击该选项即可确认；也可点右上角“取消选择”返回。"

var art_view: TextureRect
var prose: VBoxContainer
var options_panel: VBoxContainer
var options_header: Control
var cancel_button: Button
var entries: Array = []
var widgets: Array = []
var preselect_key := ""
var default_prose := {}

func costs(option: Dictionary) -> String:
	var result := PackedStringArray()
	if option.get("cost",0)>0: result.append("%d AP" % option.cost)
	for id in option.get("cardCosts",{}): result.append(catalog.entry("cards",id).name+"×%d" % option.cardCosts[id])
	for stat in option.get("statCosts",{}): result.append({"hp":"生命","sanity":"SAN"}.get(stat,stat)+"%d" % option.statCosts[stat])
	return " · ".join(result)

func build() -> void:
	name = "NodeEventBody"
	add_theme_constant_override("separation", 0)
	var columns := HBoxContainer.new()
	columns.name = "NodeEventColumns"
	columns.add_theme_constant_override("separation", int(COLUMN_GAP))
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.clip_contents = true
	add_child(columns)
	build_art_column(columns)
	var prose_column := build_frame_column(columns, 1.06, "NodeEventProse")
	prose = VBoxContainer.new()
	prose.name = "NodeEventText"
	prose.add_theme_constant_override("separation", 10)
	prose.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var prose_scroll:=ScrollContainer.new()
	prose_scroll.name="NodeEventProseScroll"
	prose_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	prose_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	prose_column.add_child(prose_scroll)
	prose_scroll.add_child(prose)
	prose.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var choices_column := build_frame_column(columns, 0.0, "NodeEventOptions")
	choices_column.custom_minimum_size.x = CHOICES_WIDTH
	choices_column.size_flags_horizontal = Control.SIZE_FILL
	# The header keeps its height in every state so showing 取消选择 never moves the options.
	options_header = HBoxContainer.new()
	options_header.name = "NodeEventOptionsHeader"
	options_header.add_theme_constant_override("separation", 6)
	options_header.custom_minimum_size.y = 56 if context.get("mobile",false) else 34
	choices_column.add_child(options_header)
	var prompt := W.text(options_header, "请做出选择", 14, W.MUTED)
	prompt.name = "NodeEventOptionsHint"
	prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt.size_flags_horizontal = Control.SIZE_FILL
	# An expanding spacer right-aligns 取消选择 without relying on shrink flags.
	var push := Control.new()
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_header.add_child(push)
	cancel_button = build_direct_button(options_header, "取消选择", cancel_preselect)
	cancel_button.name = "CancelPreselect"
	cancel_button.tooltip_text = "回到事件说明，不提交选项"
	cancel_button.custom_minimum_size = Vector2(136, 56 if context.get("mobile",false) else 34)
	cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel_button.add_theme_font_size_override("font_size", 14)
	options_panel = VBoxContainer.new()
	options_panel.name = "NodeEventChoices"
	options_panel.add_theme_constant_override("separation", 0)
	options_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var choices_scroll:=ScrollContainer.new()
	choices_scroll.name="NodeEventChoicesScroll"
	choices_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	choices_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	choices_column.add_child(choices_scroll)
	choices_scroll.add_child(options_panel)
	options_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	choices_scroll.resized.connect(func(): options_panel.custom_minimum_size.y=choices_scroll.size.y)
	apply_art()
	node_event()
	pack_options()
	paint_options()
	paint_prose({})

func build_art_column(columns: Node) -> void:
	var frame := preload("res://presentation/hud_frame.gd").new()
	frame.name = "NodeEventArt"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 0.94
	var style: StyleBoxFlat = VoyagePage.compact_style()
	style.bg_color = Color(0.02,0.045,0.065,0.96)
	style.content_margin_left = 8; style.content_margin_right = 8
	style.content_margin_top = 8; style.content_margin_bottom = 8
	frame.add_theme_stylebox_override("panel", style)
	columns.add_child(frame)
	art_view = TextureRect.new()
	art_view.name = "NodeEventIllustration"
	art_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art_view)

func build_frame_column(columns: Node, ratio: float, frame_name: String) -> VBoxContainer:
	var frame := preload("res://presentation/hud_frame.gd").new()
	frame.name = frame_name
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if ratio > 0.0:
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.size_flags_stretch_ratio = ratio
	var style: StyleBoxFlat = VoyagePage.compact_style()
	style.content_margin_left = 18; style.content_margin_right = 18
	style.content_margin_top = 16; style.content_margin_bottom = 16
	frame.add_theme_stylebox_override("panel", style)
	columns.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	frame.add_child(box)
	return box

func apply_art() -> void:
	var node: Dictionary = context.get("node", {})
	var target := str(node.get("art", ""))
	if target != "" and assets.show_label(target): target = ""
	var monster := str(node.get("monster", ""))
	if target == "" and monster != "" and not assets.show_label("enemy."+monster): target = "enemy."+monster
	if target == "":
		target = str(ART_BY_KIND.get(str(node.get("kind", "")), ART_DEFAULT))
	art_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if target.begins_with("enemy.") else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_view.texture = assets.texture(target)
	art_view.set_meta("asset_id", target)

func node_event() -> void:
	var node: Dictionary = context.node
	var step: String = str(context.get("story_step", ""))
	var lines: Array = []
	if step == "result":
		lines.append(str(context.get("result_text", "")))
	else:
		var description := str(node.get("description", ""))
		if description != "": lines.append(description)
	if step == "choice":
		var previous: String = str(context.get("encounter", {}).get("last_result", ""))
		if previous != "": lines.append(previous)
		if node.has("monster"):
			var enemy: Dictionary = Difficulty.enemy(catalog, context, node.monster)
			lines.append("%s · 生命%d · %s" % [enemy.name, enemy.hp, enemy.intent])
	default_prose = {
		"eyebrow": {"intro":"海上遭遇","choice":"作出选择","result":"事件结果"}.get(step, "当前事件"),
		"headline": str(node.get("name", "")),
		"lines": lines,
		"hint": "",
	}
	match step:
		"intro":
			direct("继续","advance"); direct("跳过文字","skip")
		"choice":
			if node.has("monster"):
				direct("迎战","fight"); direct("离开遭遇","leave_encounter")
			if str(node.get("kind", "")) == "shop": direct("进入商店","shop_enter")
			for option in context.get("event_options", []): event_option(option)
		"result":
			direct("结束节点","advance")

## One-step action: advance, skip, fight, shop entry and result confirmation.
func direct(title: String, command: String, args: Dictionary = {}, disabled: bool = false, reason: String = "") -> Button:
	var button := build_direct_button(options_panel, title, func(): send(command, args.duplicate(true)))
	button.name = "NodeEventAction_"+command
	button.disabled = disabled
	button.tooltip_text = reason
	if disabled and command in ["craft","install","upgrade","expand","heal","repair_cell","action_card"]:
		button.icon = assets.texture("ui.unavailable"); button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 18)
	widgets.append(button)
	return button

func build_direct_button(parent: Node, title: String, callback: Callable) -> Button:
	var button := W.button(parent, title, callback)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 15)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 56 if context.get("mobile",false) else 46
	return button

## Backward-compatible helper used by existing UI tests for direct commands.
func choice(panel: Node, title: String, command: String, args: Dictionary = {}, disabled: bool = false, reason: String = "") -> Button:
	return direct(title, command, args, disabled, reason)

func event_option(option: Dictionary) -> void:
	var alternatives: Array = option.get("actions", [])
	if alternatives.is_empty(): return
	var index := 0
	for i in range(alternatives.size()):
		if str(alternatives[i].get("reason", "")) == "": index = i; break
	var selection: OptionButton = null
	if alternatives.size() > 1:
		selection = OptionButton.new()
		selection.name = "NodeEventAlternative"
		if context.get("mobile",false): selection.custom_minimum_size.y=44
		selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for item in alternatives: selection.add_item(str(item.label))
		selection.select(index)
	var cost := costs(option)
	var entry := {
		"id": option.get("id", ""),
		"name": option.name,
		"description": option.get("description", ""),
		"cost": cost,
		"command": "option",
		"args": {},
		"alternatives": alternatives,
		"selection": selection,
		"cell": "",
	}
	add_entry(option.name+(" · "+cost if cost != "" else ""), entry)
	entry.button.name = "NodeEventOption"
	entry.button.disabled = str(alternatives[index].get("reason", "")) != ""
	entry.button.tooltip_text = option.get("description", "")+"\n"+str(alternatives[index].get("reason", ""))
	if selection != null:
		selection.item_selected.connect(func(selected):
			entry.button.disabled = str(alternatives[selected].get("reason", "")) != ""
			entry.button.tooltip_text = option.get("description", "")+"\n"+str(alternatives[selected].get("reason", ""))
			if preselect_key == entry.key: set_preselect(entry.key))

func add_entry(label: String, entry: Dictionary) -> void:
	entry.key = "%s#%d" % [str(entry.get("id", "option")), entries.size()]
	entry.label = label
	var row := VBoxContainer.new()
	row.name = "NodeEventOptionRow"
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_panel.add_child(row)
	if entry.get("selection") != null: row.add_child(entry.selection)
	var button := build_direct_button(row, label, func(): press(entry))
	entry.button = button
	entries.append(entry)
	widgets.append(row)

## First click selects, the same option clicked again confirms.
func press(entry: Dictionary) -> void:
	if entry.button.disabled: return
	if preselect_key == entry.key: commit(entry); return
	set_preselect(entry.key)

func commit(entry: Dictionary) -> void:
	var args: Dictionary = entry.get("args", {}).duplicate(true)
	var alternatives: Array = entry.get("alternatives", [])
	if not alternatives.is_empty():
		var picked: Dictionary = alternatives[alternative_index(entry)]
		if str(picked.get("reason", "")) != "": return
		args = picked.get("args", {}).duplicate(true)
	send(str(entry.get("command", "option")), args)

func set_preselect(key: String) -> void:
	preselect_key = key
	var active: Dictionary = {}
	for entry in entries:
		if entry.key == key: active = entry; break
	paint_options()
	paint_prose(active)
	highlight(active)

func cancel_preselect() -> void:
	set_preselect("")

func highlight(entry: Dictionary) -> void:
	if entry.is_empty(): request("event_target", ""); return
	var cell := entry_cell(entry)
	request("event_target", cell)

func alternative_index(entry: Dictionary) -> int:
	var selection: OptionButton = entry.get("selection", null)
	return selection.selected if selection != null else 0

func entry_cell(entry: Dictionary) -> String:
	var alternatives: Array = entry.get("alternatives", [])
	if not alternatives.is_empty():
		return str(alternatives[alternative_index(entry)].get("args", {}).get("cell", ""))
	return str(entry.get("cell", ""))

func paint_options() -> void:
	for entry in entries:
		var selected: bool = entry.key == preselect_key
		entry.button.text = "确认" if selected else entry.label
		entry.button.set_meta("surge_primary", selected)
		if entry.button.has_node("SurgeTextButtonArt"): entry.button.get_node("SurgeTextButtonArt").queue_redraw()
	paint_header()

func paint_header() -> void:
	cancel_button.visible = not preselect_key.is_empty()

func paint_prose(active: Dictionary) -> void:
	for child in prose.get_children():
		prose.remove_child(child); child.queue_free()
	if active.is_empty():
		paint_lines(str(default_prose.get("eyebrow", "")), str(default_prose.get("headline", "")), default_prose.get("lines", []), str(default_prose.get("hint", "")))
		return
	var lines: Array = []
	var description := str(active.get("description", ""))
	if description != "": lines.append(description)
	var cost := str(active.get("cost", ""))
	if cost != "": lines.append("消耗："+cost)
	var selection: OptionButton = active.get("selection", null)
	var alternatives: Array = active.get("alternatives", [])
	if selection != null and alternatives.size() > 1: lines.append("方式："+str(alternatives[selection.selected].label))
	paint_lines("预选选项", str(active.get("name", "")), lines, PRESELECT_HINT)

func paint_lines(eyebrow: String, headline: String, lines: Array, hint: String = "") -> void:
	if eyebrow != "":
		var tag := W.text(prose, eyebrow, 15, W.MUTED)
		tag.name = "NodeEventEyebrow"; tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	var title := W.text(prose, headline, 26, W.GOLD)
	title.name = "NodeEventHeadline"
	for line in lines:
		var paragraph := W.text(prose, str(line), 18, W.INK)
		paragraph.name = "NodeEventParagraph"
	var fill := Control.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prose.add_child(fill)
	if hint != "":
		var note := W.text(prose, hint, 14, W.MUTED)
		note.name = "NodeEventHint"

## Equal spacers keep every option on the same rhythm and remove the empty bottom.
func pack_options() -> void:
	for child in options_panel.get_children(): options_panel.remove_child(child)
	options_panel.add_child(spacer())
	for i in range(widgets.size()):
		options_panel.add_child(widgets[i])
		if i < widgets.size()-1: options_panel.add_child(spacer())
	options_panel.add_child(spacer())

func spacer() -> Control:
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.custom_minimum_size.y = 6
	return space
