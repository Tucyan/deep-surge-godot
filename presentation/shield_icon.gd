extends Control
## A single shield icon representing 1 point of shield.
## If is_dashed is true, the perimeter is drawn with dashed lines (breaks next turn).

@export var is_dashed: bool = false
@export var is_empty_shield: bool = false

func _init(dashed: bool = false, empty_slot: bool = false) -> void:
	is_dashed = dashed
	is_empty_shield = empty_slot
	custom_minimum_size = Vector2(18, 22)
	size_flags_vertical = SIZE_SHRINK_CENTER
	mouse_filter = MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w := size.x
	var h := size.y
	
	var p0 := Vector2(2.0, 2.0)
	var p1 := Vector2(w - 2.0, 2.0)
	var p2 := Vector2(w - 2.0, h * 0.48)
	var p3 := Vector2(w * 0.5, h - 2.0)
	var p4 := Vector2(2.0, h * 0.48)
	var poly := PackedVector2Array([p0, p1, p2, p3, p4])
	
	if is_empty_shield:
		var closed_empty := poly
		closed_empty.append(p0)
		draw_polyline(closed_empty, Color(0.35, 0.48, 0.6, 0.35), 1.2)
		return
	
	# Fill
	var fill_col := Color(0.08, 0.38, 0.78, 0.35) if is_dashed else Color(0.12, 0.48, 0.95, 0.60)
	draw_colored_polygon(poly, fill_col)
	
	# Outline
	var border_col := Color(0.6, 0.9, 1.0, 0.95) if is_dashed else Color(0.8, 0.95, 1.0, 1.0)
	
	if is_dashed:
		var edges := [
			[p0, p1],
			[p1, p2],
			[p2, p3],
			[p3, p4],
			[p4, p0]
		]
		for edge in edges:
			draw_dashed_segment(edge[0], edge[1], border_col, 3.0, 2.0, 1.5)
	else:
		var closed_poly := poly
		closed_poly.append(p0)
		draw_polyline(closed_poly, border_col, 1.6)
		# Inner subtle highlight spine
		draw_line(Vector2(w * 0.5, 4.5), Vector2(w * 0.5, h * 0.75), Color(1, 1, 1, 0.38), 1.0)

func draw_dashed_segment(p_from: Vector2, p_to: Vector2, col: Color, dash_len: float, gap_len: float, line_w: float) -> void:
	var total_len := p_from.distance_to(p_to)
	if total_len <= 0.001: return
	var dir := (p_to - p_from) / total_len
	var cur := 0.0
	while cur < total_len:
		var seg_end := minf(cur + dash_len, total_len)
		draw_line(p_from + dir * cur, p_from + dir * seg_end, col, line_w)
		cur += dash_len + gap_len
