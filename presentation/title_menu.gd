extends Control
signal menu_action(action: String)
const REFERENCE := Vector2(1672,941)
const BUTTON_GROUP_CENTER_Y := (161.5 + 653.0 + 135.0) * 0.5
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
var building:=false
func create_background() -> void:
	clip_contents=true
	var fill:=ColorRect.new(); fill.name="TitleBlackFill"; fill.color=Color.BLACK
	fill.mouse_filter=MOUSE_FILTER_IGNORE; add_child(fill)
	fill.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	poster=TextureRect.new(); poster.texture=load("res://assets/title_ui/lighthouse_poster.png")
	poster.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; poster.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	poster.mouse_filter=MOUSE_FILTER_IGNORE; add_child(poster)
	background=VideoStreamPlayer.new(); background.expand=true
	background.stream=load("res://assets/title_ui/lighthouse_loop.ogv"); background.loop=true
	background.volume_db=-80; background.mouse_filter=MOUSE_FILTER_IGNORE
	background.modulate.a=1.0
	add_child(background); background.play()
	resized.connect(_reflow); _reflow()
func create(view: Dictionary, with_background: bool = true) -> void:
	building=true
	set_meta("mobile_ui",bool(view.get("mobile",false)))
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
		var ui_zoom: float=view.get("ui_scale",1.0)
		b.size=Vector2(layout.width,layout.height)*ui_zoom
		# Scale row spacing with the artwork so 125% does not crowd adjacent buttons.
		var center := Vector2(layout.x + layout.width * 0.5, layout.y + layout.height * 0.5)
		center.y = REFERENCE.y * 0.5 + (center.y - BUTTON_GROUP_CENTER_Y) * ui_zoom
		b.position = center - b.size * 0.5
		b.material=edge_material
		b.ignore_texture_size=true; b.stretch_mode=TextureButton.STRETCH_SCALE
		b.pivot_offset=b.size*Vector2(0.5,0.5); b.focus_mode=FOCUS_ALL
		b.z_index=6-i
		b.mouse_default_cursor_shape=CURSOR_POINTING_HAND
		b.texture_normal=dark[i]; b.texture_hover=dark[i] if view.get("mobile",false) else light[i]; b.texture_pressed=light[i]; b.texture_focused=light[i]
		var hit_mask:=BitMap.new(); hit_mask.create_from_image_alpha(dark[i].get_image(),0.15)
		b.texture_click_mask=hit_mask
		b.disabled=i==1 and not view.get("can_resume",view.active) and not view.get("has_story_saves", false)
		if b.disabled:
			b.modulate=Color(0.62,0.66,0.72,0.75)
			b.tooltip_text="已有航程，请继续游戏" if i==0 else "暂无可继续的存档"
		if not view.get("mobile",false):
			b.mouse_entered.connect(_hover.bind(i,true)); b.mouse_exited.connect(_hover.bind(i,false))
		b.focus_entered.connect(_hover.bind(i,true)); b.focus_exited.connect(_hover.bind(i,false))
		b.pressed.connect(func(): menu_action.emit(ACTIONS[i]))
		composition.add_child(b); buttons.append(b)
		# Transition scheduling only: keep the same art/mask work, let the loading
		# layer render between buttons instead of covering one long frozen frame.
		if view.get("loading_transition",false): await get_tree().process_frame
	if view.active: selected=1
	_update_highlight()
	if not resized.is_connected(_reflow): resized.connect(_reflow)
	_reflow()
	building=false
func _reflow() -> void:
	if size.x<1 or size.y<1:return
	if composition!=null:
		var fit:=minf(size.x/REFERENCE.x,size.y/REFERENCE.y)
		# Use the same centered contain transform as the title artwork, including black bars.
		composition.scale=Vector2.ONE*fit
		composition.size=REFERENCE
		composition.position=(size-REFERENCE*fit)*0.5
	if background!=null:
		var fit:=minf(size.x/2560.0,size.y/1440.0)
		background.size=Vector2(2560,1440)*fit; background.position=(size-background.size)*0.5
		if poster!=null:
			poster.size=background.size; poster.position=background.position
func _update_highlight() -> void:
	for i in range(buttons.size()): buttons[i].texture_normal=light[i] if i==selected and not buttons[i].disabled else dark[i]
func _hover(index: int, active: bool) -> void:
	if get_meta("mobile_ui",false): return
	if buttons[index].disabled:return
	if active: selected=index
	_update_highlight()
	var b:=buttons[index]
	var enlarged:=active or b.has_focus() or b.is_hovered()
	if _tweens.has(index) and _tweens[index].is_valid(): _tweens[index].kill()
	var tween:=create_tween(); _tweens[index]=tween
	tween.tween_property(b,"scale",Vector2.ONE*(1.01 if enlarged else 1.0),0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	b.z_index=10 if enlarged else 6-index
