extends "res://presentation/loading_transition.gd"
## Native canvas animation; elapsed time is presentation-only.
@export var backdrop_color := Color(0.03,0.08,0.11,0.82)
@export var ink_color := Color("e5d5ad")
@export var wave_color := Color(0.48,0.68,0.71,0.45)

func _ready() -> void:
	super._ready()
	name="VoyageTransition"
	stage.add_theme_color_override("font_color",ink_color)
	caption.text="潮水流转，新的航程正在展开"
	caption.add_theme_color_override("font_color",Color("a3babb"))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),backdrop_color)
	var center:=Vector2(size.x*.5,size.y*.46)
	# Small drifting wave bands leave the underlying raft and HUD visible.
	for layer in range(3):
		var points:=PackedVector2Array()
		for x in range(-180,181,4):
			var edge:=1.0-absf(float(x))/180.0
			var y:=34+layer*15+sin(x*.033-elapsed*2.4+layer*.9)*5*edge
			points.append(center+Vector2(x,y))
		draw_polyline(points,wave_color,2.0,true)
	var boat:=center+Vector2(sin(elapsed*1.4)*7,sin(elapsed*2.4)*3)
	draw_colored_polygon(PackedVector2Array([boat+Vector2(-40,14),boat+Vector2(43,14),boat+Vector2(25,30),boat+Vector2(-24,30)]),ink_color)
	draw_line(boat+Vector2(-3,14),boat+Vector2(-3,-56),ink_color,2.5,true)
	draw_colored_polygon(PackedVector2Array([boat+Vector2(3,-51),boat+Vector2(3,7),boat+Vector2(36,7)]),Color("b29b6b"))
	draw_colored_polygon(PackedVector2Array([boat+Vector2(-9,-36),boat+Vector2(-9,7),boat+Vector2(-33,7)]),Color("7e9b98"))
