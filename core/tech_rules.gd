extends RefCounted
## Permanent technology; mutations are dispatched through GameSession.
static func count_lit(catalog, unlocked: Array, tier: int) -> int:
	var count := 0
	for id in catalog.table("tech"):
		if int(catalog.entry("tech",id).tier)==tier and id in unlocked: count+=1
	return count

static func gate_reason(catalog, unlocked: Array, id: String) -> String:
	var node: Dictionary=catalog.entry("tech",id)
	if node.is_empty(): return "科技节点不存在"
	var tier := int(node.tier)
	var needed := int(node.required_previous)
	if tier>1 and count_lit(catalog,unlocked,tier-1)<needed:
		return "需先点亮第%d层任意%d个节点（%d/%d）。" % [tier-1,needed,count_lit(catalog,unlocked,tier-1),needed]
	return ""

static func valid_profile(catalog, unlocked: Array) -> bool:
	var seen := {}
	for id in unlocked:
		if not id is String or seen.has(id) or catalog.entry("tech",id).is_empty(): return false
		seen[id]=true
	for id in unlocked:
		if gate_reason(catalog,unlocked,id)!="": return false
	return true

static func valid_definitions(nodes: Dictionary) -> bool:
	var counts := {1:0,2:0}
	for id in nodes:
		var node: Variant=nodes[id]
		if not node is Dictionary: return false
		if not (node.get("tier") is float or node.get("tier") is int): return false
		if int(node.tier) not in [1,2] or float(node.tier)!=floor(float(node.tier)) or not node.get("name") is String or not node.get("description") is String: return false
		if not node.get("price") is float and not node.get("price") is int: return false
		if node.price<=0 or floor(float(node.price))!=float(node.price): return false
		if node.get("required_previous")!=(0 if node.tier==1 else 2): return false
		if node.get("requires",[])!=[]: return false
		var modifiers: Variant=node.get("modifiers",{})
		if not modifiers is Dictionary: return false
		for key in modifiers:
			if key not in ["hpMax","hungerMax","hydrationMax","sanityMax","baseAp","battleAp","handLimit"]: return false
			if not (modifiers[key] is float or modifiers[key] is int) or modifiers[key]<=0 or floor(float(modifiers[key]))!=float(modifiers[key]): return false
		counts[int(node.tier)]+=1
	return counts[1]>=2 and counts[2]>0

static func projection(catalog, profile: Dictionary, active: bool) -> Dictionary:
	var result := {"points":profile.points,"active":active,"tiers":[],"nodes":[]}
	for tier in [1,2]:
		var lit := count_lit(catalog,profile.tech,tier)
		var total := 0
		for id in catalog.table("tech"):
			var node: Dictionary=catalog.entry("tech",id)
			if int(node.tier)!=tier: continue
			total+=1
			var reason := gate_reason(catalog,profile.tech,id)
			if id in profile.tech: reason="已经点亮"
			elif active: reason="活动航程中，科技点亮锁定。"
			elif reason=="" and profile.points<node.price: reason="涌潮点不足"
			result.nodes.append({"id":id,"name":node.name,"description":node.description,"tier":tier,"price":node.price,"lit":id in profile.tech,"allowed":reason=="","reason":reason})
		result.tiers.append({"tier":tier,"lit":lit,"total":total,"required_previous":0 if tier==1 else 2,"unlocked":tier==1 or count_lit(catalog,profile.tech,tier-1)>=2})
	return result
