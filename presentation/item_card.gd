extends CenterContainer
## Art and frame use stable AssetIds. Native button retains action text for input/accessibility.
const W = preload("res://presentation/widgets.gd")
# Opaque frame edges in the current 1024x1536 ui.card.front (alpha > 128).
# Transparent image margins and the separate ground shadow do not occlude cards.
const FACE_HORIZONTAL_BOUNDS := Vector2(80.0/1024.0,945.0/1024.0)
func create(assets: RefCounted, card: Dictionary, action_title: String, callback: Callable, width: float, height: float, disabled: bool = false) -> void:
	custom_minimum_size = Vector2(width,height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := Control.new(); frame.custom_minimum_size = Vector2(height * (1024.0 / 1536.0), height)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(frame)
	var shadow := Panel.new(); shadow.name="CardGroundShadow"; shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shadow_style := StyleBoxFlat.new(); shadow_style.bg_color=Color.TRANSPARENT
	shadow_style.set_corner_radius_all(7); shadow_style.shadow_color=Color(0.015,0.025,0.04,0.28)
	shadow_style.shadow_size=7; shadow_style.shadow_offset=Vector2(1,5)
	shadow.add_theme_stylebox_override("panel",shadow_style)
	frame.add_child(shadow); place(shadow,Vector4(.08,.04,.92,.96))
	var background := TextureRect.new(); background.texture = assets.texture("ui.card.front")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if card.definition.cost > 0:
		var price := W.text(frame,"%d" % card.definition.cost,13,W.INK); price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE; place(price,Vector4(0.74,0.07,0.88,0.16))
	var art := TextureRect.new(); art.texture = assets.texture("card."+card.id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art); place(art,Vector4(0.18,0.18,0.82,0.62))
	var name_label := W.text(frame,card.definition.name,14,Color("24333e")); name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF; name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	place(name_label,Vector4(0.14,0.66,0.86,0.75))
	if int(card.get("stack_count",1))>1:
		var badge := Label.new(); badge.name="StackQuantity"; badge.text="×%d" % card.stack_count
		badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; badge.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter=Control.MOUSE_FILTER_IGNORE; badge.add_theme_font_size_override("font_size",23)
		var quantity_font := SystemFont.new()
		quantity_font.font_names=PackedStringArray(["Arial","Microsoft YaHei","sans-serif"])
		quantity_font.font_weight=800
		badge.add_theme_font_override("font",quantity_font)
		badge.add_theme_color_override("font_color",Color("fff0c4"))
		badge.add_theme_color_override("font_outline_color",Color("17232e"))
		badge.add_theme_constant_override("outline_size",6)
		frame.add_child(badge); place(badge,Vector4(0.46,0.52,0.86,0.68))
	var button := W.button(frame,action_title,callback,disabled,card.definition.description)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The title remains available to accessibility/UI tests; visual text is above.
	for state in ["normal","hover","pressed","disabled","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new(); focus.bg_color = Color.TRANSPARENT; focus.border_color = W.GOLD; focus.set_border_width_all(1); focus.set_corner_radius_all(3)
	button.add_theme_stylebox_override("focus",focus)
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]: button.add_theme_color_override(state,Color.TRANSPARENT)
	button.clip_text = true
	button.mouse_entered.connect(func(): background.modulate = Color(1.12,1.12,1.12) if not disabled and not W.TextButtonArt.uses_touch_ui(button) else (Color(0.75,0.75,0.75) if disabled else Color.WHITE))
	button.mouse_exited.connect(func(): background.modulate = Color.WHITE if not disabled else Color(0.75,0.75,0.75))
	if disabled: background.modulate = Color(0.75,0.75,0.75)

func place(control: Control, anchors: Vector4) -> void:
	control.anchor_left = anchors.x; control.anchor_top = anchors.y; control.anchor_right = anchors.z; control.anchor_bottom = anchors.w
	control.offset_left = 0; control.offset_top = 0; control.offset_right = 0; control.offset_bottom = 0
