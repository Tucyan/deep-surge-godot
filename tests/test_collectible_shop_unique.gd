extends SceneTree
const Session = preload("res://core/game_session.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _init() -> void:
	var catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(), "catalog loads")
	for pair in [["crimsonVial", "run"], ["hunterSpear", "held"]]:
		catalog._tables.relics[pair[0]].unique = pair[1]
		var s = Session.new(catalog)
		check(s.dispatch("new", {"mode":"challenge", "origin":"strong", "seed":22}), "new challenge")
		s.state.node = catalog.entry("nodes", "trader")
		s.state.node.visit_id = "unique-shop"
		s.state.phase = "story"
		s.state.story_step = "choice"
		s.Encounter.arrived(s)
		check(s.dispatch("shop_enter"), "open shop")
		s.state.shop.relics = [pair[0]]
		s.give("coin", 30)
		check(s.Collectibles.acquire(s, pair[0]), "already own unique relic")
		var frozen = s.snapshot()
		var row: Dictionary = s.Shop.view(s).relic_stock[0]
		check(not row.can_coin, "owned unique is disabled in quote: " + pair[0])
		check(not str(row.get("reason", "")).is_empty(), "owned unique quote explains limit")
		check(s.snapshot() == frozen, "quote is pure")
		check(not s.dispatch("buy_collectible", {"id":pair[0]}), "duplicate purchase denied")
		check(s.snapshot() == frozen, "denied purchase preserves coins and RNG")
		check(s.Collectibles.discard(s, s.state.collectibles.items[0].uid), "discard owned relic")
		row = s.Shop.view(s).relic_stock[0]
		check(row.can_coin == (pair[1] == "held"), "discard respects uniqueness tier")
	print("COLLECTIBLE SHOP UNIQUE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
