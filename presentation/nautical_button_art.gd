@tool
extends Control
## Independent long/round decoration; native Button retains text and input.
const Frame=preload("res://presentation/nautical_frame.gd")
var round_button := false
static func apply(button: Button, circular: bool=false):
	for state in ["normal","hover","pressed","disabled","focus"]:
		var empty=StyleBoxEmpty.new()
		empty.content_margin_left=30 if not circular else 14
		empty.content_margin_right=empty.content_margin_left
		button.add_theme_stylebox_override(state,empty)
	button.add_theme_color_override("font_color",Color("f8e8c8"))
	button.add_theme_color_override("font_hover_color",Color("fff4dc"))
	button.add_theme_color_override("font_pressed_color",Color("fff4dc"))
	button.add_theme_color_override("font_disabled_color",Color("8b9496"))
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var art=load("res://presentation/nautical_button_art.gd").new()
	art.name="RoundButtonArtwork" if circular else "LongButtonArtwork"
	art.round_button=circular; art.show_behind_parent=true
	button.add_child(art); art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.mouse_entered.connect(art.queue_redraw); button.mouse_exited.connect(art.queue_redraw)
	button.button_down.connect(art.queue_redraw); button.button_up.connect(art.queue_redraw)
	button.focus_entered.connect(art.queue_redraw); button.focus_exited.connect(art.queue_redraw)
	button.draw.connect(art.queue_redraw)
func _ready():
	mouse_filter=MOUSE_FILTER_IGNORE; resized.connect(queue_redraw)
func _draw():
	var button=get_parent() as Button
	var gold=Color("edcd98") if button.is_hovered() or button.has_focus() else Color("dabb87")
	var blue=Color("11354c") if button.is_hovered() else Color("082639")
	if button.is_pressed(): blue=Color("183e50")
	if button.disabled: gold=Color("626d70"); blue=Color("112330")
	var center=size*.5
	if round_button:
		var r=minf(size.x,size.y)*.5-7
		draw_circle(center,r+5,Color("05141f"))
		draw_circle(center,r,blue)
		for inset in [0.0,11.0]: draw_arc(center,r-inset,0,TAU,128,gold,2 if inset==0 else 1,true)
		for angle in [0.0,PI*.5,PI,PI*1.5]:
			faceted_star(center+Vector2.RIGHT.rotated(angle)*(r-2),13,gold)
		for quadrant in range(4):
			var angle=PI*.5*quadrant+.35
			draw_arc(center,r-18,angle,angle+.88,24,Color("69869a"),2,true)
			for j in range(5): draw_circle(center+Vector2.RIGHT.rotated(angle+float(j)*.12)*(r-6),.9,gold)
	else:
		var r=Rect2(Vector2(7,5),size-Vector2(14,10))
		var style=StyleBoxFlat.new(); style.bg_color=blue; style.border_color=gold
		style.set_border_width_all(2); style.set_corner_radius_all(int(r.size.y*.5))
		draw_style_box(style,r)
		var inner=style.duplicate(); inner.bg_color=Color.TRANSPARENT; inner.border_color=Color("78898b"); inner.set_border_width_all(1)
		draw_style_box(inner,r.grow(-6))
		for x in [23.0,size.x-23.0]: faceted_star(Vector2(x,center.y),10,gold)
		for y in [7.0,size.y-7.0]:
			Frame.star(self,Vector2(center.x,y),5,gold)
			for side in [-1.0,1.0]: draw_line(Vector2(center.x+side*10,y),Vector2(center.x+side*(center.x-37),y),gold,1,true)

func faceted_star(p: Vector2, radius: float, gold: Color):
	Frame.star(self,p,radius+2,Color("04131f"))
	for i in range(4):
		var axis=Vector2.UP.rotated(i*PI*.5)
		var side=axis.rotated(PI*.5)*radius*.23
		var tip=p+axis*radius
		draw_colored_polygon(PackedVector2Array([p,tip,p+axis*radius*.23+side]),gold)
		draw_colored_polygon(PackedVector2Array([p,tip,p+axis*radius*.23-side]),gold.lightened(.3))
		draw_line(p,tip,Color("998365"),.65,true)
