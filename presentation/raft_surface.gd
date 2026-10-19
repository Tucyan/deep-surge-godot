extends Node3D
const GHOST_HEIGHT := .30
const SEA_CLEARANCE := .025
const OUTLINE_WIDTH_SCALE := 1.4
const FILL_OPACITY := .16
const DECK_HIGHLIGHT_CLEARANCE := .002
## Visual picking and ghost instances, outside Raft so framing ignores previews.
var world: TextureRect
var selected: Node3D
var drop: Node3D
var _drop_key: String=""
func create(owner_world: TextureRect, expansions: Array) -> void:
	world=owner_world; name="RaftInteractionVisuals"
	world.world.add_child(self)
	for target in expansions:
		var ghost:=_ghost(target,"blue" if target.allowed else "red")
		ghost.name="Expansion_%d_%d" % [target.x,target.y]; ghost.set_meta("target",target)
	global_transform=world.raft.global_transform
	_update_expansion_heights()
func _process(_delta: float) -> void:
	if is_instance_valid(world.raft): global_transform=world.raft.global_transform
	_update_expansion_heights()
func sea_position(target: Dictionary) -> Vector3:
	var center: Vector3=world.raft.to_global(Vector3((target.x-.5)*2.35,0,(target.y-.5)*2.1))
	var height: float=-INF
	for x in [-1.12,0.0,1.12]:
		for z in [-1.0,0.0,1.0]:
			var sample_height: float=world.ocean.height_at(center.x+x,center.z+z) if world.ocean!=null else world.texture_ocean.sea.global_position.y
			height=maxf(height,sample_height)
	return Vector3(center.x,height+SEA_CLEARANCE,center.z)
func _update_expansion_heights() -> void:
	for child in get_children():
		if child.has_meta("target"):
			# Keep the blueprint nearly flat, above the highest local water sample.
			child.global_transform=Transform3D(Basis.IDENTITY.scaled(Vector3(1,.1,1)),sea_position(child.get_meta("target")))
func _material(tint: String) -> StandardMaterial3D:
	var key: String="interaction:"+tint
	if not world._materials.has(key):
		var mat:=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color={"blue":Color(.12,.62,1,.72),"red":Color(1,.17,.16,.72),"white":Color(1,1,1,.24),"green":Color(.12,1,.28,.24)}[tint]
		mat.emission_enabled=true; mat.emission=mat.albedo_color; mat.emission_energy_multiplier=.55
		world._materials[key]=mat
	return world._materials[key]
func _tint(node: Node,tint: String,outline: bool=false) -> void:
	if node is MeshInstance3D:
		node.material_override=_material(tint); node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if outline and tint in ["red","blue"]:
			# Widen each beam across its narrow horizontal axis about its own
			# centre, preserving slot footprint and beam lengths.
			var bounds: AABB=node.mesh.get_aabb()
			var factor:=Vector3.ONE
			if bounds.size.x<=bounds.size.z*1.1: factor.x=OUTLINE_WIDTH_SCALE
			if bounds.size.z<=bounds.size.x*1.1: factor.z=OUTLINE_WIDTH_SCALE
			node.position+=node.basis*(bounds.get_center()*(Vector3.ONE-factor))
			node.scale*=factor
	for child in node.get_children(): _tint(child,tint,outline)
func _add_fill(parent: Node3D,tint: String,mesh: Mesh=null) -> void:
	var key: String="interaction-fill:"+tint
	if not world._materials.has(key):
		var material: StandardMaterial3D=_material(tint).duplicate()
		material.albedo_color.a=.24 if tint in ["white","green"] else FILL_OPACITY; material.emission_enabled=false
		material.cull_mode=BaseMaterial3D.CULL_DISABLED; material.render_priority=-1
		world._materials[key]=material
	if mesh==null:
		if not world._meshes.has("interaction-fill"):
			var plane:=PlaneMesh.new(); plane.size=Vector2(2.20,1.96)
			world._meshes["interaction-fill"]=plane
		mesh=world._meshes["interaction-fill"]
	var fill:=MeshInstance3D.new(); fill.name="TranslucentFill"
	fill.mesh=mesh; fill.material_override=world._materials[key]
	fill.position.y=.015 if tint in ["red","blue"] else 0.0; fill.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fill)
func _deck_highlight_mesh(deck: Node3D) -> Mesh:
	var key: String="interaction-deck-top:"+str(deck.get_meta("blender_source"))
	if not world._meshes.has(key):
		var builder:=SurfaceTool.new(); builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for instance in deck.find_children("*","MeshInstance3D",true,false):
			if instance.mesh==null: continue
			var relative: Transform3D=deck.global_transform.affine_inverse()*instance.global_transform
			var normal_basis: Basis=relative.basis.inverse().transposed()
			for surface_index in range(instance.mesh.get_surface_count()):
				if instance.mesh.surface_get_primitive_type(surface_index)!=Mesh.PRIMITIVE_TRIANGLES: continue
				var arrays: Array=instance.mesh.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				var count: int=indices.size() if not indices.is_empty() else vertices.size()
				for offset in range(0,count,3):
					var triangle: Array[int]=[]; var normal:=Vector3.ZERO
					for corner in range(3):
						var index: int=indices[offset+corner] if not indices.is_empty() else offset+corner
						triangle.append(index); normal+=normal_basis*normals[index]
					# Copy only upward-facing deck surfaces, retaining gaps, bevels
					# and damaged-board shapes instead of hovering above their bounds.
					if normal.normalized().y<.65: continue
					for index in triangle:
						builder.set_normal(Vector3.UP)
						builder.add_vertex(relative*vertices[index]+Vector3.UP*DECK_HIGHLIGHT_CLEARANCE)
		world._meshes[key]=builder.commit()
	return world._meshes[key]
func _ghost(target: Dictionary,tint: String) -> Node3D:
	if tint in ["white","green"]:
		var highlight:=Node3D.new(); add_child(highlight)
		var deck: Node3D=world.cells.get_node(NodePath(str(target.id)+"/Deck"))
		highlight.transform=global_transform.affine_inverse()*deck.global_transform
		_add_fill(highlight,tint,_deck_highlight_mesh(deck))
		return highlight
	var scene: PackedScene=world._assets.model("model.raft.slot-ghost")
	var result: Node3D=scene.instantiate() if scene!=null else Node3D.new()
	add_child(result); result.position=Vector3((target.x-.5)*2.35,GHOST_HEIGHT,(target.y-.5)*2.1)
	_tint(result,tint,true)
	if tint in ["red","blue"]: _add_fill(result,tint)
	return result
func select(target: Dictionary) -> void:
	if is_instance_valid(selected): selected.queue_free()
	selected=null
	if not target.is_empty() and target.get("kind","")!="expand": selected=_ghost(target,"white"); selected.name="SelectedCellHighlight"
func show_drop(target: Dictionary,card: Dictionary,allowed: bool,upgrade: bool=false) -> void:
	var key: String=str(target.get("id",""))+str(card.get("id",""))+str(allowed)+str(upgrade)
	if key==_drop_key: return
	_drop_key=key
	if is_instance_valid(drop): drop.queue_free()
	drop=null
	if target.is_empty(): return
	drop=_ghost(target,"green" if allowed and upgrade else ("blue" if allowed else "red")); drop.name="EquipmentDropGhost"
	if upgrade: return
	var packed: PackedScene=world._assets.model("model.raft.module."+card.id) if card.definition.kind=="equipment" else null
	if packed!=null:
		var model: Node3D=packed.instantiate(); drop.add_child(model); model.position.y=-.18
		_tint(model,"blue" if allowed else "red")
func pick(point: Vector2,targets: Array) -> Dictionary:
	if world.size.x<=0 or world.size.y<=0: return {}
	var local_point: Vector2=world.get_global_transform().affine_inverse()*point
	if not Rect2(Vector2.ZERO,world.size).has_point(local_point): return {}
	var pixel:=local_point/world.size*Vector2(world.viewport.size)
	# Equipment can extend above its deck. Pick its visible mesh first so a
	# click on the device does not fall through to a neighbouring deck plane.
	var ray_origin: Vector3=world.camera.project_ray_origin(pixel)
	var ray_direction: Vector3=world.camera.project_ray_normal(pixel)
	var closest: float=INF
	var picked: Dictionary={}
	for target in targets:
		if target.get("kind","") not in ["cell","raft_details","collectibles"]: continue
		var tile: Node=world.cells.get_node_or_null(NodePath(target.id)) if target.kind=="cell" else world.raft.get_node_or_null("DecorativeRoot")
		if tile==null: continue
		for mesh in tile.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh==null or not mesh.is_visible_in_tree(): continue
			var inverse: Transform3D=mesh.global_transform.affine_inverse()
			var hit=mesh.mesh.get_aabb().intersects_ray(inverse*ray_origin,inverse.basis*ray_direction)
			if hit is Vector3:
				if target.kind in ["raft_details","collectibles"]:
					var local_hit: Vector3=world.raft.to_local(mesh.global_transform*hit)
					var center:=Vector2((target.x-.5)*2.35,(target.y-.5)*2.1)
					if not Rect2(center-Vector2(1.12,1),Vector2(2.24,2)).has_point(Vector2(local_hit.x,local_hit.z)): continue
				var distance: float=ray_origin.distance_squared_to(mesh.global_transform*hit)
				if distance<closest: closest=distance; picked=target
	if not picked.is_empty(): return picked
	var origin: Vector3=world.raft.to_local(world.camera.project_ray_origin(pixel))
	var direction: Vector3=world.raft.global_transform.basis.inverse()*world.camera.project_ray_normal(pixel)
	if absf(direction.y)<.00001: return {}
	var distance: float=(.4-origin.y)/direction.y
	if distance<=0: return {}
	var hit:=origin+direction*distance
	for target in targets:
		var sample: Vector3=hit
		if target.get("kind","")=="expand":
			if absf(ray_direction.y)<.00001: continue
			var sea: Vector3=sea_position(target)
			sample=world.raft.to_local(ray_origin+ray_direction*((sea.y-ray_origin.y)/ray_direction.y))
		var center:=Vector2((target.x-.5)*2.35,(target.y-.5)*2.1)
		if Rect2(center-Vector2(1.12,1),Vector2(2.24,2)).has_point(Vector2(sample.x,sample.z)): return target
	return {}
func screen_rect(target: Dictionary) -> Rect2:
	var tile: Node=world.cells.get_node_or_null(NodePath(str(target.get("id","")))) if target.get("kind","")=="cell" else null
	if tile==null: return Rect2(screen_point(target),Vector2.ZERO)
	var minimum:=Vector2(INF,INF); var maximum:=Vector2(-INF,-INF)
	for instance in tile.find_children("*","MeshInstance3D",true,false):
		if instance.mesh==null or not instance.is_visible_in_tree(): continue
		for corner in range(8):
			var pixel: Vector2=world.camera.unproject_position(instance.global_transform*instance.mesh.get_aabb().get_endpoint(corner))
			var point: Vector2=world.get_global_transform()*(pixel/Vector2(world.viewport.size)*world.size)
			minimum=minimum.min(point); maximum=maximum.max(point)
	return Rect2(minimum,maximum-minimum) if minimum.x!=INF else Rect2(screen_point(target),Vector2.ZERO)
func screen_point(target: Dictionary) -> Vector2:
	var local:=Vector3((target.x-.5)*2.35,.4,(target.y-.5)*2.1)
	var location: Vector3=sea_position(target) if target.get("kind","")=="expand" else world.raft.to_global(local)
	var pixel: Vector2=world.camera.unproject_position(location)
	return world.get_global_transform()*(pixel/Vector2(world.viewport.size)*world.size)
