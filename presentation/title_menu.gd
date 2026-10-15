extends Control
signal menu_action(action: String)
const REFERENCE := Vector2(1672,941)
const FILES := ["01_start_game","02_continue","03_journal","04_shop","05_rewind","06_exit"]
const ACTIONS := ["start","continue","journal","shop","recall","quit"]
var composition: Control
var background: VideoStreamPlayer
var poster: TextureRect
var buttons: Array[TextureButton] = []
var dark: Array[Texture2D] = []
var light: Array[Texture2D] = []
var layout_debug: Control
var selected := 0
var _tweens: Dictionary = {}
func create_background() -> void:
	clip_contents=true
	poster=TextureRect.new(); poster.texture=load("res://assets/title_ui/ocean_poster.png")
	poster.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; poster.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.mouse_filter=MOUSE_FILTER_IGNORE; add_child(poster)
	background=VideoStreamPlayer.new(); background.expand=true
	background.stream=load("res://assets/title_ui/ocean_loop.ogv"); background.loop=true
	background.volume_db=-80; background.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(background); background.play()
	resized.connect(_reflow); _reflow()
func create(view: Dictionary, with_background: bool = true) -> void:
	clip_contents=true
	if with_background: create_background()
	composition=Control.new(); composition.size=REFERENCE; composition.mouse_filter=MOUSE_FILTER_PASS; add_child(composition)
	var shade:=TextureRect.new()
	shade.name="MenuBoard"
	shade.texture=load("res://assets/title_ui/menu_board_source.png")
	shade.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	shade.size=REFERENCE; shade.mouse_filter=MOUSE_FILTER_IGNORE
	var board_material:=ShaderMaterial.new()
	board_material.shader=load("res://assets/shaders/title_board.gdshader")
	shade.material=board_material; composition.add_child(shade)
	var logo:=TextureRect.new(); logo.texture=load("res://assets/title_ui/07_deep_surge_logo.png")
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position=Vector2(850,-85); logo.size=Vector2(750,474.811828613281)
	logo.mouse_filter=MOUSE_FILTER_IGNORE; composition.add_child(logo)
	var edge_material:=ShaderMaterial.new()
	edge_material.shader=load("res://assets/shaders/title_button_edge.gdshader")
	for i in range(6):
		dark.append(load("res://assets/title_ui/"+FILES[i]+"_dark.png"))
		light.append(load("res://assets/title_ui/05_rewind_light_v4.png" if i==4 else "res://assets/title_ui/"+FILES[i]+"_light.png"))
		var b:=TextureButton.new(); b.name="Title_"+ACTIONS[i]
		var layout: Dictionary = {
			"start": {"x": 1050.0, "y": 280.0, "width": 450.0, "height": 151.363647460938},
			"continue": {"x": 1040.0, "y": 378.0, "width": 450.0, "height": 151.363647460938},
			"journal": {"x": 1038.0, "y": 476.0, "width": 450.0, "height": 151.363647460938},
			"shop": {"x": 1066.09997558594, "y": 580.0, "width": 450.0, "height": 151.363647460938},
			"recall": {"x": 1100.30004882813, "y": 678.0, "width": 450.0, "height": 151.363647460938},
			"quit": {"x": 1160.0, "y": 770.0, "width": 450.0, "height": 151.363647460938}
		}[ACTIONS[i]]
		b.position=Vector2(layout.x,layout.y)
		var ui_zoom: float=view.get("ui_scale",1.0)
		b.size=Vector2(layout.width,layout.height)*ui_zoom
		b.position-=Vector2(layout.width,layout.height)*(ui_zoom-1.0)*0.5
		b.material=edge_material
		b.ignore_texture_size=true; b.stretch_mode=TextureButton.STRETCH_SCALE
		b.pivot_offset=b.size*Vector2(0.5,0.5); b.focus_mode=FOCUS_ALL
		b.z_index=6-i
		b.mouse_default_cursor_shape=CURSOR_POINTING_HAND
		b.texture_normal=dark[i]; b.texture_hover=light[i]; b.texture_pressed=light[i]; b.texture_focused=light[i]
		var hit_mask:=BitMap.new(); hit_mask.create_from_image_alpha(dark[i].get_image(),0.15)
		b.texture_click_mask=hit_mask
		b.disabled=(i==0 and view.active) or (i==1 and not view.has_run)
		if b.disabled:
			b.modulate=Color(0.62,0.66,0.72,0.75)
			b.tooltip_text="已有航程，请继续游戏" if i==0 else "暂无可继续的存档"
		b.mouse_entered.connect(_hover.bind(i,true)); b.mouse_exited.connect(_hover.bind(i,false))
		b.focus_entered.connect(_hover.bind(i,true)); b.focus_exited.connect(_hover.bind(i,false))
		b.pressed.connect(func(): menu_action.emit(ACTIONS[i]))
		composition.add_child(b); buttons.append(b)
	if view.active: selected=1
	_update_highlight()
	if not resized.is_connected(_reflow): resized.connect(_reflow)
	_reflow()
func _reflow() -> void:
	if size.x<1 or size.y<1:return
	if composition!=null:
		var fit:=minf(size.x/REFERENCE.x,size.y/REFERENCE.y)
		composition.scale=Vector2.ONE*fit; composition.position=(size-REFERENCE*fit)*0.5
	if background!=null:
		var cover:=maxf(size.x/1704.0,size.y/960.0)
		background.size=Vector2(1704,960)*cover; background.position=(size-background.size)*0.5
		poster.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
func _update_highlight() -> void:
	for i in range(buttons.size()): buttons[i].texture_normal=light[i] if i==selected and not buttons[i].disabled else dark[i]
func _hover(index: int, active: bool) -> void:
	if buttons[index].disabled:return
	if active: selected=index
	_update_highlight()
	var b:=buttons[index]
	var enlarged:=active or b.has_focus() or b.is_hovered()
	if _tweens.has(index) and _tweens[index].is_valid(): _tweens[index].kill()
	var tween:=create_tween(); _tweens[index]=tween
	tween.tween_property(b,"scale",Vector2.ONE*(1.01 if enlarged else 1.0),0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	b.z_index=10 if enlarged else 6-index
