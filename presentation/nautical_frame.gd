@tool
extends Control
## Size-aware geometry; corner ornaments stay fixed when panels stretch.
@export var paper := false
@export_range(0.0,1.0) var paper_opacity := 0.7
@export var ornaments := true
const GOLD := Color("dbc395")
# Match draw_circle's 64-segment fan, shared by every paper frame. Only the
# instance transforms/colors belong to a frame and are released with it.
static var _grain_circle: ArrayMesh
var _paper_grain: MultiMesh
var _grain_size := Vector2i(-1,-1)

static func _circle_mesh() -> ArrayMesh:
	if _grain_circle != null: return _grain_circle
	var vertices := PackedVector2Array([Vector2.ZERO])
	var indices := PackedInt32Array()
	for i in range(65):
		var angle: float=i*TAU/64.0
		vertices.append(Vector2(cos(angle),sin(angle))*.55)
	for i in range(64): indices.append_array(PackedInt32Array([0,i+1,i+2]))
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_INDEX]=indices
	_grain_circle=ArrayMesh.new()
	_grain_circle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return _grain_circle

func _draw_paper_grain() -> void:
	var pixel_size := Vector2i(size)
	if _paper_grain == null or pixel_size != _grain_size:
		_grain_size=pixel_size
		var columns := range(12,pixel_size.x-12,5)
		var rows := range(12,pixel_size.y-12,7)
		_paper_grain=MultiMesh.new()
		_paper_grain.transform_format=MultiMesh.TRANSFORM_2D
		_paper_grain.use_colors=true
		_paper_grain.mesh=_circle_mesh()
		_paper_grain.instance_count=columns.size()*rows.size()
		var index := 0
		for x in columns:
			for y in rows:
				_paper_grain.set_instance_transform_2d(index,Transform2D(0,Vector2(x,y)))
				_paper_grain.set_instance_color(index,Color(.44,.33,.16,.025+float((x*17+y*13)%7)*.004))
				index+=1
	if _paper_grain.instance_count>0: draw_multimesh(_paper_grain,null)

func _ready():
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
static func outline(r: Rect2, cut: float) -> PackedVector2Array:
	var a=r.position; var b=r.end
	return PackedVector2Array([a+Vector2(cut,0),Vector2(b.x-cut,a.y),Vector2(b.x,a.y+cut),b-Vector2(0,cut),b-Vector2(cut,0),Vector2(a.x+cut,b.y),Vector2(a.x,b.y-cut),a+Vector2(0,cut),a+Vector2(cut,0)])
static func star(canvas: CanvasItem, p: Vector2, radius: float, color: Color):
	canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius*.23,-radius*.23),p+Vector2(radius,0),p+Vector2(radius*.23,radius*.23),p+Vector2(0,radius),p+Vector2(-radius*.23,radius*.23),p-Vector2(radius,0),p-Vector2(radius*.23,radius*.23)]),color)
func _draw():
	if size.x<24 or size.y<24: return
	var r=Rect2(Vector2(2,2),size-Vector2(4,4))
	var fill=Color("f3ecde") if paper else Color("071722")
	if paper: fill.a=paper_opacity
	draw_colored_polygon(outline(r,14),fill)
	draw_polyline(outline(r,14),Color("08121b"),5,true)
	draw_polyline(outline(r,14),GOLD,1.5,true)
	draw_polyline(outline(r.grow(-5),10),Color("162635") if paper else Color("756954"),1,true)
	if paper:
		_draw_paper_grain()
		for corner in [Vector2(13,13),Vector2(size.x-13,13),Vector2(13,size.y-13),size-Vector2(13,13)]:
			var direction=Vector2(1 if corner.x<size.x*.5 else -1,1 if corner.y<size.y*.5 else -1)
			for t in [0.0,7.0,14.0]:
				var p=corner+Vector2(t,t)*direction
				draw_arc(p,5,0,TAU,24,Color("162635"),1.2,true)
			draw_polyline(PackedVector2Array([corner+Vector2(0,29)*direction,corner,corner+Vector2(29,0)*direction]),Color("162635"),2,true)
			star(self,corner+Vector2(11,11)*direction,6,Color("162635"))
	elif ornaments:
		var y=size.y*.5
		for center_x in [size.x*.4,size.x*.6]:
			star(self,Vector2(center_x,y),6,GOLD)
			draw_line(Vector2(center_x-110,y),Vector2(center_x-12,y),Color("9a8969"),1,true)
			draw_line(Vector2(center_x+12,y),Vector2(center_x+110,y),Color("9a8969"),1,true)
