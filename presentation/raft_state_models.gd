extends RefCounted
## Blender-authored geometry; runtime only instantiates modules and projects state labels.
const NAMES := {"lamp":"灯","filter":"滤水器","planter":"土盆","medkit":"包扎包","crossbow":"弓弩","spearRack":"矛架"}
func module(world,id: String) -> Node3D:
	var source: PackedScene = world._assets.model("model.raft.module."+id)
	if source == null: push_error("Missing Blender raft module: "+id); return Node3D.new()
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
	if world._raft_layout == "123456" and int(cell.x) < 3 and int(cell.y) < 2: prefix = str(int(cell.y)*3+int(cell.x)+1)
	var text: String = prefix+" · "+("破损" if damaged else "空位")
	if not cell.equipment.is_empty():
		var eq: Dictionary = cell.equipment; var active: bool = not damaged and (eq.id != "lamp" or int(eq.fuel)>0)
		var model := module(world,eq.id); model.name = "Equipment"; model.set_meta("equipment_id",eq.id); model.set_meta("active",active)
		tile.add_child(model); style_meshes(world,model,not damaged,false,active and eq.id=="lamp")
		text = prefix+" · "+NAMES.get(eq.id,eq.id)+" %d级" % int(eq.level)
		if damaged: text += "\n停用 · 待修补"
		elif eq.id == "lamp": text += "\n燃料 %d" % int(eq.fuel)
	elif damaged: text += "\n待修补"
	label(tile,font,text,Vector3(0,.36,.84),damaged)
	return tile
func root_cells(layout: String="123456") -> Array:
	if layout != "123456": return [{"id":"root-a","x":-1,"y":0,"status":"intact","equipment":{}},{"id":"root-b","x":-1,"y":1,"status":"intact","equipment":{}}]
	return [{"id":"root-a","x":0,"y":0,"status":"intact","equipment":{}},{"id":"root-b","x":1,"y":0,"status":"intact","equipment":{}}]
func decorative_root(world,font: Font,layout: String="123456") -> Node3D:
	var base := module(world,"root-decor"); base.name = "DecorativeRoot"
	base.position = Vector3(0,.13,-1.05)
	if layout != "123456": base.position = Vector3(-3.525,.13,0); base.rotation.y = PI/2
	style_meshes(world,base,true,true,true)
	var light := OmniLight3D.new(); light.name = "DecorativeLanternLight"
	light.position = Vector3(1.38,1.18,.32); light.light_color = Color("efbb79"); light.light_energy = .65; light.omni_range = 2.7
	base.add_child(light)
	var tent_light := OmniLight3D.new(); tent_light.name = "TentLanternLight"
	tent_light.position = Vector3(-1.50,.52,.40); tent_light.light_color = light.light_color; tent_light.light_energy = light.light_energy; tent_light.omni_range = 1.75
	tent_light.shadow_enabled = true; tent_light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	base.add_child(tent_light)
	label(base,font,"1 · 2  装饰筏根" if layout == "123456" else "装饰筏根",Vector3(0,.35,.84))
	return base
