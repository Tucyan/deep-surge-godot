extends TextureRect
## Visual-only scene. No random draw, AP, production or survival code.
const TextureOcean = preload("res://presentation/texture_ocean.gd")
const ModelOcean = preload("res://presentation/model_ocean.gd")
const ToonOcean = preload("res://presentation/toon_ocean.gd")
const NIGHT_GRADE = preload("res://assets/shaders/night_grade.gdshader")
## "model" forces the archived GLB ocean (legacy tests); empty uses the toon ocean.
static var ocean_style_override := ""
const RaftModels = preload("res://presentation/raft_state_models.gd")
var raft_models := RaftModels.new()
var _raft_layout := "spiral-v1"
var camera_controls = preload("res://presentation/raft_camera_controls.gd").new()
var camera_input_enabled := false
var camera_orbit_button := MOUSE_BUTTON_RIGHT
var camera_pan_button := MOUSE_BUTTON_LEFT
var camera_mode := "oblique"
var _camera_drag_button := 0
var _camera_pivot := Vector3.ZERO
var _automatic_camera_pose := Transform3D.IDENTITY
var _camera_touches: Dictionary={}
var _reset_from := Transform3D.IDENTITY
var _reset_progress := 1.0
const CAMERA_RESET_SECONDS := .45
const WET_WOOD = preload("res://assets/shaders/wet_wood.gdshader")
var viewport: SubViewport
var world: Node3D
var raft: Node3D
var cells: Node3D
var destinations: Node3D
var camera: Camera3D
var texture_ocean
var model_ocean
var toon_ocean
## Active wave provider (toon or model); null means the flat texture fallback.
var ocean
var lantern: OmniLight3D
var _rock_material: StandardMaterial3D
var _env: Environment
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _assets: RefCounted
var _font: SystemFont
var _cell_signature := ""
var _destination_signature := ""
var _time := 0.0
var motion := true
var shadow_opacity := .4
## Centre of the unobstructed scene area (left of the action panel, above hand).
const RAFT_SCREEN_CENTER := Vector2(0.3875,0.46)
var _framing_pending := true
var _framed_size := Vector2i.ZERO
var _render_size_override := Vector2i.ZERO
var framing_rect := Rect2(.025,.22,.725,.48)
var _camera_base := Transform3D.IDENTITY
var _camera_from := Transform3D.IDENTITY
var _camera_target := Transform3D.IDENTITY
var _camera_progress := 1.0
var _has_camera_pose := false
const CAMERA_MOVE_SECONDS := .65

func set_framing_rect(value: Rect2) -> void:
	if framing_rect.position.distance_to(value.position)<.001 and framing_rect.size.distance_to(value.size)<.001: return
	framing_rect=value; _framing_pending=true

func _animate_camera(delta: float) -> void:
	if not _has_camera_pose: return
	if _camera_progress<1.0:
		_camera_progress=minf(1.0,_camera_progress+delta/CAMERA_MOVE_SECONDS)
		var eased:=_camera_progress*_camera_progress*(3.0-2.0*_camera_progress)
		_automatic_camera_pose=_camera_from.interpolate_with(_camera_target,eased)
	else: _automatic_camera_pose=_camera_target
	var desired: Transform3D=camera_controls.apply_pose(_automatic_camera_pose,_camera_pivot)
	if _reset_progress<1.0:
		_reset_progress=minf(1.0,_reset_progress+delta/CAMERA_RESET_SECONDS)
		var reset_eased: float=_reset_progress*_reset_progress*(3.0-2.0*_reset_progress)
		camera.global_transform=_reset_from.interpolate_with(desired,reset_eased)
	else: camera.global_transform=desired

func set_camera_input_enabled(enabled: bool) -> void:
	camera_input_enabled=enabled
	mouse_filter=Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if not enabled: camera_controls.cancel_drag(); _camera_touches.clear(); _camera_drag_button=0

func reset_camera_view() -> void:
	if _has_camera_pose:
		_reset_from=camera.global_transform; _reset_progress=0.0
	camera_controls.reset(); _camera_touches.clear(); _camera_drag_button=0; _animate_camera(0)

func set_camera_mode(value: String) -> void:
	if value not in ["oblique","top"] or value==camera_mode: return
	# Consume the manual offsets into the interpolation source before clearing them.
	# This also preserves the visible pose when switching during a reset/transition.
	if _has_camera_pose:
		_automatic_camera_pose=camera.global_transform
		_camera_from=_automatic_camera_pose; _camera_target=_automatic_camera_pose
		_camera_progress=0.0
	camera_mode=value
	camera_controls.reset(); _camera_touches.clear(); _camera_drag_button=0
	_reset_progress=1.0; _framing_pending=true

func camera_input(event: InputEvent) -> void:
	if not camera_input_enabled or _reset_progress<1.0: return
	if event is InputEventMouseButton:
		if event.button_index in [camera_orbit_button,camera_pan_button]:
			if event.pressed:
				_camera_drag_button=event.button_index
				camera_controls.begin_drag(event.position,"orbit" if event.button_index==camera_orbit_button else "pan")
			elif event.button_index==_camera_drag_button:
				camera_controls.end_drag(); _camera_drag_button=0
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera_controls.zoom_by(event.factor*(1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1))
	elif event is InputEventMouseMotion:
		if _camera_drag_button>0 and event.button_mask & (1 << (_camera_drag_button-1)):
			var depth: float=maxf(1.0,-camera.to_local(_camera_pivot+camera_controls.pan_offset).z)
			var units_per_pixel: float=2.0*depth*tan(deg_to_rad(camera.fov)*.5)/maxf(size.y,1.0)
			camera_controls.drag_to(event.position,camera.global_basis,units_per_pixel)
		else: camera_controls.end_drag(); _camera_drag_button=0
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_camera_touches[event.index]=event.position
			if _camera_touches.size()==1: camera_controls.begin_drag(event.position)
		else:
			_camera_touches.erase(event.index); camera_controls.end_drag()
			if event.canceled: camera_controls.cancel_drag()
	elif event is InputEventScreenDrag and _camera_touches.has(event.index):
		if _camera_touches.size()==2:
			var points: Array=_camera_touches.values(); var old_distance: float=points[0].distance_to(points[1])
			_camera_touches[event.index]=event.position; points=_camera_touches.values()
			var new_distance: float=points[0].distance_to(points[1])
			if old_distance>1 and new_distance>1:
				camera_controls.zoom_by(log(new_distance/old_distance)/log(1.0/.88))
			camera_controls.dragged=true; camera_controls.end_drag()
		else:
			_camera_touches[event.index]=event.position; camera_controls.drag_to(event.position)
	_animate_camera(0)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		camera_controls.cancel_drag(); _camera_touches.clear(); _camera_drag_button=0


func set_render_size(value: Vector2i) -> void:
	_render_size_override=value.max(Vector2i(2,2))
	viewport.size=_render_size_override

func _resize_render_surface() -> void:
	if is_instance_valid(viewport):
		viewport.size=_render_size_override if _render_size_override!=Vector2i.ZERO else Vector2i(size).max(Vector2i(2,2))

func create(assets: RefCounted) -> void:
	_assets = assets
	_font = SystemFont.new(); _font.font_names = PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	# Always map the render texture onto the full logical scene rectangle.
	# Render pixels may vary with clarity without changing screen coordinates.
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode=TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_input.connect(camera_input)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	texture=viewport.get_texture()
	resized.connect(_resize_render_surface)
	_resize_render_surface()
	world = Node3D.new(); world.name = "VoyageWorld"; viewport.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101f2b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("94adbb")
	env.ambient_light_energy = 0.65
	env.fog_enabled = true; env.fog_light_color = Color("1c3543"); env.fog_density = 0.012
	var environment := WorldEnvironment.new(); environment.environment = env; world.add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48,-28,0)
	moon.light_color = Color("b5ced6"); moon.light_energy = 1.8; moon.shadow_enabled = true
	moon.shadow_opacity=shadow_opacity
	world.add_child(moon)
	texture_ocean = TextureOcean.new(); texture_ocean.name = "WaterContact"
	world.add_child(texture_ocean); texture_ocean.create(assets)
	if ocean_style_override != "model":
		toon_ocean = ToonOcean.new(); toon_ocean.name = "ToonOcean"; world.add_child(toon_ocean)
		if toon_ocean.create(assets): ocean = toon_ocean
		else: world.remove_child(toon_ocean); toon_ocean.queue_free(); toon_ocean = null
	if ocean == null:
		model_ocean = ModelOcean.new(); model_ocean.name = "Ocean"; world.add_child(model_ocean)
		if model_ocean.create(assets): ocean = model_ocean
		else: world.remove_child(model_ocean); model_ocean.queue_free(); model_ocean = null
	if ocean != null: texture_ocean.sea.visible = false
	if toon_ocean != null: apply_night(env,moon)
	raft = Node3D.new(); raft.name = "Raft"; world.add_child(raft)
	raft.add_child(raft_models.decorative_root(self,_font,_raft_layout))
	cells = Node3D.new(); cells.name = "LogicalCells"; raft.add_child(cells)
	lantern = OmniLight3D.new()
	lantern.position = Vector3(-1.2,1.5,0.7); lantern.light_color = Color("ffd38a")
	lantern.light_energy = 2.2 if toon_ocean == null else float(toon_ocean.settings.environment.lantern_energy)
	lantern.omni_range = 6.0; lantern.visible = false; raft.add_child(lantern)
	destinations = Node3D.new(); destinations.name = "Destinations"; world.add_child(destinations)
	for i in range(48):
		var angle: float = float(i) * 2.39996
		var radius: float = 12.0 + float(i % 9) * 2.4
		var position := Vector3(cos(angle)*radius,-0.5,sin(angle)*radius)
		var rock := cone(world,position,0.35+float(i%4)*0.20,1.2+float(i%5)*0.65,Color("1c3039"))
		if _rock_material != null: rock.material_override = _rock_material
		rock.rotation_degrees.z = float(i%3-1)*9.0
	camera = Camera3D.new(); camera.name = "VoyageCamera"
	camera.position = Vector3(6.5,7.6,12)
	camera.fov = 43.0; camera.near = 0.1; camera.far = 140.0
	world.add_child(camera); camera.look_at(Vector3(2.0,0.7,0.0),Vector3.UP); camera.current = true

## Cold dark-blue night look; all values come from data.ocean.toon-config.
func apply_night(env: Environment, moon: DirectionalLight3D) -> void:
	var look: Dictionary = toon_ocean.settings.environment
	env.background_color = Color(look.background)
	env.ambient_light_color = Color(look.ambient_color); env.ambient_light_energy = look.ambient_energy
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(look.fog_color); env.fog_density = 1.0
	env.fog_depth_curve = look.fog_depth_curve
	_env = env; apply_view_scale(1.0)
	moon.light_color = Color(look.moon_color); moon.light_energy = look.moon_energy
	shadow_opacity=float(look.get("shadow_opacity",.4)); moon.shadow_opacity=shadow_opacity
	moon.rotation_degrees = Vector3(look.moon_rotation[0],look.moon_rotation[1],look.moon_rotation[2])
	_rock_material = material(Color(look.rock_color))
	texture_ocean.foam_material.set_shader_parameter("foam_color",Color(look.contact_foam_color))
	texture_ocean.foam_material.set_shader_parameter("contact_color",Color(look.contact_shadow_color))
	texture_ocean.foam_material.set_shader_parameter("foam_opacity",look.contact_foam_opacity)
	var grade := ShaderMaterial.new(); grade.shader = NIGHT_GRADE
	var values: Dictionary = toon_ocean.settings.grade
	for key in values:
		var value = values[key]
		grade.set_shader_parameter(key,Vector3(value[0],value[1],value[2]) if value is Array else value)
	# This class defines material(); use the CanvasItem setter explicitly.
	set_material(grade)

## Keep the raft equally clear when the camera pulls back for a larger footprint.
func apply_view_scale(scale_factor: float) -> void:
	if toon_ocean == null or _env == null: return
	var look: Dictionary = toon_ocean.settings.environment
	_env.fog_depth_begin = float(look.fog_depth_begin)*scale_factor; _env.fog_depth_end = float(look.fog_depth_end)*scale_factor
	toon_ocean.set_view_scale(scale_factor)

func hide_deck(node: Node) -> void:
	if node is MeshInstance3D and "deck" in node.name.to_lower(): node.visible = false
	for child in node.get_children(): hide_deck(child)

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + str(glow)
	if _materials.has(key): return _materials[key]
	var result := StandardMaterial3D.new(); result.albedo_color = color; result.roughness = 0.76
	if glow: result.emission_enabled = true; result.emission = color; result.emission_energy_multiplier = 0.65
	_materials[key] = result
	return result

func wet_wood(color: Color) -> ShaderMaterial:
	var key := "wet:"+color.to_html()
	if _materials.has(key): return _materials[key]
	var result := ShaderMaterial.new(); result.shader = WET_WOOD
	result.set_shader_parameter("wood_color",color)
	_materials[key] = result
	return result

func box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var key: String = "box:"+str(size)
	if not _meshes.has(key):
		var created := BoxMesh.new(); created.size = size; _meshes[key] = created
	var node := MeshInstance3D.new(); var mesh: BoxMesh = _meshes[key]
	node.mesh = mesh; node.material_override = material(color); node.position = position; parent.add_child(node)
	return node

func cone(parent: Node3D, position: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var key: String = "cone:%s:%s" % [radius,height]
	if not _meshes.has(key):
		var created := CylinderMesh.new()
		created.top_radius = radius*0.15; created.bottom_radius = radius; created.height = height; created.radial_segments = 5
		_meshes[key] = created
	var node := MeshInstance3D.new(); var mesh: CylinderMesh = _meshes[key]
	node.mesh = mesh; node.material_override = material(color); node.position = position; parent.add_child(node)
	return node

func clear(parent: Node) -> void:
	for child in parent.get_children(): parent.remove_child(child); child.queue_free()

func sync(view: Dictionary) -> void:
	visible = view.screen == "game"
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if not view.has("cells"): return
	var signature := JSON.stringify(view.cells)
	if signature != _cell_signature:
		_cell_signature = signature; clear(cells)
		var layout: String = view.get("flags",{}).get("raft_layout","legacy")
		if layout != _raft_layout:
			_raft_layout = layout
			var old = raft.get_node("DecorativeRoot"); raft.remove_child(old); old.queue_free()
			raft.add_child(raft_models.decorative_root(self,_font,_raft_layout))
		var hull_cells: Array = view.cells.duplicate(true)+raft_models.root_cells(_raft_layout)
		texture_ocean.sync_cells(hull_cells)
		if ocean != null: ocean.sync_cells(hull_cells)
		var min_x: float=INF; var min_y: float=INF; var max_x: float=-INF; var max_y: float=-INF
		for root_cell in raft_models.root_cells(_raft_layout):
			min_x=minf(min_x,root_cell.x); max_x=maxf(max_x,root_cell.x)
			min_y=minf(min_y,root_cell.y); max_y=maxf(max_y,root_cell.y)
		lantern.visible = false
		for cell in view.cells:
			if cell.status == "detached": continue
			min_x = minf(min_x,cell.x); min_y = minf(min_y,cell.y)
			max_x = maxf(max_x,cell.x); max_y = maxf(max_y,cell.y)
			var tile = raft_models.build(self,cell,_font); cells.add_child(tile)
			if cell.status == "intact" and cell.equipment.get("id","") == "lamp" and int(cell.equipment.get("fuel",0)) > 0:
				if not lantern.visible:
					lantern.position = tile.position+Vector3(0,.74,-.13); lantern.visible = true
				else:
					var light := OmniLight3D.new(); light.light_color = lantern.light_color; light.light_energy = lantern.light_energy; light.omni_range = lantern.omni_range
					light.position = Vector3(0,.74,-.13); tile.add_child(light)
		if min_x > max_x: min_x = 0; min_y = 0; max_x = 1; max_y = 1
		if toon_ocean != null:
			for mat in [toon_ocean.material,toon_ocean.far_material]:
				mat.set_shader_parameter("lantern_enabled",lantern.visible)
				mat.set_shader_parameter("lantern_strength",toon_ocean.settings.lantern.strength if lantern.visible else 0.0)
		var center := Vector3(((min_x+max_x)*0.5-0.5)*2.35,0,((min_y+max_y)*0.5-0.5)*2.1)
		_camera_pivot=center+Vector3(0,.35,0)
		var scale_factor: float = maxf(1.0,pow(maxf(max_x-min_x+1.0,max_y-min_y+1.0)/2.0,0.65))
		var position_goal:=center+Vector3(5.5,7.6,10.5)*scale_factor
		_camera_base=Transform3D(Basis.IDENTITY,position_goal).looking_at(center+Vector3(1.2*scale_factor,0.35,0),Vector3.UP)
		apply_view_scale(scale_factor)
		_framing_pending = true
	var destination_signature := JSON.stringify([view.phase,view.get("node",{}).get("id",""),view.get("candidates",[])])
	if destination_signature != _destination_signature:
		_destination_signature = destination_signature; clear(destinations)
		var list: Array = view.candidates if view.phase == "navigation" else ([view.node] if not view.node.is_empty() else [])
		for i in range(list.size()):
			var marker := Node3D.new(); marker.position = Vector3(6.8,0.05,-4.0+float(i)*4.5); destinations.add_child(marker)
			var color := Color("c6593e") if list[i].has("monster") else Color("67a2aa")
			cone(marker,Vector3.ZERO,0.65,2.0,Color("21303b"))
			var ring := MeshInstance3D.new(); var torus := TorusMesh.new(); torus.inner_radius = 0.75; torus.outer_radius = 0.83
			ring.mesh = torus; ring.material_override = material(color,true); ring.position.y = 0.08; marker.add_child(ring)

func _process(delta: float) -> void:
	if not is_instance_valid(raft) or not visible: return
	if motion: _time += delta
	texture_ocean.tick(_time)
	if ocean != null:
		ocean.tick(_time)
		raft.position.y = ocean.plane_height-float(ocean.settings.raft_draft)
		raft.rotation.z = atan(ocean.plane_slope.x)
		raft.rotation.x = -atan(ocean.plane_slope.y)
		if toon_ocean != null and lantern.visible: toon_ocean.set_lantern(lantern.global_position)
		texture_ocean.foam_material.set_shader_parameter("plane_height",ocean.plane_height)
		texture_ocean.foam_material.set_shader_parameter("plane_slope",ocean.plane_slope)
		for key in _materials:
			if key.begins_with("wet:"):
				_materials[key].set_shader_parameter("water_height",ocean.plane_height)
				_materials[key].set_shader_parameter("water_slope",ocean.plane_slope)
		_frame_raft_if_needed()
		_animate_camera(delta)
		return
	var config: Dictionary = texture_ocean.config
	raft.position.y = float(config.raft_base_height)+sin(_time*0.85)*float(config.bob_amplitude)
	raft.rotation.z = sin(_time*0.48)*float(config.tilt_amplitude)
	raft.rotation.x = cos(_time*0.55)*float(config.tilt_amplitude)
	_frame_raft_if_needed()
	_animate_camera(delta)

## Fit actual geometry inside the HUD-free rectangle, then interpolate the pose.
## Recompute only after geometry/layout/viewport changes, never every wave frame.
func _frame_raft_if_needed() -> void:
	if viewport.size.x < 2 or viewport.size.y < 2: return
	if not _framing_pending and _framed_size == viewport.size: return
	var meshes := raft.find_children("*","MeshInstance3D",true,false)
	if meshes.is_empty(): return
	var previous: Transform3D=_automatic_camera_pose if _has_camera_pose else camera.global_transform
	camera.global_transform=_camera_base
	if camera_mode=="top":
		# Explicit screen-up avoids the singular UP vector of a vertical look_at.
		camera.global_transform=Transform3D(Basis.IDENTITY,_camera_pivot+Vector3.UP*(_camera_base.origin-_camera_pivot).length()).looking_at(_camera_pivot,Vector3.FORWARD)
	var safe:=Rect2(framing_rect.position*Vector2(viewport.size),framing_rect.size*Vector2(viewport.size))
	var target:=safe.get_center()
	for attempt in range(10):
		var minimum := Vector2(INF,INF)
		var maximum := Vector2(-INF,-INF)
		for node in meshes:
			if not node.is_visible_in_tree() or node.mesh == null: continue
			var bounds: AABB = node.mesh.get_aabb()
			for i in range(8):
				var pixel := camera.unproject_position(node.global_transform*bounds.get_endpoint(i))
				minimum = minimum.min(pixel); maximum = maximum.max(pixel)
		if minimum.x == INF: camera.global_transform=previous; return
		var error := (minimum+maximum)*0.5-target
		var depth := maxf(1.0,-camera.to_local(raft.global_position).z)
		var ratio:=maxf((maximum.x-minimum.x)/maxf(1,safe.size.x-20),(maximum.y-minimum.y)/maxf(1,safe.size.y-20))
		if ratio>1.0:
			camera.position+=camera.basis.z*depth*(ratio-1.0)*1.02
			continue
		if error.length() < 0.25: break
		var units_per_pixel := 2.0*depth*tan(deg_to_rad(camera.fov)*0.5)/float(viewport.size.y)
		camera.position += (camera.basis.x*error.x-camera.basis.y*error.y)*units_per_pixel
	_camera_target=camera.global_transform
	camera_controls.base_elevation=asin(clampf(_camera_target.basis.z.y,-1.0,1.0))
	if _has_camera_pose:
		_camera_from=previous; _camera_progress=0.0; _automatic_camera_pose=previous
	else:
		_has_camera_pose=true; _camera_progress=1.0; _automatic_camera_pose=_camera_target
	camera.global_transform=camera_controls.apply_pose(_automatic_camera_pose,_camera_pivot)
	_framing_pending = false
	_framed_size = viewport.size
