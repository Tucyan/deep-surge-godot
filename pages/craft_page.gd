extends "res://pages/flow_base.gd"
const PAGE_SIZE := 8
const READY := Color("8dd6b6")
const MISSING := Color("df968b")

func box_style(background: Color, border: Color, margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=background; style.border_color=border
	style.set_border_width_all(1); style.set_corner_radius_all(7)
	style.content_margin_left=margin; style.content_margin_right=margin
	style.content_margin_top=margin; style.content_margin_bottom=margin
	return style

func badge(parent: Node, text: String, color: Color) -> void:
	var panel := PanelContainer.new(); parent.add_child(panel)
	panel.add_theme_stylebox_override("panel",box_style(Color("172d35"),Color("33565b"),5))
	var label := W.text(panel,text,16,color); label.autowrap_mode=TextServer.AUTOWRAP_OFF

func build() -> void:
	add_theme_constant_override("separation",10)
	W.text(self,"工具台 · 配方合成",27,W.INK)
	var inventory := PanelContainer.new(); inventory.name="CraftInventory"; add_child(inventory)
	inventory.add_theme_stylebox_override("panel",box_style(Color("0c1d26"),Color("2c4652"),8))
	var stock := HBoxContainer.new(); inventory.add_child(stock)
	W.text(stock,"材料库存",18,W.GOLD)
	badge(stock,"当前 AP: %d" % context.ap,READY)
	for id in ["wood","iron","plastic","cloth","rope"]:
		badge(stock,"%s %d" % [catalog.entry("cards",id).name,amount(id)],W.INK if amount(id)>0 else W.MUTED)
	var page_size: int=PAGE_SIZE
	var ids: Array=catalog.table("recipes").keys()
	var pages := maxi(1,ceili(float(ids.size())/page_size))
	var index := clampi(int(context.ui_state.get("list_page",0)),0,pages-1)
	var grid := GridContainer.new(); grid.name="RecipeGrid"; grid.columns=4
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",10); grid.add_theme_constant_override("v_separation",10)
	add_child(grid)
	for id in ids.slice(index*page_size,mini(ids.size(),(index+1)*page_size)): recipe_tile(grid,id)
	var footer := HBoxContainer.new(); add_child(footer)
	W.text(footer,"合成消耗 AP；设备安装另付 AP。",15,W.MUTED)
	W.button(footer,"上一页",func(): request("list_page",str(index-1)),index==0)
	W.counter(footer,"%d / %d" % [index+1,pages])
	W.button(footer,"下一页",func(): request("list_page",str(index+1)),index==pages-1)

func recipe_tile(grid: Node, id: String) -> void:
	var recipe: Dictionary=catalog.entry("recipes",id)
	var output: Dictionary=catalog.entry("cards",recipe.output)
	var reason := ""
	for material in recipe.ingredients:
		if amount(material)<recipe.ingredients[material]: reason="缺少材料"
	if context.ap<recipe.cost: reason="AP 不足"
	if id=="spearRack" and "spear" not in context.profile.tech: reason="需解锁科技"
	if context.get("tutorial_operation","") not in ["","craft"]:
		reason="先完成教学操作"
	elif context.get("tutorial_operation","")=="craft" and id!="filter":
		reason="教学需先合成滤水器"
	if not context.can_base: reason="当前阶段不可合成"
	var tile := PanelContainer.new(); tile.set_meta("recipe_id",id)
	tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tile.size_flags_vertical=Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel",box_style(Color("192f37"),Color("47796f") if reason=="" else Color("2c424b")))
	grid.add_child(tile)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",8); tile.add_child(column)
	var title := HBoxContainer.new(); column.add_child(title)
	W.text(title,output.name,22,W.INK)
	badge(title,"%d AP" % recipe.cost,W.GOLD)
	var description := W.text(column,output.description,17,W.MUTED)
	description.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var materials := HFlowContainer.new(); column.add_child(materials)
	materials.add_theme_constant_override("h_separation",5); materials.add_theme_constant_override("v_separation",5)
	for material in recipe.ingredients:
		var owned: int=amount(material); var needed: int=recipe.ingredients[material]
		badge(materials,"%s %d/%d" % [catalog.entry("cards",material).name,owned,needed],READY if owned>=needed else MISSING)
	var button := W.button(column,"合成" if reason=="" else reason,func(): send("craft",{"id":id}),reason!="",reason)
	button.name="CraftRecipeButton"; button.set_meta("recipe_id",id)
	button.custom_minimum_size.y=42; button.accessibility_name=recipe.name+" · %d AP" % recipe.cost
	for state in ["normal","hover","pressed"]:
		button.add_theme_stylebox_override(state,box_style(Color("32685e") if state=="normal" else Color("44897b"),Color("64a995"),7))
