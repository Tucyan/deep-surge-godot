extends "res://pages/flow_base.gd"
## Presentation-only selection and pagination; no rule command on page changes.
var body: HBoxContainer
var selected_table := ""
var detail: VBoxContainer

func build() -> void:
	match context.panel:
		"craft":
			heading("合成","选择配方查看材料，制造消耗 AP，设备安装不消耗 AP。")
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
	W.text(detail,"基地AP %d  ·  安装不消耗 AP" % context.ap,16,W.MUTED)
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
	name = "Encyclopedia"
	W.text(self,"图鉴",30,W.GOLD)
	selected_table = category_bar({"cards":"卡牌","enemies":"怪物","relics":"潮汐遗物","endings":"结局"},"cards")
	var ids: Array = ending_names().keys() if selected_table == "endings" else catalog.table(selected_table).keys()
	body = HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(body)
	body.add_theme_constant_override("separation",18)
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.8; body.add_child(left)
	var grid := W.grid(left,2 if context.get("mobile",false) else 3); grid.name = "EncyclopediaGrid"
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pages := maxi(1,ceili(float(ids.size())/6.0))
	var index := clampi(int(context.ui_state.get("list_page",0)),0,pages-1)
	var visible_ids: Array = ids.slice(index*6,index*6+6)
	var selected: String = context.ui_state.get("selected_id","")
	if selected not in visible_ids: selected = str(visible_ids[0]) if not visible_ids.is_empty() else ""
	for id in visible_ids: encyclopedia_card(grid,str(id),ids.find(id)+1,str(id)==selected)
	# Keep the final page's card proportions identical to the preceding pages.
	for unused in range(6-visible_ids.size()):
		var space := Control.new(); space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		space.size_flags_horizontal = Control.SIZE_EXPAND_FILL; space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(space)
	var footer := HBoxContainer.new(); footer.alignment = BoxContainer.ALIGNMENT_CENTER; left.add_child(footer)
	pager(footer,index,pages)
	detail = W.panel(body); detail.name = "EncyclopediaDetail"
	detail.get_parent().size_flags_stretch_ratio = 1.0
	if selected != "": encyclopedia_detail(selected)
	else: W.text(detail,"当前没有可显示的内容。",18,W.MUTED)

func encyclopedia_art(id: String) -> String:
	if not discovered(id) or selected_table == "endings": return "ui.card.back"
	return {"cards":"card.","enemies":"enemy.","relics":"relic."}[selected_table]+id

func encyclopedia_card(grid: GridContainer, id: String, number: int, selected: bool) -> void:
	var title: String = "尚未发现 · %02d" % number
	if discovered(id): title = ending_names()[id] if selected_table == "endings" else catalog.entry(selected_table,id).name
	preview_card(grid,id,title,encyclopedia_art(id),selected,"EncyclopediaCard_")

func preview_card(grid: GridContainer, id: String, title: String, art: String, selected: bool, prefix: String, caption: String = "") -> void:
	var card := Button.new(); card.name = prefix+id
	card.set_meta("entry_id",id); card.accessibility_name = title
	card.custom_minimum_size = Vector2(0,120)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("143B83") if state in ["hover","pressed"] else Color("08224B")
		style.border_color = W.GOLD if selected else Color("536b87")
		if state == "focus": style.border_color = Color("F6EBDA")
		style.set_border_width_all(2 if selected or state == "focus" else 1)
		style.set_corner_radius_all(4); card.add_theme_stylebox_override(state,style)
	grid.add_child(card); card.pressed.connect(func(): request("selected_id",id))
	var margin := MarginContainer.new(); margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,12)
	var column := VBoxContainer.new(); column.mouse_filter = Control.MOUSE_FILTER_IGNORE; margin.add_child(column)
	W.art(column,assets,art,54,false)
	var cover: TextureRect = column.get_child(0); cover.name = "Cover"
	cover.size_flags_vertical = Control.SIZE_EXPAND_FILL; cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := W.text(column,title,18,W.GOLD if selected else W.INK); label.name = "EntryTitle"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF; label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if caption != "":
		var price := W.text(column,caption,15,W.MUTED); price.name = "ProductPrice"
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price.autowrap_mode = TextServer.AUTOWRAP_OFF
		card.custom_minimum_size.y = 160

func ending_names() -> Dictionary:
	return {"survived":"灯火未熄","withdrawn":"离开潮眼","true":"回声归航","dead":"沉入深潮","mad":"迷失潮声","abandon":"返回岸边"}

func discovered(id: String) -> bool:
	if selected_table == "endings": return id in context.profile.endings
	var prefix: String = {"cards":"card.","enemies":"enemy.","relics":"relic."}[selected_table]
	return prefix+id in context.profile.discovered

func encyclopedia_detail(id: String) -> void:
	W.art(detail,assets,encyclopedia_art(id),100,discovered(id) and selected_table != "endings")
	var image: TextureRect = detail.get_child(0); image.name = "DetailImage"
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var known := discovered(id)
	var data: Dictionary = catalog.entry(selected_table,id) if known and selected_table != "endings" else {}
	var title: String = ending_names()[id] if known and selected_table == "endings" else data.get("name","尚未发现")
	W.text(detail,title,24,W.GOLD if known else W.MUTED)
	var tab: String = context.ui_state.get("encyclopedia_tab","description")
	var tabs := HBoxContainer.new(); detail.add_child(tabs)
	var story := W.button(tabs,"故事",func(): request("encyclopedia_tab","story"),tab=="story")
	story.name = "EncyclopediaStoryTab"
	var description := W.button(tabs,"说明",func(): request("encyclopedia_tab","description"),tab!="story")
	description.name = "EncyclopediaDescriptionTab"
	var copy := "在航程中发现后解锁详情。"
	if known:
		if tab == "story": copy = data.get("story","故事内容暂未收录。")
		elif selected_table == "endings": copy = "这段航程的结果已经记录。"
		else: copy = str(data.get("description",data.get("intent","暂无说明。")))
	var text := W.text(detail,copy,18,W.INK if known else W.MUTED)
	text.name = "DetailCopy"; text.custom_minimum_size.y = 96
	if context.get("mobile",false):
		var scroll:=ScrollContainer.new(); scroll.name="MobileEncyclopediaCopy"
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		detail.remove_child(text); detail.add_child(scroll); scroll.add_child(text)

func meta_page() -> void:
	name = "MetaShop"
	var header := HBoxContainer.new(); add_child(header)
	W.text(header,"局外商店",30,W.GOLD)
	var balance := W.text(header,"涌潮点  %d" % context.profile.points,23,W.GOLD)
	balance.name = "MetaShopBalance"; balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var close_space := Control.new(); close_space.custom_minimum_size.x = 56; header.add_child(close_space)
	selected_table = category_bar({"meta_shop":"成长与补给","tech":"科技"},"meta_shop")
	if selected_table == "tech":
		tech_page(); return
	var ids: Array = catalog.table(selected_table).keys().filter(func(id): return id != "blessing")
	body = HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(body)
	body.add_theme_constant_override("separation",18)
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.8; body.add_child(left)
	var grid := W.grid(left,3); grid.name = "MetaShopGrid"; grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pages := maxi(1,ceili(float(ids.size())/6.0))
	var index := clampi(int(context.ui_state.get("list_page",0)),0,pages-1)
	var visible_ids := ids.slice(index*6,index*6+6)
	var selected: String = context.ui_state.get("selected_id","")
	if selected not in visible_ids: selected = str(visible_ids[0]) if not visible_ids.is_empty() else ""
	for id in visible_ids:
		var item: Dictionary = catalog.entry(selected_table,id)
		var status := meta_status(id)
		var caption := "%d 涌潮点 · %s" % [item.price,status]
		preview_card(grid,str(id),item.name,meta_art(str(id)),str(id)==selected,"MetaShopCard_",caption)
	for unused in range(6-visible_ids.size()):
		var space := Control.new(); space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		space.size_flags_horizontal = Control.SIZE_EXPAND_FILL; space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(space)
	var footer := HBoxContainer.new(); footer.alignment = BoxContainer.ALIGNMENT_CENTER; left.add_child(footer)
	pager(footer,index,pages)
	detail = W.panel(body); detail.name = "MetaShopDetail"
	detail.add_theme_constant_override("separation",8)
	if selected != "": meta_detail(selected)
	else: W.text(detail,"当前没有可显示的商品。",18,W.MUTED)

func meta_art(id: String) -> String:
	return {"raft":"card.wood","body":"card.medkit","inheritance":"icon.meta.inheritance","coupon":"icon.meta.coupon","hands":"card.repair","smallBox":"card.crate","bigBox":"card.crate","supply":"card.filter","knowledge":"card.lamp","craft":"card.repair","endurance":"card.calm","spear":"card.spearRack","vitality":"card.medkit","tactics":"card.crossbow"}.get(id,"ui.card.back")

func tech_page() -> void:
	body = HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(body)
	body.add_theme_constant_override("separation",18)
	var tree := VBoxContainer.new(); tree.name = "TechTree"
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tree.size_flags_stretch_ratio = 1.8; body.add_child(tree)
	var selected: String = context.ui_state.get("selected_id","")
	if not catalog.table("tech").has(selected): selected = "knowledge"
	var projection: Dictionary = context.tech_tree
	for tier in projection.tiers:
		var section := W.panel(tree); section.name = "TechTier_%d" % tier.tier
		section.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
		section.add_theme_constant_override("separation",4)
		var style: StyleBoxFlat = section.get_parent().get_theme_stylebox("panel").duplicate()
		style.content_margin_top = 10; style.content_margin_bottom = 10
		style.border_color = Color("536b87") if tier.unlocked else Color("334253")
		section.get_parent().add_theme_stylebox_override("panel",style)
		var title := "第一层 · 漂流基础" if int(tier.tier)==1 else "第二层 · 深潮进阶"
		W.text(section,"%s    %d / %d 已点亮" % [title,tier.lit,tier.total],20,W.GOLD if tier.unlocked else W.MUTED)
		var nodes := W.grid(section,3); nodes.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for node in projection.nodes:
			if int(node.tier)==int(tier.tier): tech_node(nodes,node,selected)
		if int(tier.tier)==1:
			var gate := W.text(tree,"──  第一层点亮 %d / 2   →   %s第二层  ──" % [tier.lit,"已解锁" if projection.tiers[1].unlocked else "解锁"],17,W.GOLD if projection.tiers[1].unlocked else W.MUTED)
			gate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail = W.panel(body); detail.name = "MetaShopDetail"; detail.add_theme_constant_override("separation",8)
	meta_detail(selected)

func tech_node(parent: GridContainer, node: Dictionary, selected: String) -> void:
	var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation",4); parent.add_child(column)
	var center := CenterContainer.new(); center.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(center)
	var point := Button.new(); point.name = "TechNode_"+node.id
	point.custom_minimum_size = Vector2(72,72); point.accessibility_name = node.name
	point.tooltip_text = node.description+"\n"+str(node.price)+" 涌潮点"+ ("\n"+node.reason if node.reason!="" else "")
	point.icon = assets.texture(meta_art(node.id)); point.expand_icon = true
	point.add_theme_constant_override("icon_max_width",42)
	point.modulate = Color("8a99ac") if node.reason.begins_with("需先") else Color.WHITE
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new(); style.set_corner_radius_all(38); style.set_border_width_all(2)
		style.bg_color = Color("143B83") if node.lit or state in ["hover","pressed"] else Color("08224B")
		style.border_color = W.GOLD if node.lit or selected==node.id else Color("536b87")
		if state=="focus": style.border_color = Color("F6EBDA")
		if selected==node.id: style.set_border_width_all(3)
		point.add_theme_stylebox_override(state,style)
	center.add_child(point); point.pressed.connect(func(): request("selected_id",node.id))
	var title := W.text(column,node.name,18,W.GOLD if node.lit or selected==node.id else W.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF; title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var state_text := "已点亮" if node.lit else ("层级锁定" if node.reason.begins_with("需先") else "未点亮")
	var price := W.text(column,"%d 涌潮点 · %s" % [node.price,state_text],15,W.GOLD if node.lit else W.MUTED)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func meta_status(id: String) -> String:
	var item: Dictionary = catalog.entry(selected_table,id)
	if selected_table == "tech":
		for node in context.tech_tree.nodes:
			if node.id == id: return "可点亮" if node.allowed else node.reason
	elif int(context.profile.purchases.get(id,0)) >= int(item.maxPurchases): return "已购满"
	if context.active: return "航程中锁定"
	if context.profile.points < item.price: return "涌潮点不足"
	return "可解锁" if selected_table == "tech" else "可购买"

func meta_detail(id: String) -> void:
	var item: Dictionary = catalog.entry(selected_table,id)
	W.art(detail,assets,meta_art(id),80,false)
	var image: TextureRect = detail.get_child(0); image.name = "DetailImage"
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	W.text(detail,item.name,24,W.GOLD)
	W.text(detail,item.description,18).name = "MetaShopDescription"
	if selected_table == "tech":
		W.text(detail,"第 %d 层 · 每个节点仅可点亮一次" % item.tier,16,W.MUTED)
	else:
		W.text(detail,"累计购买 %d / %d" % [context.profile.purchases.get(id,0),item.maxPurchases],16,W.MUTED)
	W.text(detail,"%d 涌潮点" % item.price,23,W.GOLD)
	var status := meta_status(id)
	var locked := status not in ["可购买","可点亮"]
	var reason := status
	if status == "航程中锁定": reason = "活动航程中，局外购买锁定。"
	W.text(detail,reason,16,W.MUTED if locked else W.GOLD).name = "MetaShopStatus"
	var purchase := W.button(detail,"点亮节点" if selected_table == "tech" else "购买",func(): send("tech" if selected_table == "tech" else "meta_buy",{"id":id}),locked,reason if locked else "")
	purchase.name = "MetaShopPurchase"
	if not locked: W.primary(purchase)

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
			if preload("res://core/raft_layout.gd").is_root(x,y):
				var root_number: int=preload("res://core/raft_layout.gd").number_at(x,y)
				var root_name := "帐篷" if root_number == 1 else "箱子"
				W.button(grid,"%d · %s" % [root_number,root_name],func(): pass,true,"固定装饰区，不提供设备槽位")
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
	W.text(map,"有效手牌上限 %d" % int(context.get("player",{}).get("limit",0)),16,W.GOLD)
	detail = W.panel(body)
	if selected.begins_with("pos:"):
		var parts := selected.split(":")
		W.text(detail,"扩建筏格",27,W.GOLD)
		var wood_cost: int=int(context.expansion_cost.wood)
		W.text(detail,"木头%d · 基地AP1" % wood_cost,22)
		action(detail,"扩建 (%d,%d)" % [int(parts[1]),int(parts[2])],"expand",{"x":int(parts[1]),"y":int(parts[2])},not context.can_base or context.ap < 1 or amount("wood") < wood_cost)
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
		var install_disabled: bool = not context.can_base
		var button := W.button(detail,"安装 · "+held[0].definition.name,func(): send("install",{"cell":cell.id,"uid":held[choices.selected].uid}),install_disabled)
		choices.item_selected.connect(func(index): button.text = "安装 · "+held[index].definition.name)
		return
	var equipment: Dictionary = catalog.entry("equipment",cell.equipment.id)
	W.text(detail,"%s · %d级" % [equipment.name,cell.equipment.level],25)
	W.text(detail,equipment.description,18)
	if equipment.get("fuel",false) or cell.equipment.id=="generator":
		var fuel_label:=W.text(detail,"剩余燃料 %d" % cell.equipment.fuel,18,W.MUTED)
		if cell.equipment.id=="generator": fuel_label.name="GeneratorFuel"
		var fuel_row := HBoxContainer.new(); detail.add_child(fuel_row)
		var materials: Array=["corpse"] if cell.equipment.id=="generator" else ["wood","corpse"]
		for material in materials:
			if cell.equipment.id=="generator":
				var fuel_button:=W.button(fuel_row,"投入尸体燃料 · +3",func():send("fuel",{"cell":cell.id,"material":"corpse"}),not context.can_base or amount("corpse")==0)
				fuel_button.name="GeneratorFuelButton"
			else: action(fuel_row,"投入 · "+catalog.entry("cards",material).name,"fuel",{"cell":cell.id,"material":material},not context.can_base or amount(material) == 0)
	if cell.equipment.id=="generator": generator_detail(cell,equipment)
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

func generator_detail(cell: Dictionary,equipment: Dictionary) -> void:
	var boosts: Array=cell.equipment.get("boost_cards",[])
	var capacity: int=int(equipment.get("capacities",[1])[clampi(int(cell.equipment.get("level",1))-1,0,equipment.get("capacities",[1]).size()-1)])
	var permanent: int=boosts.filter(func(boost):return not bool(boost.get("temporary",false)) and int(boost.get("expires_voyage",0))<=0).size()
	var ready: int=boosts.filter(func(boost):return boost.get("id","")=="ready").size()
	var temporary: int=boosts.filter(func(boost):return bool(boost.get("temporary",false)) or int(boost.get("expires_voyage",0))>0).size()
	var status:=W.text(detail,"生产进度 %d · 长期槽 %d/%d · 待领取 %d · 临时 %d" % [int(cell.equipment.get("progress",0)),permanent,capacity,ready,temporary],17,W.GOLD)
	status.name="GeneratorCapacity"
	var progress:=W.text(detail,"周期进度 %d · 燃料 %d" % [int(cell.equipment.get("progress",0)),int(cell.equipment.get("fuel",0))],15,W.MUTED); progress.name="GeneratorProgress"
	if temporary>0: W.text(detail,"临时增益 · 下轮结算消失",15,W.MUTED)
	var next_ready: Dictionary={}
	for boost in boosts:
		if boost.get("id","")=="ready":
			next_ready=boost
			break
	if not next_ready.is_empty():
		var row:=HBoxContainer.new(); detail.add_child(row)
		W.text(row,"领取下一张增益",15,W.INK)
		for id in ["power","barrier","production"]:
			var title: String={"power":"强击","barrier":"屏障","production":"增产"}[id]
			var claim:=W.button(row,title,func():send("claim_boost",{"cell":cell.id,"id":id}),not context.can_base)
			claim.name="ClaimBoost_"+str(next_ready.uid)+"_"+id
	production_targets(detail)

func production_targets(parent: Node) -> void:
	for boost in context.get("boost_cards",[]):
		if boost.get("id","")!="production": continue
		var targets: Array=[]
		for cell in context.cells:
			if cell.status=="intact" and cell.equipment.get("id","") in ["filter","planter","fishingNet"] and int(cell.equipment.get("production_bonus",0))==0:
				targets.append(cell)
		var row:=HBoxContainer.new(); parent.add_child(row)
		var expiry: String=" · 临时·下轮结算消失" if bool(boost.get("temporary",false)) or int(boost.get("expires_voyage",0))>0 else ""
		W.text(row,"增产增益%s →" % expiry,15,W.MUTED)
		if targets.is_empty():
			W.text(row,"没有可接收增益的滤水器、土盆或捕鱼网。",15,W.MUTED)
			continue
		var select:=OptionButton.new(); select.name="ProductionTargetSelect_"+str(boost.uid); row.add_child(select)
		for target in targets: select.add_item("%s · %d,%d" % [catalog.entry("equipment",target.equipment.id).name,int(target.x)+1,int(target.y)+1])
		var apply:=W.button(row,"确认增产",func():send("boost_device",{"cell":targets[select.selected].id,"buff_uid":boost.uid}))
		apply.name="ApplyProductionBoost_"+str(boost.uid); apply.disabled=not context.can_base
