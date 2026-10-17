extends RefCounted
## Local view offsets only; never reads or writes GameSession or rule RNG.
const MAX_PAN_DISTANCE := 3.0
const MIN_ELEVATION := PI / 12.0
const MAX_ELEVATION := PI / 2.0
# Elevation of the selected automatic pose; pitch is a local offset from it.
var base_elevation := atan2(8.0,12.0)
var locked := false
var yaw := 0.0
var pitch := 0.0
var zoom := 1.0
var pan_offset := Vector3.ZERO
var dragged := false
var _pressed := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _drag_mode := "orbit"
func reset() -> void:
	yaw=0.0; pitch=0.0; zoom=1.0; pan_offset=Vector3.ZERO; cancel_drag()
func orbit(delta: Vector2) -> void:
	if locked: return
	yaw=wrapf(yaw-delta.x*.006,-PI,PI)
	pitch=clampf(pitch-delta.y*.004,base_elevation-MAX_ELEVATION,base_elevation-MIN_ELEVATION)
func zoom_by(steps: float) -> void:
	if not locked: zoom=clampf(zoom*pow(.88,clampf(steps,-30,30)),.55,2.5)
func pan(delta: Vector2, view_basis: Basis, units_per_pixel: float) -> void:
	if locked: return
	var right:=Vector3(view_basis.x.x,0,view_basis.x.z).normalized()
	var back:=Vector3(view_basis.z.x,0,view_basis.z.z).normalized()
	if back.length_squared()<.001:
		back=-Vector3(view_basis.y.x,0,view_basis.y.z).normalized()
	pan_offset-=(right*delta.x+back*delta.y)*units_per_pixel
	pan_offset=pan_offset.limit_length(MAX_PAN_DISTANCE)
func begin_drag(point: Vector2, mode: String = "orbit") -> void:
	_pressed=true; dragged=false; _start=point; _last=point; _drag_mode=mode
func drag_to(point: Vector2, view_basis: Basis = Basis.IDENTITY, units_per_pixel: float = .02) -> void:
	if not _pressed or locked: return
	if not dragged and point.distance_to(_start)<6.0: return
	var delta:=point-(_last if dragged else _start)
	if _drag_mode=="pan": pan(delta,view_basis,units_per_pixel)
	else: orbit(delta)
	dragged=true; _last=point
func end_drag() -> void:
	_pressed=false
func cancel_drag() -> void:
	_pressed=false; dragged=false
func apply_pose(base: Transform3D, pivot: Vector3) -> Transform3D:
	var rotation:=Basis(Vector3.UP,yaw)*Basis(base.basis.x,pitch)
	return Transform3D(rotation*base.basis,pivot+rotation*(base.origin-pivot)*zoom+pan_offset)
