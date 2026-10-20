extends RefCounted
## Clockwise spiral, shared by rules, numbering and the single 3D build hint.
const ID := "spiral-v1"
const POSITIONS := [Vector2i(1,1),Vector2i(2,1),Vector2i(2,2),Vector2i(1,2),Vector2i(0,2),Vector2i(0,1),Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(3,1),Vector2i(3,2),Vector2i(3,3),Vector2i(2,3),Vector2i(1,3),Vector2i(0,3)]
static func positions(width: int, height: int = -1) -> Array:
	var actual_height:=width if height<0 else height
	return POSITIONS.filter(func(p):return p.x<width and p.y<actual_height)
static func is_root(x: int, y: int) -> bool:
	return Vector2i(x,y) in POSITIONS.slice(0,2)
static func number_at(x: int, y: int) -> int:
	return POSITIONS.find(Vector2i(x,y))+1
