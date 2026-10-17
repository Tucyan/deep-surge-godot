extends Control
var kind := "help"
func _ready():
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw():
	var p=size*.5
	var gold=Color("f1dfbc") if get_parent().is_hovered() else Color("d8c9aa")
	if kind=="home":
		draw_polyline(PackedVector2Array([p+Vector2(-13,0),p+Vector2(0,-12),p+Vector2(13,0)]),gold,3,true)
		draw_polyline(PackedVector2Array([p+Vector2(-10,-1),p+Vector2(-10,13),p+Vector2(-3,13),p+Vector2(-3,4),p+Vector2(4,4),p+Vector2(4,13),p+Vector2(10,13),p+Vector2(10,-1)]),gold,2,true)
	elif kind=="settings":
		for i in range(8):
			var d=Vector2.RIGHT.rotated(i*TAU/8)
			draw_line(p+d*7,p+d*14,gold,5,true)
		draw_arc(p,9,0,TAU,32,gold,4,true)
		draw_circle(p,4,Color("071722"))
	else:
		draw_arc(p,12,0,TAU,32,gold,1,true)
		draw_string(get_theme_font("font"),p+Vector2(-5,7),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,20,gold)
