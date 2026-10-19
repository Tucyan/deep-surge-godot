extends RefCounted
const Layout = preload("res://core/raft_layout.gd")
## Blender-authored geometry; runtime only instantiates modules and projects state labels.
const NAMES := {"lamp":"灯","filter":"滤水器","planter":"土盆","medkit":"包扎包","crossbow":"弓弩","spearRack":"矛架","shieldRack":"护盾架","generator":"发电机","fishingNet":"捕捞网","crate":"储物箱"}
var _production_definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/data/equipment.json"))
var _progress_texture: GradientTexture2D
func production_bar(parent: Node3D, equipment: Dictionary) -> void:
	var intervals: Array = _production_definitions.get(equipment.id,{}).get("intervals",[])
	if intervals.is_empty(): return
	var interval := int(intervals[clampi(int(equipment.level)-1,0,intervals.size()-1)])
	if interval <= 1: return
	# Display saved progress only; opening a view never forecasts or ticks production.
	var ratio := clampf(float(equipment.get("progress",0))/interval,0,1)
	if _progress_texture == null:
		_progress_texture=GradientTexture2D.new(); _progress_texture.width=160; _progress_texture.height=8
		var gradient:=Gradient.new(); gradient.colors=PackedColorArray([Color.WHITE,Color.WHITE]); _progress_texture.gradient=gradient
	var bar:=Node3D.new(); bar.name="ProductionProgress"; bar.position=Vector3(0,.36,.84); bar.set_meta("ratio",ratio); parent.add_child(bar)
	for fill in [false,true]:
		if fill and ratio<=0: continue
		var strip:=Sprite3D.new(); strip.name="Fill" if fill else "Track"; strip.texture=_progress_texture
		strip.billboard=BaseMaterial3D.BILLBOARD_ENABLED; strip.no_depth_test=true; strip.shaded=false
		strip.pixel_size=.009; strip.centered=false; strip.offset=Vector2(-80,-31)
		strip.modulate=Color("49b8ff") if fill else Color("17384e"); strip.render_priority=12 if fill else 11
		strip.region_enabled=true; strip.region_rect=Rect2(0,0,160*ratio if fill else 160,8)
		bar.add_child(strip)
func planter_stage(equipment: Dictionary) -> String:
	# Forecast the next round-start production tick; presentation never advances it.
	return "mature" if int(equipment.get("level",1)) >= 2 or int(equipment.get("progress",0)) >= 1 else "seedling"
func filter_stage(equipment: Dictionary) -> String:
	return "ready" if int(equipment.get("level",1)) >= 2 or int(equipment.get("progress",0)) >= 1 else "waiting"
func module(world,id: String) -> Node3D:
	var source: PackedScene = world._assets.model("model.raft.module."+id)
	if source == null:
		var fallback:=Node3D.new(); fallback.name="TemporaryEquipmentPlaceholder"
		fallback.set_meta("temporary_placeholder",true); fallback.set_meta("asset_id","model.raft.module."+id)
		var mesh:=MeshInstance3D.new(); var shape:=BoxMesh.new(); shape.size=Vector3(.72,.5,.55); mesh.mesh=shape
		var material:=StandardMaterial3D.new(); material.albedo_color=Color("95774f"); mesh.material_override=material; fallback.add_child(mesh)
		var marker:=Label3D.new(); marker.name="TemporaryModelLabel"; marker.text="临时模型 · "+NAMES.get(id,id); marker.font_size=24; marker.pixel_size=.01; marker.no_depth_test=true; fallback.add_child(marker)
		return fallback
	var result: Node3D = source.instantiate(); result.set_meta("blender_source",id); return result
func style_meshes(world,node: Node,intact: bool,deck: bool,lit: bool=false) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var source = node.get_active_material(i)
			if source is StandardMaterial3D:
				if deck and "Wood" in source.resource_name:
					node.set_surface_override_material(i,world.wet_wood(source.albedo_color))
				else:
					var key: String = "blender:"+str(source.get_instance_id())+str(intact)+str(lit)
					if not world._materials.has(key):
						var mat: StandardMaterial3D = source.duplicate()
						if not intact: mat.albedo_color *= Color(.48,.50,.53); mat.emission_enabled = false
						if "Glass" in node.name:
							mat.emission_enabled = lit; mat.emission = Color("e2ad64"); mat.emission_energy_multiplier = .55
						world._materials[key] = mat
					node.set_surface_override_material(i,world._materials[key])
	for child in node.get_children(): style_meshes(world,child,intact,deck,lit)
func label(parent: Node3D,font: Font,text: String,pos: Vector3,damaged: bool=false) -> void:
	var sign := Label3D.new(); sign.name = "StateLabel"; sign.font = font; sign.text = text; sign.font_size = 28; sign.pixel_size = .009
	# These are gameplay annotations: keep every line and outline readable
	# through the deck/equipment, while modal UI still renders above the viewport.
	sign.no_depth_test=true; sign.render_priority=10; sign.outline_render_priority=9
	sign.position = pos; sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED; sign.modulate = Color("e9b09a") if damaged else Color("dfd2ac"); sign.outline_modulate = Color("10262b"); parent.add_child(sign)
func build(world,cell: Dictionary,font: Font) -> Node3D:
	var tile := Node3D.new(); tile.name = cell.id; tile.position = Vector3((cell.x-.5)*2.35,.13,(cell.y-.5)*2.1)
	tile.set_meta("cell_id",cell.id); tile.set_meta("status",cell.status); tile.set_meta("blender_source",true)
	var damaged: bool = cell.status == "damaged"
	var variant := posmod(int(cell.x)+int(cell.y)*2,3)
	var deck_id := ("deck-damaged" if damaged else "deck-intact")+("" if variant==0 else "-%d" % (variant+1))
	var deck := module(world,deck_id); deck.name = "Deck"; tile.add_child(deck); style_meshes(world,deck,not damaged,true)
	if damaged:
		var marker := Node3D.new(); marker.name = "Damage"; tile.add_child(marker)
	var prefix: String = "%d,%d" % [cell.x+1,cell.y+1]
	if world._raft_layout == Layout.ID: prefix = str(Layout.number_at(int(cell.x),int(cell.y)))
	if world._raft_layout == "123456" and int(cell.x) < 3 and int(cell.y) < 2: prefix = str(int(cell.y)*3+int(cell.x)+1)
	var text: String = prefix+" · "+("破损" if damaged else "空位")
	if not cell.equipment.is_empty():
		var eq: Dictionary = cell.equipment; var active: bool = not damaged and (eq.id != "lamp" or int(eq.fuel)>0)
		var stage := planter_stage(eq) if eq.id == "planter" else ""
		var model_id: String = "planter-seedling" if stage == "seedling" else eq.id
		var water_stage := filter_stage(eq) if eq.id == "filter" else ""
		if water_stage == "waiting": model_id = "filter-waiting"
		var model := module(world,model_id); model.name = "Equipment"; model.set_meta("equipment_id",eq.id); model.set_meta("active",active)
		if eq.id == "planter": model.set_meta("growth_stage",stage)
		if eq.id == "filter": model.set_meta("production_stage",water_stage)
		tile.add_child(model); style_meshes(world,model,not damaged,false,active and eq.id=="lamp")
		text = prefix+" · "+NAMES.get(eq.id,eq.id)+" %d级" % int(eq.level)
		production_bar(tile,eq)
	label(tile,font,text,Vector3(0,.36,.84),damaged)
	return tile
func root_cells(layout: String=Layout.ID) -> Array:
	if layout == Layout.ID: return [{"id":"root-a","x":1,"y":1,"status":"intact","equipment":{}},{"id":"root-b","x":2,"y":1,"status":"intact","equipment":{}}]
	if layout != "123456": return [{"id":"root-a","x":-1,"y":0,"status":"intact","equipment":{}},{"id":"root-b","x":-1,"y":1,"status":"intact","equipment":{}}]
	return [{"id":"root-a","x":0,"y":0,"status":"intact","equipment":{}},{"id":"root-b","x":1,"y":0,"status":"intact","equipment":{}}]
func decorative_root(world,font: Font,layout: String=Layout.ID) -> Node3D:
	var base := module(world,"root-decor"); base.name = "DecorativeRoot"
	base.position = Vector3(0,.13,-1.05)
	if layout == Layout.ID: base.position += Vector3(2.35,0,2.1)
	elif layout != "123456": base.position = Vector3(-3.525,.13,0); base.rotation.y = PI/2
	style_meshes(world,base,true,true,true)
	var light := OmniLight3D.new(); light.name = "DecorativeLanternLight"
	light.position = Vector3(1.38,1.18,.32); light.light_color = Color("efbb79"); light.light_energy = .65; light.omni_range = 2.7
	base.add_child(light)
	var tent_light := OmniLight3D.new(); tent_light.name = "TentLanternLight"
	tent_light.position = Vector3(-1.50,.52,.40); tent_light.light_color = light.light_color; tent_light.light_energy = light.light_energy; tent_light.omni_range = 1.75
	tent_light.shadow_enabled = true; tent_light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	tent_light.shadow_opacity=world.shadow_opacity
	base.add_child(tent_light)
	var first_root: Dictionary=root_cells(layout)[0]
	var details_position:=Vector3((first_root.x-.5)*2.35,.48,(first_root.y-.5)*2.1+.84)
	label(base,font,"木筏详情",base.transform.affine_inverse()*details_position)
	var second_root: Dictionary=root_cells(layout)[1]
	var collection_position:=Vector3((second_root.x-.5)*2.35,.64,(second_root.y-.5)*2.1+.84)
	label(base,font,"潮汐遗物",base.transform.affine_inverse()*collection_position)
	base.get_child(base.get_child_count()-1).name="CollectiblesRootLabel"
	return base
