extends RefCounted
## Loads data at the composition boundary; consumers receive independent copies.
var _tables: Dictionary = {}
var error := ""
var _fingerprint := ""

func load_catalog() -> bool:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://content/manifest.json"))
	if not manifest is Dictionary or not manifest.get("tables") is Dictionary:
		error = "内容清单格式错误"
		return false
	var pending := {}
	for table in ["cards", "nodes", "enemies", "equipment", "boosts", "recipes", "shops", "meta_shop", "tech", "relics", "environments", "difficulties"]:
		var path: String = manifest.tables.get(table, "")
		if not path.begins_with("res://content/data/") or ".." in path:
			error = "内容路径非法：" + table
			return false
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or data.is_empty():
			error = "内容表格式错误：" + table
			return false
		pending[table] = data
	for id in pending.nodes:
		var node: Dictionary = pending.nodes[id]
		if node.get("monster", "") != "" and not pending.enemies.has(node.monster):
			error = "怪物引用不存在：" + id
			return false
	for id in pending.recipes:
		if not pending.cards.has(pending.recipes[id].output):
			error = "配方产物不存在：" + id
			return false
	for id in pending.environments:
		var d: Variant=pending.environments[id]
		if not d is Dictionary or d.get("id")!=id or not d.get("name") is String or not d.get("description") is String or not d.get("negative") is bool:
			error="环境定义格式错误："+str(id); return false
		for key in ["weight","duration"]:
			if not (d.get(key) is float or d.get(key) is int) or floor(float(d[key]))!=float(d[key]) or d[key]<(1 if key=="duration" else 0):
				error="环境参数无效："+str(id); return false
	if not preload("res://core/difficulty_rules.gd").valid(pending.difficulties):
		error="难度定义无效"; return false
	if not preload("res://core/tech_rules.gd").valid_definitions(pending.tech):
		error="科技分层定义无效"; return false
	if not preload("res://core/collectible_rules.gd").valid_definitions(pending.relics):
		error="潮汐遗物效果定义无效"; return false
	for definition in pending.relics.values():
		if not definition.get("enabled",false): continue
		for effect in definition.effects:
			if effect.type=="grant_card" and not pending.cards.has(effect.id):
				error="潮汐遗物产物不存在："+str(effect.id); return false
	if not preload("res://core/relic_rewards.gd").valid_content(pending.relics,pending.nodes):
		error="节点潮汐遗物奖励配置无效"; return false
	_tables = pending
	_fingerprint = JSON.stringify(_tables).sha256_text()
	return true

func table(id: String) -> Dictionary:
	return _tables.get(id, {}).duplicate(true)

func entry(table_id: String, id: String) -> Dictionary:
	return _tables.get(table_id, {}).get(id, {}).duplicate(true)

func fingerprint() -> String:
	return _fingerprint

## Exact content fingerprint before round-start production (2026-10-15).
func previous_production_fingerprint() -> String:
	return "5cb5232ab877fd50088ba7a3143e45b6e2c79f294bd86843d1da7497ad316dcc"

## Exact content fingerprint before the 2026-10-14 medkit/spear revision.
func previous_balance_fingerprint() -> String:
	return "be2b3aebf83c9a36beb2fc99c8a174de78eaf5ba2749883584b4e3b2b67cc9fe"

func prior_flow_fingerprint() -> String:
	return "a7bff4df6d81283c3f09e76b8af60e1298f985da4b90a4a3adfcac25709e4f9c"

func legacy_fingerprint() -> String:
	return "05bc868335a128050d30745c9a0d0c47b862a1c78d9f169367e55b04bb6bb134"
