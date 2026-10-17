extends RefCounted
## UI preferences/order only; never writes inventory or consumes rule RNG.
var auto_sort := true
var stack_resources := true
const HOVER_MODES := ["spread","raise"]
var hover_mode := "spread"
var order: Array = []
var path := "user://hand-layout.cfg"
const KINDS := ["survival","resource","currency","equipment","action","combat","negative"]
const STACK_MINIMUM := 4

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(path)!=OK: return
	auto_sort=bool(config.get_value("hand","auto_sort",true))
	stack_resources=bool(config.get_value("hand","stack_resources",true))
	order=Array(config.get_value("hand","order",[]))
	var mode=config.get_value("hand","hover_mode","spread")
	hover_mode=mode if mode in HOVER_MODES else "spread"

func save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("hand","auto_sort",auto_sort)
	config.set_value("hand","stack_resources",stack_resources)
	config.set_value("hand","hover_mode",hover_mode if hover_mode in HOVER_MODES else "spread")
	config.set_value("hand","order",order)
	return config.save(path)

func build(entries: Array, force_unstack_resources: bool = false) -> Array:
	var entries_by_uid := {}
	for entry in entries:
		entries_by_uid[entry.uid] = entry

	var sorted := entries.duplicate()
	if not order.is_empty():
		# Prune any UIDs from order that are no longer in entries
		order = order.filter(func(uid): return entries_by_uid.has(uid))
		# Insert any newly acquired cards into order
		for entry in entries:
			if not order.has(entry.uid):
				if auto_sort:
					_insert_into_order(entry, entries_by_uid)
				else:
					order.append(entry.uid)
		sorted.sort_custom(func(a,b):
			var ia: int = order.find(a.uid); var ib: int = order.find(b.uid)
			if ia<0: ia=order.size()+entries.find(a)
			if ib<0: ib=order.size()+entries.find(b)
			return ia<ib)
	elif auto_sort:
		sorted.sort_custom(func(a,b):
			var ka: int = KINDS.find(a.definition.kind); var kb: int = KINDS.find(b.definition.kind)
			if ka!=kb: return ka<kb
			if a.id!=b.id: return a.id<b.id
			return entries.find(a)<entries.find(b))

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

func _insert_into_order(new_entry: Dictionary, entries_by_uid: Dictionary) -> void:
	var new_uid: String = new_entry.uid
	var new_id: String = new_entry.id
	var new_kind: String = str(new_entry.definition.kind)
	var new_kind_idx: int = KINDS.find(new_kind)

	# 1. Try to place next to cards with the exact same ID
	var last_same_id := -1
	for i in range(order.size()):
		var c = entries_by_uid.get(order[i])
		if c != null and c.id == new_id:
			last_same_id = i
	if last_same_id >= 0:
		order.insert(last_same_id + 1, new_uid)
		return

	# 2. Try to place within the same kind, maintaining ID alphabetical ordering
	var first_larger_id := -1
	var last_same_kind := -1
	for i in range(order.size()):
		var c = entries_by_uid.get(order[i])
		if c != null and c.definition.kind == new_kind:
			last_same_kind = i
			if first_larger_id < 0 and c.id > new_id:
				first_larger_id = i
	if first_larger_id >= 0:
		order.insert(first_larger_id, new_uid)
		return
	if last_same_kind >= 0:
		order.insert(last_same_kind + 1, new_uid)
		return

	# 3. Find neighbor kind based on KINDS order
	var insert_pos := 0
	var found_earlier := false
	for i in range(order.size()):
		var c = entries_by_uid.get(order[i])
		if c != null:
			var k_idx: int = KINDS.find(c.definition.kind)
			if k_idx <= new_kind_idx:
				insert_pos = i + 1
				found_earlier = true
	if found_earlier:
		order.insert(insert_pos, new_uid)
		return

	# If this kind precedes all existing kinds in order, put at 0
	order.insert(0, new_uid)

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
	# Keep auto_sort enabled while preserving user's custom ordering
