extends RefCounted
const Stats = preload("res://core/run_statistics.gd")
const Effects = preload("res://core/effect_query.gd")
const RESOURCES := ["wood", "iron", "plastic", "rope", "cloth"]

static func count(state: Dictionary, id: String) -> int:
	if id == "coin":
		return state.coins
	var total := 0
	for card in state.hand:
		if card.id == id and not card.temporary:
			total += 1
	return total

static func give(state: Dictionary, id: String, amount: int = 1, temporary: bool = false, source: String = "reward") -> void:
	if id == "coin":
		state.coins += amount
		Stats.card(state,id,"obtained",amount,source)
		return
	for i in range(amount):
		state.hand.append({"uid": "card-%d" % state.next_id, "id":id, "temporary":temporary, "source":source})
		state.next_id += 1
		Stats.card(state,id,"obtained",1,source,state.hand[-1].uid)

static func consume(state: Dictionary, id: String, amount: int, reason: String = "cost") -> bool:
	if count(state, id) < amount:
		return false
	if id == "coin":
		state.coins -= amount
		Stats.card(state,id,"cost_consumed",amount,reason)
		return true
	for i in range(amount):
		for index in range(state.hand.size()):
			if state.hand[index].id == id and not state.hand[index].temporary:
				Stats.card(state,id,"cost_consumed",1,reason,state.hand[index].uid)
				state.hand.remove_at(index)
				break
	return true

static func capacity(state: Dictionary) -> int:
	var ordinary := 0
	var arrow_groups := {}
	for card in state.hand:
		if card.id == "arrow" and int(card.get("stack_limit",1)) > 1:
			var limit: int = int(card.stack_limit)
			arrow_groups[limit] = int(arrow_groups.get(limit,0)) + 1
		else: ordinary += 1
	for limit in arrow_groups: ordinary += ceili(float(arrow_groups[limit])/float(limit))
	return ordinary + (1 if state.coins > 0 else 0)

static func hand_limit(state: Dictionary, catalog: RefCounted) -> int:
	var result: int = int(state.get("player", {}).get("limit", 10))
	for cell in state.get("cells", []):
		if cell.get("status", "") != "intact": continue
		var equipment: Dictionary = cell.get("equipment", {})
		if equipment.get("id", "") == "crate":
			var level: int=clampi(int(equipment.get("level",1)),1,3)
			result += int(catalog.entry("equipment", "crate").get("capacity", [1,2,3])[level-1])
	return maxi(1,result+Effects.modifier(state,catalog,"inventory.limit"))

static func find(state: Dictionary, uid: String) -> Dictionary:
	for card in state.hand:
		if card.uid == uid:
			return card
	return {}

static func remove(state: Dictionary, uid: String, reason: String = "use_consumed") -> void:
	for i in range(state.hand.size()):
		if state.hand[i].uid == uid:
			Stats.card(state,state.hand[i].id,reason,1,state.get("_stat_command","system"),uid)
			state.hand.remove_at(i)
			return
