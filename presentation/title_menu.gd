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
	poster=TextureRect.new(); poster.texture=load("res://assets/title_ui/lighthouse_poster.png")
	poster.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; poster.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.mouse_filter=MOUSE_FILTER_IGNORE; add_child(poster)
	background=VideoStreamPlayer.new(); background.expand=true
	background.stream=load("res://assets/title_ui/lighthouse_loop.ogv"); background.loop=true
	background.volume_db=-80; background.mouse_filter=MOUSE_FILTER_IGNORE
	background.modulate.a=1.0
	add_child(background); background.play()
	resized.connect(_reflow); _reflow()
func create(view: Dictionary, with_background: bool = true) -> void:
	clip_contents=true
	if with_background:
		create_background()
	else:
		if is_inside_tree():
			for p in get_tree().root.find_children("*","VideoStreamPlayer",true,false): background=p; break
		else:
			tree_entered.connect(func():
				if background==null:
					for p in get_tree().root.find_children("*","VideoStreamPlayer",true,false): background=p; break
			, CONNECT_ONE_SHOT)
	composition=Control.new(); composition.size=REFERENCE; composition.mouse_filter=MOUSE_FILTER_PASS; add_child(composition)
	var shade:=TextureRect.new()
	shade.name="MenuBoard"
	shade.texture=load("res://assets/title_ui/menu_board_source.png")
	shade.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	shade.size=REFERENCE; shade.mouse_filter=MOUSE_FILTER_IGNORE
	shade.visible=false
	composition.add_child(shade)
	var logo:=TextureRect.new(); logo.name="TitleLogo"; logo.texture=load("res://assets/title_ui/deep_surge_logo_v3.png")
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position=Vector2(140,80); logo.size=Vector2(650,487.5)
	logo.mouse_filter=MOUSE_FILTER_IGNORE; logo.visible=true
	composition.add_child(logo)
	var logo_backdrop:=preload("res://presentation/title_logo_backdrop.gd").new()
	logo_backdrop.name="TitleLogoBackdrop"; logo_backdrop.show_behind_parent=true
	logo.add_child(logo_backdrop); logo_backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var frame:=preload("res://presentation/title_frame.gd").new(); frame.name="TitleFrame"
	add_child(frame); frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var edge_material:=ShaderMaterial.new()
	edge_material.shader=load("res://assets/shaders/title_button_edge.gdshader")
	for i in range(6):
		dark.append(load("res://assets/title_ui/"+FILES[i]+"_dark.png"))
		light.append(load("res://assets/title_ui/"+FILES[i]+"_light.png"))
		var b:=TextureButton.new(); b.name="Title_"+ACTIONS[i]
		var layout: Dictionary = {
			"start": {"x": 1125.0, "y": 161.5, "width": 435.0, "height": 145.0},
			"continue": {"x": 1141.0, "y": 281.0, "width": 405.0, "height": 135.0},
			"journal": {"x": 1141.0, "y": 374.0, "width": 405.0, "height": 135.0},
			"shop": {"x": 1141.0, "y": 467.0, "width": 405.0, "height": 135.0},
			"recall": {"x": 1141.0, "y": 560.0, "width": 405.0, "height": 135.0},
			"quit": {"x": 1141.0, "y": 653.0, "width": 405.0, "height": 135.0}
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
		composition.scale=Vector2.ONE*fit; composition.position=Vector2.ZERO
		composition.size=size/fit
		for b in buttons:
			b.position.x=composition.size.x-REFERENCE.x+(1125.0 if b==buttons[0] else 1141.0)-(b.size.x-(435.0 if b==buttons[0] else 405.0))*0.5
	if background!=null:
		var cover:=maxf(size.x/2240.0,size.y/960.0)
		background.size=Vector2(2240,960)*cover; background.position=(size-background.size)*0.5
		if poster!=null: poster.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
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
