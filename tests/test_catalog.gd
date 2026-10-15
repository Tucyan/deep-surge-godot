extends SceneTree

func _init() -> void:
	var catalog = load("res://content/catalog.gd").new()
	assert(catalog.load_catalog(), catalog.error)
	assert(catalog.table("cards").size() == 26)
	for id in ["shieldRack","generator","fishingNet","crate"]:
		assert(catalog.entry("cards",id).kind=="equipment")
	assert(catalog.table("nodes").size() == 12)
	var card: Dictionary = catalog.entry("cards", "water")
	card.name = "changed"
	assert(catalog.entry("cards", "water").name == "淡水")
	var assets = load("res://presentation/asset_catalog.gd").new()
	var texture: Texture2D = assets.texture("card.water")
	assert(texture == assets.texture("card.water"))
	assert(texture.get_size() == Vector2(1312, 1199))
	assert(not assets.show_label("card.water"))
	assert(assets.texture("missing.id") != null)
	print("CATALOG / ASSET CACHE: PASS")
	quit(0)
