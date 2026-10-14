extends SubViewportContainer
## Visual-only scene. No random draw, AP, production or survival code.
const TextureOcean = preload("res://presentation/texture_ocean.gd")
const ModelOcean = preload("res://presentation/model_ocean.gd")
const ToonOcean = preload("res://presentation/toon_ocean.gd")
const NIGHT_GRADE = preload("res://assets/shaders/night_grade.gdshader")
## "model" forces the archived GLB ocean (legacy tests); empty uses the toon ocean.
static var ocean_style_override := ""
const RaftModels = preload("res://presentation/raft_state_models.gd")
var raft_models := RaftModels.new()
var _raft_layout := "123456"
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
## Centre of the unobstructed scene area (left of the action panel, above hand).
const RAFT_SCREEN_CENTER := Vector2(0.3875,0.46)
var _framing_pending := true
var _framed_size := Vector2i.ZERO

func create(assets: RefCounted) -> void:
	_assets = assets
	_font = SystemFont.new(); _font.font_names = PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
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
		var min_x: float = 0.0 if _raft_layout == "123456" else -1.0; var min_y := 0.0; var max_x: float = 1.0 if _raft_layout == "123456" else -1.0; var max_y: float = 0.0 if _raft_layout == "123456" else 1.0
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
		var scale_factor: float = maxf(1.0,pow(maxf(max_x-min_x+1.0,max_y-min_y+1.0)/2.0,0.65))
		camera.position = center + Vector3(5.5,7.6,10.5)*scale_factor
		camera.look_at(center+Vector3(1.2*scale_factor,0.35,0),Vector3.UP)
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
		return
	var config: Dictionary = texture_ocean.config
	raft.position.y = float(config.raft_base_height)+sin(_time*0.85)*float(config.bob_amplitude)
	raft.rotation.z = sin(_time*0.48)*float(config.tilt_amplitude)
	raft.rotation.x = cos(_time*0.55)*float(config.tilt_amplitude)
	_frame_raft_if_needed()

## Translate the camera in its own screen plane, preserving angle and distance.
## Recompute only after layout/viewport changes; waves must not move the camera.
func _frame_raft_if_needed() -> void:
	if viewport.size.x < 2 or viewport.size.y < 2: return
	if not _framing_pending and _framed_size == viewport.size: return
	var meshes := raft.find_children("*","MeshInstance3D",true,false)
	if meshes.is_empty(): return
	var target := Vector2(viewport.size)*RAFT_SCREEN_CENTER
	for attempt in range(4):
		var minimum := Vector2(INF,INF)
		var maximum := Vector2(-INF,-INF)
		for node in meshes:
			if not node.is_visible_in_tree() or node.mesh == null: continue
			var bounds: AABB = node.mesh.get_aabb()
			for i in range(8):
				var pixel := camera.unproject_position(node.global_transform*bounds.get_endpoint(i))
				minimum = minimum.min(pixel); maximum = maximum.max(pixel)
		if minimum.x == INF: return
		var error := (minimum+maximum)*0.5-target
		if error.length() < 0.5: break
		var depth := -camera.to_local(raft.global_position).z
		var units_per_pixel := 2.0*depth*tan(deg_to_rad(camera.fov)*0.5)/float(viewport.size.y)
		camera.position += (camera.basis.x*error.x-camera.basis.y*error.y)*units_per_pixel
	_framing_pending = false
	_framed_size = viewport.size
