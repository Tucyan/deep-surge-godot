extends "res://pages/flow_base.gd"
## Presentation-only selection and pagination; no rule command on page changes.
var body: HBoxContainer
var selected_table := ""
var detail: VBoxContainer

func build() -> void:
	match context.panel:
		"craft":
			heading("合成","选择配方查看材料，制造与安装分别收费。")
			list_body(["filter"] if context.get("tutorial_operation","") != "" else catalog.table("recipes").keys(),recipe_names(),Callable(self,"recipe_detail"))
		"shop":
			heading(context.node.name,"贝币 %d  ·  尸体 %d" % [context.coins,amount("corpse")])
			var ids: Array = catalog.table("shops").keys().filter(func(id): return catalog.entry("shops",id).has("card"))
			var names := {}
			for id in ids: names[id] = catalog.entry("shops",id).name
			list_body(ids,names,Callable(self,"shop_detail"))
			action(self,"离开商店","shop_leave")
		"raft": raft_page()
		"encyclopedia": encyclopedia()
		"meta_shop": meta_page()

func recipe_names() -> Dictionary:
	var names := {}
	for id in catalog.table("recipes"): names[id] = catalog.entry("recipes",id).name
	return names

func list_body(ids: Array, names: Dictionary, callback: Callable) -> void:
	body = HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(body)
	var left := W.panel(body,Vector2(320,0)); left.get_parent().size_flags_horizontal = 0
	var pages: int = maxi(1,ceili(float(ids.size())/6.0))
	var index: int = clampi(int(context.ui_state.get("list_page",0)),0,pages-1)
	var visible_ids: Array = ids.slice(index*6,mini(ids.size(),index*6+6))
	var selected: String = context.ui_state.get("selected_id","")
	if selected not in visible_ids: selected = str(visible_ids[0]) if not visible_ids.is_empty() else ""
	for id in visible_ids:
		var button := W.button(left,names[id],func(): request("selected_id",str(id)))
		if str(id) == selected: button.add_theme_color_override("font_color",W.GOLD)
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; left.add_child(spacer)
	pager(left,index,pages)
	detail = W.panel(body)
	if selected != "": callback.call(selected)
	else: W.text(detail,"当前没有可显示的内容。",20,W.MUTED)

func pager(parent: Node, index: int, pages: int) -> void:
	if pages <= 1: return
	var row := HBoxContainer.new(); parent.add_child(row)
	W.button(row,"上一页",func(): request("list_page",str(index-1)),index == 0)
	W.counter(row,"%d/%d" % [index+1,pages])
	W.button(row,"下一页",func(): request("list_page",str(index+1)),index == pages-1)

func recipe_detail(id: String) -> void:
	var recipe: Dictionary = catalog.entry("recipes",id)
	W.text(detail,recipe.name,27,W.GOLD)
	W.art(detail,assets,"card."+recipe.output,105)
	var valid: bool = context.ap >= recipe.cost
	if context.get("tutorial_operation","") != "" and context.tutorial_operation != "craft": valid = false
	for material in recipe.ingredients:
		W.text(detail,"%s   持有 %d / 需要 %d" % [catalog.entry("cards",material).name,amount(material),recipe.ingredients[material]],18)
		if amount(material) < recipe.ingredients[material]: valid = false
	if id == "spearRack" and "spear" not in context.profile.tech: valid = false
	W.text(detail,"基地AP %d  ·  安装需要另付1 AP" % context.ap,16,W.MUTED)
	if context.get("tutorial_operation","") in ["install","upgrade"]: W.text(detail,context.tutorial_reason,18,W.GOLD)
	action(detail,recipe.name+" · %d AP" % recipe.cost,"craft",{"id":id},not valid,"材料/AP不足或科技未解锁")

func shop_detail(id: String) -> void:
	var item: Dictionary = catalog.entry("shops",id)
	W.text(detail,item.name,27,W.GOLD)
	W.art(detail,assets,"card."+item.card,120)
	W.text(detail,catalog.entry("cards",item.card).description,18)
	var price: int = int(item.price)
	if int(context.profile.purchases.get("coupon",0)) > 0 and price > 1: price -= 1
	action(detail,"%d 贝币购买" % price,"buy",{"id":id,"payment":"coin"},context.coins < price)
	action(detail,"%d 尸体交换" % ceili(float(price)/2.0),"buy",{"id":id,"payment":"corpse"},amount("corpse") < ceili(float(price)/2.0))

func category_bar(categories: Dictionary, default_id: String) -> String:
	var category: String = context.ui_state.get("category","")
	if not categories.has(category): category = default_id
	var row := HBoxContainer.new(); add_child(row)
	for id in categories:
		W.button(row,categories[id],func(): request("category",id),id == category)
	return category

func encyclopedia() -> void:
	heading("图鉴","只显示已经发现的内容。")
	selected_table = category_bar({"cards":"卡牌","enemies":"怪物","relics":"藏品","endings":"结局"},"cards")
	var ids: Array = ending_names().keys() if selected_table == "endings" else catalog.table(selected_table).keys()
	var names := {}
	for id in ids:
		if discovered(id): names[id] = ending_names()[id] if selected_table == "endings" else catalog.entry(selected_table,id).name
		else: names[id] = "尚未发现 · %02d" % (ids.find(id)+1)
	list_body(ids,names,Callable(self,"encyclopedia_detail"))

func ending_names() -> Dictionary:
	return {"survived":"灯火未熄","withdrawn":"离开潮眼","true":"回声归航","dead":"沉入深潮","mad":"迷失潮声","abandon":"返回岸边"}

func discovered(id: String) -> bool:
	if selected_table == "endings": return id in context.profile.endings
	var prefix: String = {"cards":"card.","enemies":"enemy.","relics":"relic."}[selected_table]
	return prefix+id in context.profile.discovered

func encyclopedia_detail(id: String) -> void:
	if not discovered(id):
		W.art(detail,assets,"ui.card.back",190,false)
		W.text(detail,"尚未发现",28,W.MUTED)
		W.text(detail,"在航程中发现后解锁详情。",20,W.MUTED)
		return
	if selected_table == "endings":
		W.text(detail,ending_names()[id],28,W.GOLD)
		W.text(detail,"这段航程的结果已经记录。",20)
		return
	var data: Dictionary = catalog.entry(selected_table,id)
	W.text(detail,data.name,28,W.GOLD)
	var prefix: String = {"cards":"card.","enemies":"enemy.","relics":"relic."}[selected_table]
	W.art(detail,assets,prefix+id,130)
	W.text(detail,data.get("description",data.get("intent","")),20)

func meta_page() -> void:
	heading("局外商店","涌潮点 %d%s" % [context.profile.points," · 活动航程中，购买锁定" if context.active else ""])
	selected_table = category_bar({"meta_shop":"成长与补给","tech":"科技"},"meta_shop")
	var ids: Array = catalog.table(selected_table).keys().filter(func(id): return id != "blessing")
	var names := {}
	for id in ids: names[id] = catalog.entry(selected_table,id).name
	list_body(ids,names,Callable(self,"meta_detail"))

func meta_detail(id: String) -> void:
	var item: Dictionary = catalog.entry(selected_table,id)
	W.text(detail,item.name,28,W.GOLD)
	W.text(detail,item.description,20)
	W.text(detail,"价格 %d 涌潮点" % item.price,23,W.GOLD)
	var locked: bool = context.active or context.profile.points < item.price
	if selected_table == "tech":
		if id in context.profile.tech: locked = true; W.text(detail,"已经解锁",18,W.MUTED)
		for pre in item.requires:
			W.text(detail,"前置："+catalog.entry("tech",pre).name,18,W.MUTED)
			if pre not in context.profile.tech: locked = true
	else:
		W.text(detail,"累计购买 %d/%d" % [context.profile.purchases.get(id,0),item.maxPurchases],18,W.MUTED)
		if context.profile.purchases.get(id,0) >= item.maxPurchases: locked = true
	action(detail,"解锁" if selected_table == "tech" else "购买","tech" if selected_table == "tech" else "meta_buy",{"id":id},locked,"积分/前置不足，或活动航程锁定")

func raft_page() -> void:
	heading("木筏详情","选择一个筏格查看；导航、准备与收尾阶段可以操作。")
	body = HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(body)
	var map := W.panel(body,Vector2(440,0)); map.get_parent().size_flags_horizontal = 0
	W.text(map,"筏格布局",24,W.GOLD)
	var grid := W.grid(map,3 if int(context.profile.purchases.get("raft",0)) == 0 else 4)
	var side: int = grid.columns
	var selected: String = context.ui_state.get("selected_id","")
	if selected == "": selected = context.cells[0].id
	for y in range(side):
		for x in range(side):
			if context.flags.get("raft_layout","") == "123456" and y == 0 and x in [0,1]:
				var root_name := "帐篷" if x == 0 else "箱子"
				W.button(grid,"%d · %s" % [x+1,root_name],func(): pass,true,"固定装饰区，不提供设备槽位")
				continue
			var cell := {}
			var adjacent := false
			for c in context.cells:
				if c.x == x and c.y == y: cell = c
				if c.status != "detached" and absi(c.x-x)+absi(c.y-y) == 1: adjacent = true
			if not cell.is_empty() and cell.status != "detached":
				var label: String = "破损" if cell.status == "damaged" else ("空格" if cell.equipment.is_empty() else catalog.entry("equipment",cell.equipment.id).name)
				W.button(grid,"%d,%d\n%s" % [x+1,y+1,label],func(): request("selected_id",cell.id))
			else:
				var token := "pos:%d:%d" % [x,y]
				W.button(grid,"扩建\n%d,%d" % [x+1,y+1],func(): request("selected_id",token),not adjacent or not context.can_base or context.get("tutorial_operation","") != "")
	W.text(map,"基地AP %d · 木头 %d" % [context.ap,amount("wood")],18,W.MUTED)
	detail = W.panel(body)
	if selected.begins_with("pos:"):
		var parts := selected.split(":")
		W.text(detail,"扩建筏格",27,W.GOLD)
		W.text(detail,"木头2 · 基地AP1",22)
		action(detail,"扩建 (%d,%d)" % [int(parts[1]),int(parts[2])],"expand",{"x":int(parts[1]),"y":int(parts[2])},not context.can_base or context.ap < 1 or amount("wood") < 2)
		return
	for cell in context.cells:
		if cell.id == selected: cell_detail(cell)

func cell_detail(cell: Dictionary) -> void:
	W.text(detail,"筏格 %d,%d" % [cell.x+1,cell.y+1],27,W.GOLD)
	var disabled: bool = not context.can_base or context.ap < 1
	var teaching: String = context.get("tutorial_operation","")
	if cell.status == "damaged":
		W.text(detail,"破损 · 设备停用",22)
		var has_wood := amount("wood") >= 1
		var has_rope := amount("rope") >= 2
		var rep_text := "修理 · 木头1/AP1" if has_wood else ("修理 · 绳索2/AP1" if has_rope else "修理 · 木头1(或绳索2)/AP1")
		action(detail,rep_text,"repair_cell",{"cell":cell.id},disabled or (not has_wood and not has_rope))
		for card in context.hand:
			if card.id == "repair": action(detail,"使用修补包 · AP1","action_card",{"uid":card.uid,"cell":cell.id},disabled); break
		return
	if cell.equipment.is_empty():
		W.text(detail,"完好空格",22,W.MUTED)
		var held: Array = context.hand.filter(func(card): return card.definition.kind == "equipment")
		if teaching != "":
			held = held.filter(func(card): return card.id == "filter") if teaching == "install" else []
			if held.is_empty(): W.text(detail,context.tutorial_reason,18,W.GOLD); return
		if held.is_empty(): W.text(detail,"没有可安装设备牌。",18,W.MUTED); return
		var choices := OptionButton.new()
		for card in held: choices.add_item(card.definition.name)
		detail.add_child(choices)
		var button := W.button(detail,"安装 · "+held[0].definition.name,func(): send("install",{"cell":cell.id,"uid":held[choices.selected].uid}),disabled)
		choices.item_selected.connect(func(index): button.text = "安装 · "+held[index].definition.name)
		return
	var equipment: Dictionary = catalog.entry("equipment",cell.equipment.id)
	W.text(detail,"%s · %d级" % [equipment.name,cell.equipment.level],25)
	W.text(detail,equipment.description,18)
	if equipment.get("fuel",false):
		W.text(detail,"剩余燃料 %d" % cell.equipment.fuel,18,W.MUTED)
		var fuel_row := HBoxContainer.new(); detail.add_child(fuel_row)
		for material in ["wood","corpse"]: action(fuel_row,"投入 · "+catalog.entry("cards",material).name,"fuel",{"cell":cell.id,"material":material},not context.can_base or amount(material) == 0)
	if equipment.has("healing"): action(detail,"治疗 · 布条1/AP1","heal",{"cell":cell.id},disabled or amount("cloth") == 0)
	var donors: Array = []
	for other in context.cells:
		if other.id != cell.id and other.status == "intact" and other.equipment.get("id","") == cell.equipment.id and other.equipment.get("level",0) == cell.equipment.level:
			donors.append({"name":"消耗筏格%d,%d的设备" % [other.x+1,other.y+1],"args":{"cell":cell.id,"donor":other.id}})
	if cell.equipment.level == 1:
		for card in context.hand:
			if card.id == cell.equipment.id: donors.append({"name":"消耗同类设备牌","args":{"cell":cell.id,"uid":card.uid}})
	if not donors.is_empty() and cell.equipment.level < 3:
		var choices := OptionButton.new()
		for donor in donors: choices.add_item(donor.name)
		detail.add_child(choices)
		W.button(detail,"合并升级 · AP1",func(): send("upgrade",donors[choices.selected].args.duplicate(true)),disabled)
	for card in context.hand:
		if card.id == "dismantle":
			var materials: Array = catalog.entry("recipes",cell.equipment.id).ingredients.keys()
			var choices := OptionButton.new()
			for material in materials: choices.add_item("回收"+catalog.entry("cards",material).name)
			detail.add_child(choices)
			W.button(detail,"拆除设备 · AP1",func(): send("action_card",{"cell":cell.id,"uid":card.uid,"material":materials[choices.selected]}),disabled)
			break
