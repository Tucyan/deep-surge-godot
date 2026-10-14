@tool
extends PanelContainer
## Reusable ornamental frame; geometry is visual-only and follows the panel bounds.
func _draw() -> void:
	if size.x < 24 or size.y < 24: return
	var ink := Color("b5a787")
	ink.a = 0.65
	draw_rect(Rect2(Vector2(5,5),size-Vector2(10,10)),Color(0.66,0.65,0.55,0.18),false,1.0)
	for corner in [Vector2(9,9),Vector2(size.x-9,9),Vector2(9,size.y-9),size-Vector2(9,9)]:
		draw_colored_polygon(PackedVector2Array([corner+Vector2(0,-3),corner+Vector2(3,0),corner+Vector2(0,3),corner+Vector2(-3,0)]),ink)
	var half := minf(40.0,size.x*0.14)
	draw_line(Vector2(size.x*.5-half,5),Vector2(size.x*.5+half,5),ink,1.0,true)
