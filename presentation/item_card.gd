extends CenterContainer
## Art, frame and category emblems are stable AssetIds. This control emits no rules.
const W = preload("res://presentation/widgets.gd")
func create(assets: RefCounted, card: Dictionary, action_title: String, callback: Callable, width: float, height: float, disabled: bool = false) -> void:
	custom_minimum_size = Vector2(width,height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := Control.new(); frame.custom_minimum_size = Vector2(height*0.651,height)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(frame)
	var background := TextureRect.new(); background.texture = assets.texture("ui.card.front")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var kind: String = card.definition.kind
	var category: String = "combat" if kind in ["combat","negative"] else ("survival" if kind == "survival" else "material")
	var emblem := TextureRect.new(); emblem.texture = assets.texture("ui.card.type."+category)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(emblem); place(emblem,Vector4(0.08,0.05,0.24,0.15))
	if card.definition.cost > 0:
		var price := W.text(frame,"%d" % card.definition.cost,13,W.INK); price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE; place(price,Vector4(0.78,0.055,0.91,0.15))
	var art := TextureRect.new(); art.texture = assets.texture("card."+card.id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art); place(art,Vector4(0.17,0.16,0.83,0.64))
	var name_label := W.text(frame,card.definition.name,14,Color("24333e")); name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF; name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(name_label,Vector4(0.12,0.735,0.88,0.84))
	if int(card.get("stack_count",1))>1:
		var badge := Label.new(); badge.name="StackQuantity"; badge.text="×%d" % card.stack_count
		badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; badge.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter=Control.MOUSE_FILTER_IGNORE; badge.add_theme_font_size_override("font_size",19)
		badge.add_theme_color_override("font_color",Color("fff0c4"))
		var badge_style := StyleBoxFlat.new(); badge_style.bg_color=Color("173340"); badge_style.border_color=W.GOLD
		badge_style.set_border_width_all(1); badge_style.set_corner_radius_all(4); badge.add_theme_stylebox_override("normal",badge_style)
		frame.add_child(badge); place(badge,Vector4(0.60,0.53,0.94,0.67))
	var hint: String = "弃置" if action_title.begins_with("弃置") else ("使用" if action_title.begins_with("使用") else "查看")
	var hint_label := W.text(frame,hint,11,Color("314654")); hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; place(hint_label,Vector4(0.12,0.66,0.88,0.73))
	var button := W.button(frame,action_title,callback,disabled,card.definition.description)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The title remains available to accessibility/UI tests; visual text is above.
	for state in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new(); focus.bg_color = Color.TRANSPARENT; focus.border_color = W.GOLD; focus.set_border_width_all(1); focus.set_corner_radius_all(3)
	button.add_theme_stylebox_override("focus",focus)
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]: button.add_theme_color_override(state,Color.TRANSPARENT)
	button.clip_text = true
	button.mouse_entered.connect(func(): background.modulate = Color(1.12,1.12,1.12) if not disabled else Color(0.75,0.75,0.75))
	button.mouse_exited.connect(func(): background.modulate = Color.WHITE if not disabled else Color(0.75,0.75,0.75))
	if disabled: background.modulate = Color(0.75,0.75,0.75)

func place(control: Control, anchors: Vector4) -> void:
	control.anchor_left = anchors.x; control.anchor_top = anchors.y; control.anchor_right = anchors.z; control.anchor_bottom = anchors.w
	control.offset_left = 0; control.offset_top = 0; control.offset_right = 0; control.offset_bottom = 0
