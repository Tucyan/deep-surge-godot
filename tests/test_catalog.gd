extends SceneTree

var failures := 0
func check(ok: bool, reason: String = "catalog assertion") -> void:
	if not ok: failures += 1; printerr("FAIL: " + reason)

func _init() -> void:
	var catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(), catalog.error)
	check(catalog.table("cards").size() == 26)
	for id in ["shieldRack","generator","fishingNet","crate"]:
		check(catalog.entry("cards",id).kind=="equipment")
	check(catalog.table("nodes").size() == 37, "18 base nodes, three layer bosses, eleven retired relic nodes and five replacement collectible nodes")
	var card: Dictionary = catalog.entry("cards", "water")
	card.name = "changed"
	check(catalog.entry("cards", "water").name == "淡水")
	var assets = load("res://presentation/asset_catalog.gd").new()
	var texture: Texture2D = assets.texture("card.water")
	check(texture == assets.texture("card.water"))
	check(texture.get_size() == Vector2(1312, 1199))
	check(not assets.show_label("card.water"))
	check(assets.texture("missing.id") != null)
	print("CATALOG / ASSET CACHE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
