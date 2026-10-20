extends CanvasLayer
## Read-only receipt for an already committed departure; never dispatches rules.
const HOLD_SECONDS:=2.4
const FADE_SECONDS:=0.25
func configure(before: Dictionary, after: Dictionary, failure: String = "") -> void:
	name="DepartureNotice"; layer=110
	var center:=CenterContainer.new(); center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(center); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel:=PanelContainer.new(); panel.name="DepartureNoticePanel"
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; center.add_child(panel)
	var style:=StyleBoxFlat.new(); style.bg_color=Color(0.025,0.04,0.06,0.82)
	style.content_margin_left=24; style.content_margin_right=24
	style.content_margin_top=16; style.content_margin_bottom=16
	panel.add_theme_stylebox_override("panel",style)
	var label:=Label.new(); label.name="DepartureNoticeText"
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",32)
	label.add_theme_color_override("font_color",Color(0.98,0.96,0.91))
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var lines:=PackedStringArray(["航行结算"])
	for entry in [["hunger","饱食度"],["hydration","水分"],["hp","生命值"]]:
		var loss:=maxi(0,int(before.get(entry[0],0))-int(after.get(entry[0],0)))
		lines.append("%s −%d（剩余 %d）" % [entry[1],loss,int(after.get(entry[0],0))])
	if not failure.is_empty():
		lines.append("游戏失败 · "+("精神归零，迷失潮声" if failure=="mad" else "生命归零，沉入深潮"))
	label.text="\n".join(lines); panel.add_child(label)
	var tween:=create_tween(); tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(panel,"modulate:a",0.0,FADE_SECONDS)
	tween.tween_callback(queue_free)

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		queue_free()
