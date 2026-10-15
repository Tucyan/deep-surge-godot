extends RefCounted
## UI preferences/order only; never writes inventory or consumes rule RNG.
var auto_sort := true
var stack_resources := true
var order: Array = []
var path := "user://hand-layout.cfg"
const KINDS := ["survival","resource","currency","equipment","action","combat","negative"]
const STACK_MINIMUM := 4
func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(path)!=OK: return
	auto_sort=bool(config.get_value("hand","auto_sort",true))
	stack_resources=bool(config.get_value("hand","stack_resources",true))
func save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("hand","auto_sort",auto_sort)
	config.set_value("hand","stack_resources",stack_resources)
	return config.save(path)
func build(entries: Array, force_unstack_resources: bool = false) -> Array:
	var sorted := entries.duplicate()
	if auto_sort:
		sorted.sort_custom(func(a,b):
			var ka: int = KINDS.find(a.definition.kind); var kb: int = KINDS.find(b.definition.kind)
			if ka!=kb: return ka<kb
			if a.id!=b.id: return a.id<b.id
			return entries.find(a)<entries.find(b))
	elif not order.is_empty():
		sorted.sort_custom(func(a,b):
			var ia: int = order.find(a.uid); var ib: int = order.find(b.uid)
			if ia<0: ia=order.size()+entries.find(a)
			if ib<0: ib=order.size()+entries.find(b)
			return ia<ib)
	var result: Array = []; var stacks := {}
	var resource_counts := {}
	for entry in sorted:
		if entry.definition.kind=="resource" and not entry.get("temporary",false):
			resource_counts[entry.id]=int(resource_counts.get(entry.id,0))+1
	for entry in sorted:
		# Temporary resources stay separate from permanent crafting inventory.
		var merge: bool = stack_resources and not force_unstack_resources and entry.definition.kind=="resource" and not entry.get("temporary",false) and int(resource_counts.get(entry.id,0))>=STACK_MINIMUM
		if merge and stacks.has(entry.id):
			var group: Dictionary = stacks[entry.id]; group.stack_count+=1; group.stack_uids.append(entry.uid)
		else:
			var group: Dictionary = entry.duplicate(true)
			group.stack_count=int(entry.get("quantity",1)); group.stack_uids=[entry.uid]; result.append(group)
			if merge: stacks[entry.id]=group
	return result
func move_group(groups: Array, from: int, to: int) -> void:
	if from<0 or to<0 or from>=groups.size() or to>=groups.size() or from==to: return
	var moved := groups.duplicate(); var group: Dictionary = moved.pop_at(from); moved.insert(to,group)
	var visible: Array = []
	for entry in moved: visible.append_array(entry.stack_uids)
	# Hidden battle cards keep their relative order when a battle-only fan moves.
	var slots: Array = order.filter(func(uid):return uid in visible)
	if slots.size()==visible.size():
		var index := 0
		for i in range(order.size()):
			if order[i] in visible: order[i]=visible[index]; index+=1
	else:
		var hidden: Array = order.filter(func(uid):return uid not in visible)
		order=visible+hidden
	auto_sort=false
