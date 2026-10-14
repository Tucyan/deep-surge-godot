extends Control
## Decorative asset: deterministic etched brass, double rules and rope hatching.
func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw():
	var gold := Color(0.65,0.57,0.36,0.7)
	draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),gold,false,1.0)
	draw_rect(Rect2(Vector2(5,5),size-Vector2(10,10)),Color(0.46,0.59,0.61,0.35),false,1.0)
	for x in range(14,int(size.x)-14,8):
		var a := 0.12+float((x*17)%11)/55.0
		for y in [2.0,size.y-5.0]: draw_line(Vector2(x,y),Vector2(x+3,y+2),Color(0.8,0.7,0.45,a),1)
	for corner in [Vector2(10,10),Vector2(size.x-10,10),Vector2(10,size.y-10),size-Vector2(10,10)]:
		draw_circle(corner,2,gold)
		draw_arc(corner,5,0,TAU,16,Color(0.7,0.65,0.43,0.4),1)
