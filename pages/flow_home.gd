extends "res://pages/flow_base.gd"
func build() -> void:
	var title=preload("res://presentation/title_menu.gd").new()
	title.size_flags_vertical=Control.SIZE_EXPAND_FILL; title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(title); title.create(context)
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
	W.button(box,"返回",func(): center.queue_free(); title.composition.visible=true)
