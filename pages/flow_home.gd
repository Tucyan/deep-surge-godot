extends "res://pages/flow_base.gd"
func build() -> void:
	var title=preload("res://presentation/title_menu.gd").new()
	title.name="HomeMenu"
	title.size_flags_vertical=Control.SIZE_EXPAND_FILL; title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(title); title.create(context,false)
	var settings:=W.button(title,"设置",func(): request("local_panel","settings"))
	settings.name="HomeSettings"; settings.custom_minimum_size=Vector2(160,64) if context.get("mobile",false) else Vector2(112,48)
	settings.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings.offset_left=-184 if context.get("mobile",false) else -136; settings.offset_right=-24; settings.offset_top=24; settings.offset_bottom=88 if context.get("mobile",false) else 72
	settings.add_theme_font_size_override("font_size",22)
	title.menu_action.connect(_title_action.bind(title))
func _title_action(id: String, title: Control) -> void:
	match id:
		"start":
			var meta: Dictionary = context.get("meta",{})
			if not meta.get("tutorial_prompt_handled",false) and not meta.get("tutorial_done",false) and not context.get("has_run",false):
				tutorial_prompt(title)
			else: select_mode(title)
		"continue": select_mode(title)
		"journal": send("panel",{"id":"encyclopedia"})
		"shop": send("panel",{"id":"meta_shop"})
		"recall": request("local_panel","recall")
		"quit": request("quit")
func tutorial_prompt(title: Control) -> void:
	title.composition.visible = false
	var center := CenterContainer.new(); center.name = "TutorialPrompt"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); title.add_child(center)
	var box := W.panel(center,Vector2(520,260))
	W.text(box,"是否进入新手教学？",30,W.GOLD)
	W.text(box,"从选择初始卡牌开始，学习航行、生存、制造与战斗。",18,W.MUTED)
	var enter := W.button(box,"进入新手教学",func(): request("tutorial_choice","enter"))
	enter.name = "EnterTutorial"; W.primary(enter)
	var skip := W.button(box,"跳过教学",func():
		title.remove_child(center); center.queue_free()
		tutorial_skip_notice(title))
	skip.name = "SkipTutorial"
	W.corner_close(box.get_parent(),func(): center.queue_free(); title.composition.visible = true)
func tutorial_skip_notice(title: Control) -> void:
	var center := CenterContainer.new(); center.name = "TutorialSkipNotice"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); title.add_child(center)
	var box := W.panel(center,Vector2(520,260))
	W.text(box,"已跳过新手教学",30,W.GOLD)
	W.text(box,"之后可以在「挑战模式」的难度选择中，选择「新手教程」重新进入教学。",18,W.MUTED)
	var confirm := W.button(box,"知道了，选择模式",func(): request("tutorial_choice","skip_modes"))
	confirm.name = "ConfirmTutorialSkip"; W.primary(confirm)
func select_mode(title: Control) -> void:
	title.composition.visible=false
	var center:=CenterContainer.new(); center.name="ModeChoice"; center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); title.add_child(center)
	var box:=W.panel(center,Vector2(520,260))
	W.text(box,"选择航程",30,W.GOLD)
	W.button(box,"剧情模式",func():
		center.queue_free(); title.composition.visible=true
		request("narrative_choose",""))
	var challenge := W.button(box,"挑战模式",func(): request("setup","challenge"))
	challenge.name = "ChallengeMode"
	if context.get("active", false):
		W.button(box,"返回当前航程",func(): send("resume"))
	W.corner_close(box.get_parent(),func(): center.queue_free(); title.composition.visible=true)
