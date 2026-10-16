extends Control
## Draw behind the parent logo, inheriting its position, scale and visibility.
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_circle(size*0.5,minf(size.x,size.y)*0.5,Color(0,0,0,0.70),true,-1.0,true)
