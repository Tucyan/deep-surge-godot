extends RefCounted
## Loads data at the composition boundary; consumers receive independent copies.
var _tables: Dictionary = {}
var error := ""

func load_catalog() -> bool:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://content/manifest.json"))
	if not manifest is Dictionary or not manifest.get("tables") is Dictionary:
		error = "内容清单格式错误"
		return false
	var pending := {}
	for table in ["cards", "nodes", "enemies", "equipment", "recipes", "shops", "meta_shop", "tech", "relics", "story_nodes", "story_config"]:
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
	for id in pending.story_nodes:
		var node: Dictionary = pending.story_nodes[id]
		if node.get("id") != id or not node.get("lines") is Array or node.lines.is_empty() or not node.get("choices") is Array or not node.get("art") is String or node.get("handler") not in ["survival","equipment","combat","route","door","public","final","epilogue","solo_exit"]:
			error = "测试剧情结构非法："+id; return false
		if node.has("monster") and not pending.enemies.has(node.monster): error = "教学怪物不存在"; return false
		for line in node.lines:
			if not line is String or line == "": error = "剧情文本为空"; return false
	var story: Dictionary = pending.story_config.get("first_layer",{})
	if story.get("version") != "test-story-v1" or story.get("length") != 15:
		error = "测试剧情配置版本无效"; return false
	for key in ["packs","solo_pack","rest","investigations","ordinary_quest","special_quest","exchange_reward","final_seal_costs","final_tow_costs"]:
		if not story.get(key) is Dictionary: error = "测试剧情缺少配置："+key; return false
	for schedule in ["fixed_days","public_nights"]:
		if not story.get(schedule) is Dictionary: error = "剧情日程缺失"; return false
		for id in story[schedule].values():
			if not pending.story_nodes.has(id): error = "固定事件引用不存在"; return false
	for pack in story.packs.values()+[story.solo_pack,story.exchange_reward,story.ordinary_quest.rewards]:
		if not pack is Dictionary: error = "测试剧情补给包格式错误"; return false
		for id in pack:
			if not pending.cards.has(id) or not (pack[id] is float or pack[id] is int) or pack[id] < 1 or floor(float(pack[id])) != float(pack[id]): error = "剧情补给引用/数量非法"; return false
	_tables = pending
	return true

func table(id: String) -> Dictionary:
	return _tables.get(id, {}).duplicate(true)

func entry(table_id: String, id: String) -> Dictionary:
	return _tables.get(table_id, {}).get(id, {}).duplicate(true)

func fingerprint() -> String:
	return JSON.stringify(_tables).sha256_text()

## Exact content fingerprint before the 2026-10-14 medkit/spear revision.
func previous_balance_fingerprint() -> String:
	var previous:=_tables.duplicate(true)
	previous.cards.medkit={"name":"包扎包","kind":"equipment","cost":1,"description":"安装后花1 AP与布条×1恢复生命8，高等级治疗更多。"}
	previous.cards.spear.description="造成4伤害；本场战斗有效。"; previous.cards.spear.damage=4
	previous.cards.spearRack.description="每战斗回合产生矛击。"
	previous.equipment.spearRack.description="战斗每回合产矛；升级提高伤害。"
	previous.equipment.spearRack.erase("battleStartOnly")
	return JSON.stringify(previous).sha256_text()

func legacy_fingerprint() -> String:
	var original := _tables.duplicate(true)
	original.erase("story_nodes"); original.erase("story_config")
	return JSON.stringify(original).sha256_text()
