extends RefCounted
## Only this adapter knows physical art paths. No texture enters PageSession.
var _definitions: Dictionary = {}
var _cache: Dictionary = {}
var _placeholders: Dictionary = {}
var _models: Dictionary = {}
var _data: Dictionary = {}

func _init() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	if data is Dictionary:
		_definitions = data.get("assets", {})

## Warm at most one recipe page from local imported art. Decode in workers and
## finalize at most one ready resource per frame; never wait on an unfinished job.
## The normal texture() path remains the fallback when art is requested sooner.
func warm_textures(ids: Array, owner: Node) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree(): return
	var tree:=owner.get_tree()
	var pending: Dictionary={}
	for id in ids.slice(0,8):
		if _cache.has(id): continue
		var path: String=_definitions.get(id,{}).get("path","")
		if not path.begins_with("res://assets/") or ".." in path or not ResourceLoader.exists(path): continue
		if pending.has(path): pending[path].append(id); continue
		var error:=ResourceLoader.load_threaded_request(path,"Texture2D")
		if error==OK: pending[path]=[id]
	while not pending.is_empty():
		await tree.process_frame
		for path in pending.keys():
			var status:=ResourceLoader.load_threaded_get_status(path)
			if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
			if status==ResourceLoader.THREAD_LOAD_LOADED:
				var loaded:=ResourceLoader.load_threaded_get(path)
				if loaded is Texture2D and is_instance_valid(owner) and owner.is_inside_tree():
					for id in pending[path]: texture(id)
			pending.erase(path)
			break

func has_asset(asset_id: String) -> bool:
	return _definitions.has(asset_id)

func texture(asset_id: String) -> Texture2D:
	if asset_id in ["card.action_attack","card.attack"]:
		return texture("card.punch")
	if asset_id in ["card.action_block","card.block"]:
		if not _cache.has(asset_id): _cache[asset_id] = _create_shield_texture()
		return _cache[asset_id]
	if _cache.has(asset_id):
		return _cache[asset_id]
	var definition: Dictionary = _definitions.get(asset_id, {})
	var path: String = definition.get("path", "")
	if path.begins_with("res://assets/") and ".." not in path:
		if ResourceLoader.exists(path):
			var resource = load(path)
			if resource is Texture2D:
				if definition.get("region") is Array and definition.region.size() == 4:
					var region: Array = definition.region
					var atlas := AtlasTexture.new(); atlas.atlas = resource
					atlas.region = Rect2(region[0],region[1],region[2],region[3]); atlas.filter_clip = true
					resource = atlas
				_cache[asset_id] = resource
				_placeholders[asset_id] = false
				return resource
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img != null:
				var tex := ImageTexture.create_from_image(img)
				_cache[asset_id] = tex
				_placeholders[asset_id] = false
				return tex
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.from_string(definition.get("color", "#244b5b"), Color.DARK_SLATE_GRAY))
	var result := ImageTexture.create_from_image(image)
	_cache[asset_id] = result
	_placeholders[asset_id] = true
	return result

func label(asset_id: String) -> String:
	return _definitions.get(asset_id, {}).get("label", asset_id)

func show_label(asset_id: String) -> bool:
	texture(asset_id)
	return _definitions.get(asset_id, {}).get("show_label", _placeholders.get(asset_id, true))

func model(asset_id: String) -> PackedScene:
	if _models.has(asset_id): return _models[asset_id]
	var path: String = _definitions.get(asset_id,{}).get("path","")
	if path.begins_with("res://assets/") and ".." not in path and ResourceLoader.exists(path):
		var resource = load(path)
		if resource is PackedScene:
			_models[asset_id] = resource
			return resource
	return null

func data(asset_id: String) -> Dictionary:
	if _data.has(asset_id): return _data[asset_id].duplicate(true)
	var path: String = _definitions.get(asset_id,{}).get("path","")
	if path.begins_with("res://assets/data/") and ".." not in path:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary: _data[asset_id] = parsed; return parsed.duplicate(true)
	return {}

func bytes(asset_id: String) -> PackedByteArray:
	var path: String = _definitions.get(asset_id,{}).get("path","")
	if path.begins_with("res://assets/data/") and ".." not in path: return FileAccess.get_file_as_bytes(path)
	return PackedByteArray()

func _create_shield_texture() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	var gold := Color("ddcaa2"); var inner := Color("1b3240"); var dark := Color("12222d")
	for y in range(128):
		for x in range(128):
			var nx := (x - 64.0) / 48.0
			var ny := (y - 32.0) / 72.0
			if ny >= 0.0 and ny <= 1.0:
				var max_w := 1.0 - ny * ny * 0.7
				if absf(nx) <= max_w:
					var border_dist := max_w - absf(nx)
					if border_dist < 0.12 or ny < 0.08 or (1.0 - ny) < 0.08:
						img.set_pixel(x, y, gold)
					elif border_dist < 0.22:
						img.set_pixel(x, y, inner)
					else:
						img.set_pixel(x, y, dark)
	return ImageTexture.create_from_image(img)

