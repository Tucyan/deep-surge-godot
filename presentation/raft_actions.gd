extends RefCounted
## UI labels/filtering over the shared core query at one captured revision.
const Query=preload("res://core/action_query.gd")
const Rules=preload("res://core/run_rules.gd")
var view: Dictionary
var _session: RefCounted
var _catalog: RefCounted
var _cache: Dictionary={}
func refresh(session: RefCounted) -> void:
	view=session.view(); _session=Query.fork(session); _catalog=session.catalog; _cache.clear()
func quote(command: String,args: Dictionary) -> Dictionary:
	var key:=command+JSON.stringify(args)
	if _cache.has(key): return _cache[key]
	var result: Dictionary=Query.quote(_session,command,args)
	result.args.revision=view.revision; _cache[key]=result
	return result
func cell_actions(id: String) -> Array:
	var found: Array=view.get("cells",[]).filter(func(c):return c.id==id and c.status!="detached")
	if found.is_empty() or not view.get("can_base",false): return []
	var cell: Dictionary=found[0]; var result: Array=[]
	if cell.status=="damaged":
		var repair:=quote("repair_cell",{"cell":id})
		var wood_count: int = view.hand.filter(func(c): return c.id == "wood" and not c.temporary).size()
		var rope_count: int = view.hand.filter(func(c): return c.id == "rope" and not c.temporary).size()
		if wood_count >= 1: repair.label = "修复 · 木头1 / AP1"
		elif rope_count >= 2: repair.label = "修复 · 绳索2 / AP1"
		else: repair.label = "修复 · 木头1或绳索2 / AP1"
		result.append(repair)
		for card in view.hand:
			if card.id=="repair":
				var action:=quote("action_card",{"cell":id,"uid":card.uid}); action.label="修复 · 修补包 / AP1"; result.append(action); break
	elif cell.equipment.is_empty():
		var seen: Dictionary={}
		for card in view.hand:
			if card.definition.kind=="equipment" and not seen.has(card.id):
				seen[card.id]=true
				var install:=quote("install",{"cell":id,"uid":card.uid}); install.label="安装 · "+card.definition.name; result.append(install)
	if not cell.equipment.is_empty():
		var upgrades: Array=[]
		if cell.equipment.level==1:
			var has_hand_card:=false
			for card in view.hand:
				if card.id==cell.equipment.id:
					var upgrade:=quote("upgrade",{"cell":id,"uid":card.uid}); upgrade.label="升级 · AP1"; upgrades.append(upgrade); has_hand_card=true; break
			if not has_hand_card:
				var upgrade:=quote("upgrade",{"cell":id}); upgrade.label="升级 · AP1"; upgrade.allowed=false; upgrade.reason="手牌中缺少同类设备牌"; upgrades.append(upgrade)
		result.append_array(upgrades)
		if cell.equipment.level==1 and cell.status=="intact":
			var recipe: Dictionary=_catalog.entry("recipes",cell.equipment.id)
			if not recipe.is_empty():
				var shortcut:=quote("upgrade",{"cell":id,"craft":true})
				shortcut.operation="craft_upgrade"; shortcut.label="一键升级 · AP%d" % (int(recipe.cost)+1)
				var materials: PackedStringArray=[]
				for material in recipe.ingredients: materials.append("%s×%d" % [_catalog.entry("cards",material).name,recipe.ingredients[material]])
				shortcut.detail="消耗："+"、".join(materials)+"\n制作%d AP＋升级1 AP" % recipe.cost
				result.append(shortcut)
		var dismantle:=quote("dismantle",{"cell":id})
		dismantle.operation="dismantle"
		dismantle.label="拆除 · AP1"
		var recipe: Dictionary=_catalog.entry("recipes",cell.equipment.id)
		if not recipe.is_empty() and not recipe.ingredients.is_empty():
			var mat: String = recipe.ingredients.keys()[0]
			var mat_name: String = _catalog.entry("cards",mat).name
			dismantle.detail="拆除该设备并回收 %s×1" % mat_name
		else:
			dismantle.detail="拆除该设备并腾出格位"
		result.append(dismantle)
	return result
func expansions() -> Array:
	if not view.get("can_base",false) or view.get("cells",[]).is_empty(): return []
	if view.cells.any(func(c):return c.status=="intact" and c.equipment.is_empty()): return []
	var result: Array=[]
	var side: int=4 if int(view.profile.purchases.get("raft",0))>0 else 3
	for y in range(side):
		for x in range(side):
			if view.get("flags",{}).get("raft_layout","")=="123456" and y==0 and x in [0,1]: continue
			if view.cells.any(func(c):return c.x==x and c.y==y and c.status!="detached"): continue
			if not view.cells.any(func(c):return c.status!="detached" and absi(c.x-x)+absi(c.y-y)==1): continue
			var item:=quote("expand",{"x":x,"y":y})
			item.x=x; item.y=y; item.id="expand:%d:%d" % [x,y]; item.kind="expand"
			item.cost=Rules.EXPANSION_COST.duplicate(); item.ap=Rules.EXPANSION_AP; result.append(item)
	return result.slice(0,1)
func targets() -> Array:
	var result: Array=[]
	for cell in view.get("cells",[]):
		if cell.status!="detached":
			var target: Dictionary=cell.duplicate(true); target.kind="cell"; result.append(target)
	result.append_array(expansions()); return result
