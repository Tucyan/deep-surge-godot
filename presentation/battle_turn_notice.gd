extends CanvasLayer

const HOLD_SECONDS:=2.0

func configure(turn: int) -> void:
	name="BattleTurnNotice"; layer=111
	var center:=CenterContainer.new(); center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(center); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel:=PanelContainer.new(); panel.name="BattleTurnNoticePanel"
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; center.add_child(panel)
	var style:=StyleBoxFlat.new(); style.bg_color=Color(0.025,0.04,0.06,0.84)
	style.content_margin_left=32; style.content_margin_right=32
	style.content_margin_top=20; style.content_margin_bottom=20
	panel.add_theme_stylebox_override("panel",style)
	var label:=Label.new(); label.name="BattleTurnNoticeText"
	label.text="第 %d 回合" % turn
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",32)
	label.add_theme_color_override("font_color",Color(0.98,0.96,0.91))
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	get_tree().create_timer(HOLD_SECONDS).timeout.connect(queue_free)

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		queue_free()
