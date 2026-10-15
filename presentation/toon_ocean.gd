extends Node3D
## Stylized night ocean: procedural Gerstner waves shared by shader and raft float.
## Visual time only; never reads or writes GameSession, rules RNG or save data.
const SHADER = preload("res://assets/shaders/toon_ocean.gdshader")
const MIST_SHADER = preload("res://assets/shaders/night_mist.gdshader")
const WAVES := 4
var settings: Dictionary = {}
var material: ShaderMaterial
var far_material: ShaderMaterial
var near: MeshInstance3D
var far: MeshInstance3D
var mist_layers: Array[MeshInstance3D] = []
var mist_materials: Array[ShaderMaterial] = []
var plane_height := 0.0
var plane_slope := Vector2.ZERO
var raft_bounds := Vector4(0,0,2.35,2.1)
var time := 0.0
# Per wave: direction, wavenumber k, angular speed, amplitude, steepness, phase.
var _waves: Array = []
var _fade := Vector2(20,30)
var _pose_initialized := false
var _last_pose_time := 0.0

func create(assets: RefCounted) -> bool:
	settings = assets.data("data.ocean.toon-config")
	if settings.is_empty() or settings.get("waves",[]).size() != WAVES: return false
	var dk := PackedVector4Array(); var aq := PackedVector4Array(); var amplitude_sum := 0.0
	for wave in settings.waves:
		var angle := deg_to_rad(float(wave.direction_deg))
		var k := TAU/float(wave.wavelength)
		var entry := {"dir":Vector2(cos(angle),sin(angle)),"k":k,"omega":sqrt(9.81*k)*float(wave.speed),
			"a":float(wave.amplitude),"s":float(wave.steepness),"phase":float(wave.phase)}
		_waves.append(entry); amplitude_sum += entry.a
		dk.append(Vector4(entry.dir.x,entry.dir.y,k,entry.omega)); aq.append(Vector4(entry.a,entry.s,entry.phase,0))
	_fade = Vector2(settings.amplitude_fade[0],settings.amplitude_fade[1])
	material = ShaderMaterial.new(); material.shader = SHADER
	var detail: Dictionary = settings.detail
	material.set_shader_parameter("detail_texture",assets.texture("texture.ocean.detail"))
	for key in ["enabled","scale","flow_strength","water_contrast","pore_strength","thread_strength","normal_strength"]:
		material.set_shader_parameter("detail_"+key,detail[key])
	material.set_shader_parameter("detail_fade_distance",Vector2(detail.fade_distance[0],detail.fade_distance[1]))
	material.set_shader_parameter("wave_dk",dk); material.set_shader_parameter("wave_aq",aq)
	var noise: Dictionary=settings.wave_noise
	for key in ["enabled","seed","scale","phase_strength","amplitude_strength"]:
		material.set_shader_parameter("wave_noise_"+key,noise[key])
	material.set_shader_parameter("wave_noise_drift",Vector2(noise.drift[0],noise.drift[1]))
	material.set_shader_parameter("amplitude_sum",amplitude_sum)
	material.set_shader_parameter("amplitude_fade",_fade)
	material.set_shader_parameter("near_half",float(settings.near_size)*0.5)
	for key in ["contact_margin","contact_transition"]: material.set_shader_parameter(key,settings[key])
	var spacing := Vector2(settings.cell_spacing[0],settings.cell_spacing[1])
	material.set_shader_parameter("cell_half",spacing*0.5)
	var palette: Dictionary = settings.palette
	for key in palette: material.set_shader_parameter(key+"_color",Color(palette[key]))
	var shading: Dictionary = settings.shading
	material.set_shader_parameter("key_direction",_vec3(shading.key_direction))
	material.set_shader_parameter("band_thresholds",Vector4(shading.band_thresholds[0],shading.band_thresholds[1],shading.band_thresholds[2],shading.band_thresholds[3]))
	for key in ["light_weight","height_weight","fresnel_power","fresnel_strength"]: material.set_shader_parameter(key,shading[key])
	var foam: Dictionary = settings.foam
	for key in ["fold_gain","height_gain","noise_scale","erosion","streak_scale","streak_width","streak_strength","streak_crest","contact_width","contact_threshold","contact_strength","contact_noise","crest_sharpness","crest_gain","contact_frequency","contact_speed"]:
		material.set_shader_parameter(key,foam[key])
	material.set_shader_parameter("foam_threshold",foam.threshold); material.set_shader_parameter("core_threshold",foam.core_threshold)
	material.set_shader_parameter("foam_drift",Vector2(foam.drift[0],foam.drift[1]))
	material.set_shader_parameter("foam_fade_distance",Vector2(foam.fade_distance[0],foam.fade_distance[1]))
	var glint: Dictionary = settings.glint
	material.set_shader_parameter("moon_direction",_vec3(glint.moon_direction))
	material.set_shader_parameter("glint_threshold",glint.threshold); material.set_shader_parameter("glint_noise",glint.noise)
	for key in ["sheen_power","sheen_strength"]: material.set_shader_parameter(key,glint[key])
	material.set_shader_parameter("lantern_radius",settings.lantern.radius); material.set_shader_parameter("lantern_strength",settings.lantern.strength)
	material.set_shader_parameter("lantern_glint_threshold",settings.lantern.glint_threshold)
	var look: Dictionary = settings.environment
	material.set_shader_parameter("fog_color",Color(look.fog_color))
	material.set_shader_parameter("fog_depth",Vector3(look.fog_depth_begin,look.fog_depth_end,look.fog_depth_curve))
	far_material = material.duplicate(); far_material.set_shader_parameter("far_mode",true)
	near = _plane("ToonOceanNear",float(settings.near_size),int(settings.near_subdivisions),material,0.0)
	far = _plane("ToonOceanFar",float(settings.far_size),0,far_material,-0.03)
	_create_mist()
	tick(0.0)
	return true

## Distant fog bank: transparent sheets just above the water, clear around the raft.
func _create_mist() -> void:
	var mist: Dictionary = settings.mist
	for i in range(mist.layers.size()):
		var layer: Dictionary = mist.layers[i]
		var shader_material := ShaderMaterial.new(); shader_material.shader = MIST_SHADER
		shader_material.set_shader_parameter("mist_color",Color(mist.color))
		shader_material.set_shader_parameter("base_haze",mist.base_haze); shader_material.set_shader_parameter("band_softness",mist.band_softness)
		shader_material.set_shader_parameter("band_thresholds",Vector2(mist.band_thresholds[0],mist.band_thresholds[1]))
		shader_material.set_shader_parameter("density",layer.density); shader_material.set_shader_parameter("noise_scale",layer.noise_scale)
		shader_material.set_shader_parameter("drift",Vector2(layer.drift[0],layer.drift[1])); shader_material.set_shader_parameter("layer_seed",layer.seed)
		var node := _plane("NightMist_%d" % i,float(mist.size),0,shader_material,float(layer.height))
		mist_layers.append(node); mist_materials.append(shader_material)
	set_view_scale(1.0)

## Fog and mist distances follow the camera pull-back for larger rafts.
func set_view_scale(scale_factor: float) -> void:
	var look: Dictionary = settings.environment
	var fog := Vector3(float(look.fog_depth_begin)*scale_factor,float(look.fog_depth_end)*scale_factor,look.fog_depth_curve)
	for material_ref in [material,far_material]: material_ref.set_shader_parameter("fog_depth",fog)
	var detail_reach := Vector2(settings.detail.fade_distance[0],settings.detail.fade_distance[1])*scale_factor
	for material_ref in [material,far_material]: material_ref.set_shader_parameter("detail_fade_distance",detail_reach)
	var reach := Vector2(settings.mist.distance_range[0],settings.mist.distance_range[1])*scale_factor
	var clear := Vector2(settings.mist.clear_fade[0],settings.mist.clear_fade[1])*scale_factor
	for material_ref in mist_materials:
		material_ref.set_shader_parameter("distance_range",reach)
		material_ref.set_shader_parameter("clear_fade",clear)

func _vec3(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

func _plane(node_name: String, size: float, subdivisions: int, shader_material: ShaderMaterial, height: float) -> MeshInstance3D:
	var mesh := PlaneMesh.new(); mesh.size = Vector2(size,size)
	mesh.subdivide_width = subdivisions; mesh.subdivide_depth = subdivisions
	var node := MeshInstance3D.new(); node.name = node_name; node.mesh = mesh; node.position.y = height
	node.material_override = shader_material; node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func sync_cells(cells: Array) -> void:
	var spacing := Vector2(settings.cell_spacing[0],settings.cell_spacing[1])
	var centers := PackedVector2Array(); var minimum := Vector2(INF,INF); var maximum := Vector2(-INF,-INF)
	for cell in cells:
		if cell.status == "detached" or centers.size() >= int(settings.max_cells): continue
		var center := Vector2((cell.x-.5)*spacing.x,(cell.y-.5)*spacing.y)
		centers.append(center)
		minimum = minimum.min(center-spacing*0.5); maximum = maximum.max(center+spacing*0.5)
	for material_ref in [material,far_material]:
		material_ref.set_shader_parameter("cell_count",centers.size())
		if not centers.is_empty(): material_ref.set_shader_parameter("cell_centers",centers)
	if centers.is_empty(): return
	var center := (minimum+maximum)*.5; var half := (maximum-minimum)*.5
	raft_bounds = Vector4(center.x,center.y,half.x,half.y)
	for material_ref in [material,far_material]: material_ref.set_shader_parameter("raft_bounds",raft_bounds)
	for material_ref in mist_materials: material_ref.set_shader_parameter("clear_bounds",raft_bounds)

func set_lantern(position_world: Vector3) -> void:
	material.set_shader_parameter("lantern_position",position_world)

func fade_at(g: Vector2) -> float:
	var d := g.abs()
	return 1.0-smoothstep(_fade.x,_fade.y,maxf(d.x,d.y))

func contact_at(g: Vector2) -> float:
	var q := ((g-Vector2(raft_bounds.x,raft_bounds.y)).abs()-Vector2(raft_bounds.z,raft_bounds.w)).max(Vector2.ZERO)
	return 1.0-smoothstep(settings.contact_margin,settings.contact_margin+settings.contact_transition,q.length())

func _noise_hash(p: Vector2) -> float:
	var r := fposmod(p.x*37.0+p.y*73.0+float(settings.wave_noise.seed),251.0)
	return fposmod(r*r*17.0+r*13.0,251.0)/251.0

## Small integer lattice hash and cubic interpolation match the GPU exactly.
func _wave_noise(g: Vector2, index: int) -> float:
	var noise: Dictionary=settings.wave_noise
	var p := g*float(noise.scale)+Vector2(noise.drift[0],noise.drift[1])*time+Vector2(index*19,index*31)
	var cell:=p.floor(); var f:=p-cell
	var u:=f*f*(Vector2(3,3)-2.0*f)
	return lerpf(lerpf(_noise_hash(cell),_noise_hash(cell+Vector2(1,0)),u.x),lerpf(_noise_hash(cell+Vector2(0,1)),_noise_hash(cell+Vector2(1,1)),u.x),u.y)*2.0-1.0

## Same perturbed Gerstner sum as the vertex shader, scaled by distance fade.
func displacement(g: Vector2) -> Vector3:
	var d := Vector3.ZERO
	for i in range(_waves.size()):
		var wave: Dictionary=_waves[i]
		var noise: Dictionary=settings.wave_noise
		var perturbation:=_wave_noise(g,i) if noise.enabled else 0.0
		var amplitude:=1.0+float(noise.amplitude_strength)*perturbation
		var theta: float = wave.k*wave.dir.dot(g)-wave.omega*time+wave.phase+float(noise.phase_strength)*perturbation
		var horizontal: Vector2 = wave.dir*(wave.s/wave.k)*cos(theta)*amplitude
		d.x += horizontal.x; d.z += horizontal.y; d.y += wave.a*sin(theta)*amplitude
	return d*fade_at(g)

## World position of the displaced vertex whose undisplaced grid point is g.
func surface_point(g: Vector2) -> Vector3:
	var d := displacement(g); var b := contact_at(g)
	var xz := g+Vector2(d.x,d.z)*(1.0-b)
	return Vector3(xz.x,lerpf(d.y,plane_at(xz.x,xz.y),b),xz.y)

func _invert(target: Vector2, blended: bool) -> Vector2:
	var g := target
	for i in range(8):
		var d := displacement(g); var keep: float = 1.0-contact_at(g) if blended else 1.0
		g = target-Vector2(d.x,d.z)*keep
	return g

func raw_height_at(x: float, z: float) -> float:
	return displacement(_invert(Vector2(x,z),false)).y

func plane_at(x: float, z: float) -> float:
	return plane_height+plane_slope.dot(Vector2(x,z))

func height_at(x: float, z: float) -> float:
	var g := _invert(Vector2(x,z),true)
	return lerpf(displacement(g).y,plane_at(x,z),contact_at(g))

func _soft_limit(value: float, limit: float) -> float:
	# Smooth asymptotic cap: leaves ordinary slopes almost unchanged and avoids
	# the acceleration corner introduced by clampf() at the limit.
	var ratio := absf(value)/limit
	return value/pow(1.0+pow(ratio,8.0),0.125)

func tick(visual_time: float) -> void:
	time = visual_time
	var center := Vector2(raft_bounds.x,raft_bounds.y)
	var radius := Vector2(maxf(raft_bounds.z,.5),maxf(raft_bounds.w,.5))
	var left := raw_height_at(center.x-radius.x,center.y); var right := raw_height_at(center.x+radius.x,center.y)
	var front := raw_height_at(center.x,center.y+radius.y); var back := raw_height_at(center.x,center.y-radius.y)
	var limit: float = settings.slope_limit
	var target_slope := Vector2((right-left)/(radius.x*2),(front-back)/(radius.y*2))
	# Soft saturation preserves ordinary slopes while removing the hard-clamp corner.
	target_slope = Vector2(_soft_limit(target_slope.x,limit),_soft_limit(target_slope.y,limit))
	var target_height := (left+right+front+back+raw_height_at(center.x,center.y))/5.0-target_slope.dot(center)
	var delta := clampf(visual_time-_last_pose_time,0.0,0.1)
	_last_pose_time = visual_time
	if not _pose_initialized:
		plane_slope = target_slope
		plane_height = target_height
		_pose_initialized = true
	else:
		var motion: Dictionary = settings.raft_motion
		var slope_alpha := 1.0-exp(-delta/float(motion.slope_smoothing_seconds))
		var height_alpha := 1.0-exp(-delta/float(motion.height_smoothing_seconds))
		plane_slope = plane_slope.lerp(target_slope,slope_alpha)
		plane_height = lerpf(plane_height,target_height,height_alpha)
	for material_ref in mist_materials: material_ref.set_shader_parameter("visual_time",time)
	for material_ref in [material,far_material]:
		material_ref.set_shader_parameter("visual_time",time)
		material_ref.set_shader_parameter("plane_height",plane_height); material_ref.set_shader_parameter("plane_slope",plane_slope)
