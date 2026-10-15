extends "res://pages/flow_base.gd"
func build() -> void:
	var title=preload("res://presentation/title_menu.gd").new()
	title.size_flags_vertical=Control.SIZE_EXPAND_FILL; title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(title); title.create(context,false)
	var settings:=W.button(title,"设置",func(): request("local_panel","settings"))
	settings.name="HomeSettings"; settings.custom_minimum_size=Vector2(112,48)
	settings.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings.offset_left=-136; settings.offset_right=-24; settings.offset_top=24; settings.offset_bottom=72
	settings.add_theme_font_size_override("font_size",22)
	title.menu_action.connect(_title_action.bind(title))
func _title_action(id: String, title: Control) -> void:
	match id:
		"start": select_mode(title)
		"continue": send("resume")
		"journal": send("panel",{"id":"encyclopedia"})
		"shop": send("panel",{"id":"meta_shop"})
		"recall": request("local_panel","recall")
		"quit": request("quit")
func select_mode(title: Control) -> void:
	title.composition.visible=false
	var center:=CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); title.add_child(center)
	var box:=W.panel(center,Vector2(520,260))
	W.text(box,"选择航程",30,W.GOLD)
	W.button(box,"剧情模式",func(): request("setup","story"))
	W.button(box,"挑战模式",func(): request("setup","challenge"))
	W.corner_close(box.get_parent(),func(): center.queue_free(); title.composition.visible=true)
