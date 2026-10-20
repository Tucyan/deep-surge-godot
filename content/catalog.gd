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
	for table in ["cards", "nodes", "enemies", "equipment", "boosts", "recipes", "shops", "meta_shop", "tech", "relics", "environments", "difficulties", "journeys", "layers", "balance", "node_pools", "navigation_profiles", "weather_profiles", "battle_templates", "shop_profiles", "difficulty_stage_profiles"]:
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
	if not preload("res://core/campaign_rules.gd").valid_content(pending):
		error="航程分层配置无效"; return false
	if not preload("res://core/survival_rules.gd").valid_content(pending):
		error="平衡参数无效"; return false
	if not preload("res://core/environment_rules.gd").valid_content(pending):
		error="天气投放或效果配置无效"; return false
	if not preload("res://core/encounter_rules.gd").valid_content(pending):
		error="节点投放或战斗配置无效"; return false
	if not preload("res://core/shop_rules.gd").valid_content(pending):
		error="商店配置无效"; return false
	if not valid_difficulty_stage_profiles(pending):
		error="难度层级节奏配置无效"; return false
	_tables = pending
	_fingerprint = JSON.stringify(_tables).sha256_text()
	return true

static func _integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) and int(value) >= minimum

static func _number(value: Variant, minimum: float = 0.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum

static func valid_difficulty_stage_profiles(tables: Dictionary) -> bool:
	var profiles: Variant = tables.get("difficulty_stage_profiles")
	var layer_ids: Variant=tables.get("journeys",{}).get("challenge",{}).get("layers")
	if not layer_ids is Array or layer_ids.is_empty(): return false
	var difficulties: Array=preload("res://core/difficulty_rules.gd").CHALLENGE_IDS
	if not profiles is Dictionary or profiles.size() != difficulties.size()*layer_ids.size(): return false
	for difficulty in difficulties:
		for layer_id in layer_ids:
			var id: String = difficulty + ":" + layer_id
			if not profiles.has(id): return false
			var profile: Variant = profiles[id]
			if not profile is Dictionary or profile.get("id") != id or profile.get("difficulty") != difficulty or profile.get("layer") != layer_id: return false
			var layer: Variant = tables.get("layers", {}).get(layer_id, {})
			if not layer is Dictionary: return false
			for key in ["node_pool", "navigation_profile", "weather_profile", "boss_node"]:
				if not profile.get(key) is String or profile[key].is_empty() or profile[key] != layer.get(key, ""): return false
			if not tables.get("node_pools", {}).has(profile.node_pool) or not tables.get("navigation_profiles", {}).has(profile.navigation_profile) or not tables.get("weather_profiles", {}).has(profile.weather_profile): return false
			if not tables.get("nodes", {}).has(profile.boss_node) or not tables.nodes[profile.boss_node].get("boss", false): return false
			var navigation: Dictionary = tables.navigation_profiles[profile.navigation_profile]
			if not profile.get("battle_templates") is Array or profile.battle_templates.is_empty(): return false
			var seen_templates: Array = []
			for template_id in profile.battle_templates:
				if not template_id is String or template_id in seen_templates or not tables.get("battle_templates", {}).has(template_id) or template_id not in navigation.get("template_ids", []): return false
				seen_templates.append(template_id)
			if not profile.get("voyage_bands") is Array or profile.voyage_bands.is_empty() or not _integer(profile.get("minimum_battles"), 0) or int(profile.minimum_battles) > int(navigation.get("slots", 0)) or not profile.get("all_battles") is bool or not _integer(profile.get("recovery_floor"), 1) or int(profile.recovery_floor) > int(navigation.get("slots", 0)) or not _integer(profile.get("continuous_battle_limit"), 0) or int(profile.continuous_battle_limit) > int(layer.get("length", 0)): return false
			if not profile.get("weather_multipliers") is Dictionary or not profile.weather_multipliers.has("negative") or not profile.weather_multipliers.has("positive"): return false
			for multiplier in profile.weather_multipliers.values():
				if not _number(multiplier): return false
			var weather: Dictionary=tables.weather_profiles[profile.weather_profile]
			if not profile.get("weather_weights") is Dictionary: return false
			for weather_id in profile.weather_weights:
				if not tables.environments.has(weather_id) or not _number(profile.weather_weights[weather_id]): return false
				if float(profile.weather_weights[weather_id])>0 and not weather.pool.has(weather_id): return false
			for key in ["weather_safe_voyages","all_battle_weather_episode_limit","all_battle_weather_last_start"]:
				if not _integer(profile.get(key)) or int(profile[key])>=int(layer.length): return false
			if not _integer(profile.get("all_battle_weather_limit"),1) or int(profile.all_battle_weather_limit)>int(layer.length): return false
			if not profile.get("weather_exclusive_groups") is Array: return false
			for group in profile.weather_exclusive_groups:
				if not group is Array or group.size()<2: return false
				var seen: Array=[]
				for weather_id in group:
					if not weather_id is String or weather_id in seen or not tables.environments.has(weather_id): return false
					seen.append(weather_id)
			var chance:=0.0
			for kind in ["negative","positive"]:
				chance+=float(tables.difficulties[difficulty][kind+"_chance"])*float(weather[kind+"_multiplier"])*float(profile.weather_multipliers[kind])
			if chance>1.0: return false
			if not profile.get("category_weights") is Dictionary or profile.category_weights.is_empty(): return false
			for category in profile.category_weights:
				if category not in ["supply", "trade", "service", "risk", "battle", "camp", "shop"]: return false
			for weight in profile.category_weights.values():
				if not _number(weight): return false
			var survival: Variant=profile.get("survival_multipliers")
			if not survival is Dictionary or survival.size()!=2: return false
			for stat in ["hunger","hydration"]:
				if not _number(survival.get(stat)): return false
			var target: Variant = profile.get("boss_target")
			if not target is Dictionary or not _integer(target.get("hp"), 1) or not _integer(target.get("damage"), 1): return false
			var previous_max := 0
			for band in profile.voyage_bands:
				if not band is Dictionary or not _integer(band.get("min_voyage"), 1) or not _integer(band.get("max_voyage"), 1) or int(band.min_voyage) > int(band.max_voyage) or int(band.min_voyage) != previous_max + 1 or int(band.max_voyage) > int(layer.get("length", 0)) or not _integer(band.get("minimum_battles"), 0) or not band.get("all_battles") is bool: return false
				if int(band.minimum_battles) > int(navigation.get("slots", 0)): return false
				previous_max = int(band.max_voyage)
			if previous_max != int(layer.get("length", 0)): return false
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
