extends Control
## Continuous rails underneath uniformly scaled ornaments; never stretch a motif.
var parts: Dictionary = {}
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/title_ui/frame_v3/source_manifest.json"))
	for part in manifest.parts:
		parts[part.id]=load("res://assets/title_ui/frame_v3/"+part.id+".png")
	resized.connect(queue_redraw)
	queue_redraw()
func piece(id: String, pos: Vector2, dimensions: Vector2 = Vector2.ZERO) -> void:
	var texture: Texture2D=parts[id]
	draw_texture_rect(texture,Rect2(pos,texture.get_size() if dimensions==Vector2.ZERO else dimensions),false)
func _draw() -> void:
	if parts.is_empty() or size.x<=0 or size.y<=0: return
	var zoom:=minf(size.x/1672.0,size.y/941.0)
	var area:=size/zoom
	var w:=area.x; var h:=area.y
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*zoom)
	piece("top_continuous_rail",Vector2.ZERO,Vector2(w,100))
	piece("bottom_continuous_rail",Vector2(0,h-124),Vector2(w,124))
	piece("left_continuous_rail",Vector2.ZERO,Vector2(170,h))
	piece("right_continuous_rail",Vector2(w-170,0),Vector2(170,h))
	var free:=h-776.0
	var g1:=roundf(free*58.0/165.0); var g2:=roundf(free*48.0/165.0)
	for side in ["left","right"]:
		piece("top_"+side+"_corner",Vector2(0 if side=="left" else w-280,0))
		piece("bottom_"+side+"_corner",Vector2(0 if side=="left" else w-280,h-124))
		var x:=0.0 if side=="left" else w-170.0
		piece(side+"_ring",Vector2(x,405))
		piece(side+"_moon",Vector2(x,474+g1))
		piece(side+"_diamond",Vector2(x,604+g1+g2))
		var dot_x:=w*(0.25 if side=="left" else 0.75)-38
		piece("top_"+side+"_quarter_dot",Vector2(dot_x,0))
		piece("bottom_"+side+"_quarter_dot",Vector2(dot_x,h-124))
	piece("top_center_medallion",Vector2(roundf(w/2-96),0))
	piece("bottom_center_medallion",Vector2(roundf(w/2-96),h-124))
