extends RefCounted
## Reward descriptions are independent of shops, encounters and battle instances.
const Collectibles=preload("res://core/collectible_rules.gd")
const R=preload("res://core/random_streams.gd")

static func valid_entry(definitions: Dictionary, reward: Variant) -> bool:
	if not reward is Dictionary: return false
	if reward.has("id")==reward.has("pool"): return false
	var amount: Variant=reward.get("amount",1)
	if not Collectibles.number(amount) or amount<1: return false
	var ids: Variant=[reward.id] if reward.has("id") else reward.pool
	if not ids is Array or ids.is_empty(): return false
	var seen: Array=[]
	for id in ids:
		if not id is String or id in seen or not definitions.get(id,{}) is Dictionary: return false
		if not definitions.get(id,{}).get("enabled",false): return false
		seen.append(id)
	return true

static func valid_rewards(definitions: Dictionary, rewards: Variant) -> bool:
	if not rewards is Dictionary: return false
	var entries: Variant=rewards.get("relics",[])
	if not entries is Array: return false
	for entry in entries:
		if not valid_entry(definitions,entry): return false
	return true

static func effect_entry(effect: Dictionary) -> Dictionary:
	var result: Dictionary=effect.duplicate(true)
	result.erase("type")
	return result

static func valid_effects(definitions: Dictionary, effects: Array) -> bool:
	for effect in effects:
		if not effect is Dictionary: return false
		if effect.get("type","") not in ["GiveRelic","GiveRandomRelic"]: continue
		if effect.type=="GiveRelic" and (not effect.has("id") or effect.has("pool")): return false
		if effect.type=="GiveRandomRelic" and (not effect.has("pool") or effect.has("id")): return false
		if not valid_entry(definitions,effect_entry(effect)): return false
	return true

static func valid_content(definitions: Dictionary, value: Variant) -> bool:
	# Covers root nodes, variants, stages, battle offers and random outcomes.
	if value is Array:
		for child in value:
			if not valid_content(definitions,child): return false
	elif value is Dictionary:
		if value.has("rewards") and not valid_rewards(definitions,value.rewards): return false
		if value.has("effects") and (not value.effects is Array or not valid_effects(definitions,value.effects)): return false
		for child in value.values():
			if not valid_content(definitions,child): return false
	return true

static func grant(ctx, entries: Array, summary: Array) -> bool:
	if not valid_rewards(ctx.catalog.table("relics"),{"relics":entries}): return ctx.fail("潮汐遗物奖励配置无效")
	if entries.is_empty(): return true
	if ctx.state.get("mode","")=="tutorial": return ctx.fail("教程不能获得潮汐遗物")
	for entry in entries:
		for index in range(int(entry.get("amount",1))):
			# Preview never draws or reveals a random award, even on its copy.
			if entry.has("pool") and ctx._effect_preview: continue
			var id: String
			if entry.has("id"):
				id=entry.id
				if not Collectibles.eligible(ctx,id): return ctx.fail("潮汐遗物奖励发放失败：该遗物当前不可重复获得")
			else:
				var eligible: Array=Collectibles.eligible_ids(ctx,entry.pool)
				if eligible.is_empty():
					ctx.give("coin",2,false,"relic_pool_exhausted")
					var exchanged: String="遗物池已耗尽，改获贝币2枚。"
					ctx.log_text(exchanged); summary.append(exchanged)
					continue
				id=R.pick(ctx.state.rng,"rewards",eligible)
			if not Collectibles.acquire(ctx,id): return ctx.fail("潮汐遗物奖励发放失败")
			ctx.discover("relic."+id)
			var text: String="获得潮汐遗物："+str(ctx.catalog.entry("relics",id).name)
			ctx.log_text(text); summary.append(text)
	return true
