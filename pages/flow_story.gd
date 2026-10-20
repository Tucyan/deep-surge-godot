extends "res://pages/flow_base.gd"
## Node event page: illustration | prose | options.
## Options are two-step (select -> confirm); advance/skip/result stay one-step.
const VoyagePage = preload("res://pages/voyage_hud.gd")
const Difficulty = preload("res://core/difficulty_rules.gd")

const COLUMN_GAP := 20.0
const CHOICES_WIDTH := 332.0
## Mobile gives the illustration the larger share of the row; the prose column
## only keeps a readable minimum instead of absorbing everything that is left.
const ART_MOBILE_SHARE := 0.35
const ART_MOBILE_MIN_WIDTH := 220.0
const ART_MOBILE_MAX_WIDTH := 600.0
const PROSE_MOBILE_MIN_WIDTH := 340.0
const ART_DEFAULT := "opening.image.05"
## Presentation-only fallback; authored nodes may supply a registered art ID.
const ART_BY_KIND := {
	"ruin": "opening.image.02",
	"shop": "opening.image.03",
	"exchange": "opening.image.04",
	"environment": "opening.image.04",
	"battle": "opening.image.04",
}
const PRESELECT_HINT := "再次点击该选项即可确认；也可点右上角“取消选择”返回。"
const PRESELECT_HINT_MOBILE := "再次点击该选项即可确认；也可点选项右侧的“取消选择”返回。"
## Merged phone layout: the illustration is the panel backdrop and the event
## text sits on a small translucent plate. Phones use it by default; the
## desktop keeps the three-column layout.
const MERGED_PLATE_SHARE := 0.42
const MERGED_PLATE_WIDE_SHARE := 0.62
const MERGED_PLATE_MAX_HEIGHT_RATIO := 0.52
const MERGED_PLATE_MIN_WIDTH := 300.0
const MERGED_PLATE_MAX_WIDTH := 760.0
const MERGED_MARGIN_X := 26.0
const MERGED_MARGIN_Y := 22.0
const MERGED_PLATE_ALPHA := 0.70
## Inset of the merged event page: the panel owns more of the screen.
const MERGED_INSET_X := 20.0
const MERGED_INSET_TOP := 64.0
const MERGED_INSET_TOP_TUTORIAL := 108.0
const MERGED_INSET_BOTTOM := 12.0

var art_view: TextureRect
var art_column: Control
var plate: PanelContainer
var plate_holder: Control
var plate_fade: TextureRect
var merged_scroll: ScrollContainer
## True while a long prose keeps the plate at its wide width.
var plate_wide := false
var options_frame: Control
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
	if context.get("mobile",false): columns.add_theme_constant_override("separation",12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.clip_contents = true
	add_child(columns)
	if merged_art():
		build_merged_column(columns)
	else:
		build_art_column(columns)
		var prose_column := build_frame_column(columns, 1.06, "NodeEventProse")
		build_prose_area(prose_column)
	var choices_column := build_frame_column(columns, 0.0, "NodeEventOptions")
	options_frame = choices_column.get_parent() as Control
	choices_column.custom_minimum_size.x = CHOICES_WIDTH
	if context.get("mobile",false):
		choices_column.custom_minimum_size.x=420
	choices_column.size_flags_horizontal = Control.SIZE_FILL
	# Desktop keeps the header row; phones drop it so the buttons inherit its height
	# and 取消选择 moves inside the preselected option instead.
	if not context.get("mobile",false): build_options_header(choices_column)
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
	if merged_art(): fit_merged_plate.call_deferred()
	elif context.get("mobile",false): fit_art_width.call_deferred()

## Desktop header: 请做出选择 on the left, 取消选择 on the right. The row keeps its
## height in every state so showing 取消选择 never moves the options.
func build_options_header(parent: Node) -> void:
	options_header = HBoxContainer.new()
	options_header.name = "NodeEventOptionsHeader"
	options_header.add_theme_constant_override("separation", 6)
	options_header.custom_minimum_size.y = 34
	parent.add_child(options_header)
	var prompt := W.text(options_header, "请做出选择", 14, W.MUTED)
	prompt.name = "NodeEventOptionsHint"
	prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt.size_flags_horizontal = Control.SIZE_FILL
	var push := Control.new()
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_header.add_child(push)
	cancel_button = cancel_label()
	options_header.add_child(cancel_button)
	cancel_button.name = "CancelPreselect"
	cancel_button.custom_minimum_size = Vector2(136, 34)
	cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_END

## Plain red text action: bypasses the shared decorative button artwork.
func cancel_label() -> Button:
	var button := Button.new()
	button.text = "取消选择"
	button.pressed.connect(cancel_preselect)
	button.flat = true
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, Color("ef7777"))
	button.tooltip_text = "回到事件说明，不提交选项"
	button.add_theme_font_size_override("font_size", 14)
	return button

## Phones only: 取消选择 sits at the right end of the preselected option, which
## frees the header row for one more visible choice.
func build_inline_cancel(option: Button) -> Button:
	var button := cancel_label()
	button.name = "InlineCancelPreselect"
	button.add_theme_font_size_override("font_size", 18)
	button.focus_mode = Control.FOCUS_NONE
	button.visible = false
	option.add_child(button)
	button.anchor_left = 1.0; button.anchor_right = 1.0
	button.anchor_top = 0.5; button.anchor_bottom = 0.5
	# Keep clear of the decorative diamond on the option's right edge.
	button.offset_left = -194; button.offset_right = -70
	button.offset_top = -28; button.offset_bottom = 28
	return button

func build_art_column(columns: Node) -> void:
	var frame := preload("res://presentation/hud_frame.gd").new()
	frame.name = "NodeEventArt"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 0.94
	if context.get("mobile",false):
		# Phones give the illustration a share of the row instead of hiding it.
		frame.size_flags_horizontal = Control.SIZE_FILL
		frame.size_flags_stretch_ratio = 1.0
		frame.custom_minimum_size.x = ART_MOBILE_MIN_WIDTH
		art_column = frame
		columns.resized.connect(fit_art_width)
	var style: StyleBoxFlat = VoyagePage.compact_style()
	style.bg_color = Color(0.02,0.045,0.065,0.96)
	style.content_margin_left = 8; style.content_margin_right = 8
	style.content_margin_top = 8; style.content_margin_bottom = 8
	frame.add_theme_stylebox_override("panel", style)
	columns.add_child(frame)
	art_view = TextureRect.new()
	art_view.name = "NodeEventIllustration"
	art_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Every illustration keeps its authored aspect and stays fully visible; the
	# column is taller than a landscape still, so the leftover space becomes
	# dark margin above and below instead of a cropped picture.
	art_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art_view)

## Mobile only: the illustration owns its share of the row so the prose column
## gives room back to the art instead of eating everything the options leave.
## The prose keeps a readable minimum, so a narrow row shrinks the art first.
func fit_art_width() -> void:
	if art_column == null or not is_instance_valid(art_column): return
	var columns := art_column.get_parent() as Control
	if columns == null: return
	var target := clampf(columns.size.x * ART_MOBILE_SHARE, ART_MOBILE_MIN_WIDTH, ART_MOBILE_MAX_WIDTH)
	if is_instance_valid(options_frame):
		var gaps := float(columns.get_theme_constant("separation")) * 2.0
		var free := columns.size.x - options_frame.get_combined_minimum_size().x - gaps
		target = minf(target, maxf(free - PROSE_MOBILE_MIN_WIDTH, ART_MOBILE_MIN_WIDTH))
	if is_equal_approx(art_column.custom_minimum_size.x, target): return
	art_column.custom_minimum_size.x = target

## Compact plate keeps the picture visible: the text block hugs its content and
## never grows past the panel, so long prose scrolls instead of covering the art.
func build_merged_column(columns: Node) -> void:
	var frame := preload("res://presentation/hud_frame.gd").new()
	frame.name = "NodeEventArt"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 1.0
	frame.custom_minimum_size.x = MERGED_PLATE_MIN_WIDTH + MERGED_MARGIN_X*2.0
	var style: StyleBoxFlat = VoyagePage.compact_style()
	style.bg_color = Color(0.02,0.045,0.065,0.96)
	# The illustration is a backdrop, so it reaches the frame edge.
	style.content_margin_left = 0; style.content_margin_right = 0
	style.content_margin_top = 0; style.content_margin_bottom = 0
	frame.add_theme_stylebox_override("panel", style)
	columns.add_child(frame)
	art_column = frame
	art_view = TextureRect.new()
	art_view.name = "NodeEventIllustration"
	art_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art_view)
	var overlay := MarginContainer.new()
	overlay.name = "NodeEventArtOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_constant_override("margin_left", int(MERGED_MARGIN_X))
	overlay.add_theme_constant_override("margin_right", int(MERGED_MARGIN_X))
	overlay.add_theme_constant_override("margin_top", int(MERGED_MARGIN_Y))
	overlay.add_theme_constant_override("margin_bottom", int(MERGED_MARGIN_Y))
	frame.add_child(overlay)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(row)
	plate = PanelContainer.new()
	plate.name = "NodeEventProse"
	# Bottom-left keeps the plate clear of the round utility strip that stays
	# above the event surface (treasure/view buttons at the panel's left edge).
	plate.size_flags_vertical = Control.SIZE_SHRINK_END
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.015,0.035,0.05,MERGED_PLATE_ALPHA)
	plate_style.set_corner_radius_all(10)
	plate_style.set_border_width_all(1)
	plate_style.border_color = Color(1,1,1,0.10)
	plate_style.content_margin_left = 18; plate_style.content_margin_right = 18
	plate_style.content_margin_top = 14; plate_style.content_margin_bottom = 14
	plate.add_theme_stylebox_override("panel", plate_style)
	row.add_child(plate)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	plate_holder = Control.new()
	plate_holder.name = "NodeEventProseHolder"
	plate.add_child(plate_holder)
	build_prose_area(plate_holder)
	merged_scroll = plate.find_child("NodeEventProseScroll", true, false) as ScrollContainer
	if merged_scroll != null:
		merged_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# The prose keeps its own height inside the plate, so a long text scrolls
		# instead of being clipped by the plate. Phones scroll with a finger, so
		# no scrollbar is drawn here.
		prose.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		merged_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	plate_fade = TextureRect.new()
	plate_fade.name = "NodeEventProseFade"
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.015,0.035,0.05,0.0))
	gradient.set_color(1, Color(0.015,0.035,0.05,0.95))
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = gradient
	fade_texture.fill_from = Vector2(0,0)
	fade_texture.fill_to = Vector2(0,1)
	fade_texture.width = 8; fade_texture.height = 64
	plate_fade.texture = fade_texture
	plate_fade.stretch_mode = TextureRect.STRETCH_SCALE
	plate_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	plate_fade.offset_top = -34
	plate_fade.visible = false
	plate_holder.add_child(plate_fade)
	frame.resized.connect(fit_merged_plate)

## One decision for the plate: short prose keeps the narrow plate, long prose
## widens it once, and anything longer than the cap scrolls inside so the
## picture keeps most of the panel.
func fit_merged_plate() -> void:
	if plate == null or not is_instance_valid(plate): return
	if art_column == null or not is_instance_valid(art_column): return
	if plate_holder == null or not is_instance_valid(plate_holder) or prose == null: return
	var limit: float = maxf(120.0, art_column.size.y * MERGED_PLATE_MAX_HEIGHT_RATIO)
	var needed: float = prose.get_combined_minimum_size().y
	var base := clampf(art_column.size.x*MERGED_PLATE_SHARE, MERGED_PLATE_MIN_WIDTH, MERGED_PLATE_MAX_WIDTH)
	var wide := clampf(art_column.size.x*MERGED_PLATE_WIDE_SHARE, MERGED_PLATE_MIN_WIDTH, MERGED_PLATE_MAX_WIDTH)
	if needed > limit:
		if not plate_wide and wide > base:
			plate_wide = true
			plate.custom_minimum_size.x = wide
			fit_merged_plate.call_deferred()
			return
		plate_holder.custom_minimum_size.y = limit
		if plate_fade != null and is_instance_valid(plate_fade): plate_fade.visible = true
		return
	if plate_wide:
		# The prose fits again: go back to the narrow plate.
		plate_wide = false
		plate.custom_minimum_size.x = base
		fit_merged_plate.call_deferred()
		return
	plate.custom_minimum_size.x = base
	plate_holder.custom_minimum_size.y = needed
	if plate_fade != null and is_instance_valid(plate_fade): plate_fade.visible = false

func build_prose_area(parent: Node) -> void:
	prose = VBoxContainer.new()
	prose.name = "NodeEventText"
	prose.add_theme_constant_override("separation", 10)
	prose.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var prose_scroll:=ScrollContainer.new()
	prose_scroll.name="NodeEventProseScroll"
	prose_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	prose_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	parent.add_child(prose_scroll)
	prose_scroll.add_child(prose)
	prose.size_flags_horizontal=Control.SIZE_EXPAND_FILL

## Phones run the merged layout; the desktop keeps the three columns.
static func merged_art_enabled(mobile: bool) -> bool:
	return mobile

func merged_art() -> bool:
	if context.has("merged_art"): return bool(context.merged_art)
	return merged_art_enabled(context.get("mobile",false))

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
	# Node art never crops in the column layout. As a merged backdrop it fills the
	# panel instead, which is fine because the shipped backdrops are 16:9.
	art_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if merged_art() else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_view.texture = visible_still(assets.texture(target), target)
	art_view.set_meta("asset_id", target)

## Opening stills ship with letterbox bars; scenes.json records the drawn region,
## so the illustration fills the column instead of showing black bands.
static func visible_still(texture: Texture2D, target: String) -> Texture2D:
	if texture == null or not target.begins_with("opening.image."): return texture
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/opening-intro/scenes.json"))
	if not data is Dictionary: return texture
	var scenes: Array = data.get("scenes", [])
	var index := int(target.get_slice(".", 2)) - 1
	if index < 0 or index >= scenes.size(): return texture
	var region: Array = scenes[index].get("display_region", [])
	if region.size() != 4: return texture
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = Rect2(region[0], region[1], region[2], region[3])
	cropped.filter_clip = true
	return cropped

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
				direct("迎战","fight")
				var protected: bool=node.get("kind","")=="ruin"
				var damage: int=int(catalog.entry("balance","combat").get("retreat_damage",4))
				var exit_label: String="离开·保护" if protected else "离开遭遇-%d生命" % damage
				var exit_hint: String="保护退出，没有战斗胜利奖励。" if protected else "离开直接扣除%d生命，可致死，没有战斗胜利奖励。" % damage
				if node.get("boss",false): exit_hint+="\n离开将结束本局，不能进入下一层。"
				var tutorial: bool=context.get("mode","")=="tutorial"
				direct(exit_label,"leave_encounter",{},tutorial,"教程不能离开遭遇。" if tutorial else exit_hint)
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
	button.add_theme_font_size_override("font_size", 20 if context.get("mobile",false) else 15)
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
	if context.get("mobile",false): entry.cancel = build_inline_cancel(button)
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
		if entry.get("cancel") != null: entry.cancel.visible = selected
		if entry.button.has_node("SurgeTextButtonArt"): entry.button.get_node("SurgeTextButtonArt").queue_redraw()
	paint_header()

func paint_header() -> void:
	if cancel_button == null: return
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
	paint_lines("预选选项", str(active.get("name", "")), lines, preselect_hint())

## The cancel action lives in a different place per platform.
func preselect_hint() -> String:
	return PRESELECT_HINT_MOBILE if context.get("mobile",false) else PRESELECT_HINT

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
	if merged_art(): fit_merged_plate.call_deferred()

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
