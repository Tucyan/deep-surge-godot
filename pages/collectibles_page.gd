extends "res://pages/flow_base.gd"
const Placeholder=preload("res://presentation/collectible_art.gd")
const PAGE_SIZE:=20
var page_index:=0
var selected_uid:=""
var grid: GridContainer
var footer: HBoxContainer
var detail: VBoxContainer
var items: Array=[]

func build() -> void:
	name="CollectiblesWarehouse"
	items=context.get("collectibles",[])
	var header:=HBoxContainer.new(); add_child(header)
	W.text(header,"潮汐遗物",30,W.GOLD)
	var count:=W.text(header,"已持有 %d 件" % items.size(),20,W.MUTED); count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var close_space:=Control.new(); close_space.custom_minimum_size.x=52; header.add_child(close_space)
	var body:=HBoxContainer.new(); body.name="CollectionBody"; body.size_flags_vertical=Control.SIZE_EXPAND_FILL; add_child(body)
	body.add_theme_constant_override("separation",18)
	var left:=VBoxContainer.new(); left.size_flags_horizontal=Control.SIZE_EXPAND_FILL; left.size_flags_stretch_ratio=1.8; body.add_child(left)
	grid=GridContainer.new(); grid.name="CollectiblesGrid"; grid.columns=5
	grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",9); grid.add_theme_constant_override("v_separation",9); left.add_child(grid)
	footer=HBoxContainer.new(); footer.alignment=BoxContainer.ALIGNMENT_CENTER; left.add_child(footer)
	detail=W.panel(body); detail.name="CollectibleDetail"; detail.get_parent().name="CollectibleDetailSurface"
	detail.add_theme_constant_override("separation",12)
	_refresh_grid()

func _refresh_grid() -> void:
	for node in grid.get_children(): grid.remove_child(node); node.queue_free()
	for node in footer.get_children(): footer.remove_child(node); node.queue_free()
	var pages:=maxi(1,ceili(float(items.size())/PAGE_SIZE))
	page_index=clampi(page_index,0,pages-1)
	var visible_items: Array=items.slice(page_index*PAGE_SIZE,(page_index+1)*PAGE_SIZE)
	if not visible_items.any(func(item):return item.uid==selected_uid): selected_uid=visible_items[0].uid if not visible_items.is_empty() else ""
	for item in visible_items: _slot(item)
	for unused in range(PAGE_SIZE-visible_items.size()):
		var empty:=PanelContainer.new(); empty.custom_minimum_size=Vector2(80,80)
		empty.size_flags_horizontal=Control.SIZE_EXPAND_FILL; empty.size_flags_vertical=Control.SIZE_EXPAND_FILL
		empty.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var style:=StyleBoxFlat.new(); style.bg_color=Color(.04,.1,.17,.45); style.border_color=Color(.24,.34,.42,.35); style.set_border_width_all(1)
		empty.add_theme_stylebox_override("panel",style); grid.add_child(empty)
	W.button(footer,"上一页",func():page_index-=1; _refresh_grid(),page_index==0)
	W.text(footer,"%d / %d" % [page_index+1,pages],16).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	W.button(footer,"下一页",func():page_index+=1; _refresh_grid(),page_index==pages-1)
	for control in footer.get_children():
		control.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		control.custom_minimum_size.x=64 if control is Label else 96
	_refresh_detail()

func _slot(item: Dictionary) -> void:
	var button:=Button.new(); button.name="CollectibleSlot_"+item.uid; button.accessibility_name=item.name
	button.custom_minimum_size=Vector2(80,80); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.size_flags_vertical=Control.SIZE_EXPAND_FILL
	button.tooltip_text=item.name; grid.add_child(button)
	for state in ["normal","hover","pressed","focus"]:
		var style:=StyleBoxFlat.new(); style.bg_color=Color("102d50") if state=="normal" else Color("1a4160")
		style.border_color=W.GOLD if item.uid==selected_uid or state=="focus" else Color("435a6a")
		style.set_border_width_all(2 if item.uid==selected_uid else 1); style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state,style)
	var art:=Placeholder.new(); art.configure(item.id,assets); button.add_child(art)
	var title:=W.text(button,item.name,16,W.GOLD if item.uid==selected_uid else W.INK)
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE; title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.resized.connect(func():
		var side:=maxf(24,minf(86,minf(button.size.x-24,button.size.y-54)))
		art.size=Vector2(side,side); art.position=Vector2((button.size.x-side)*.5,12)
		title.position=Vector2(6,side+22); title.size=Vector2(button.size.x-12,button.size.y-side-24))
	button.pressed.connect(func():selected_uid=item.uid; _refresh_grid())

func _refresh_detail() -> void:
	for node in detail.get_children(): detail.remove_child(node); node.queue_free()
	var matches: Array=items.filter(func(item):return item.uid==selected_uid)
	if matches.is_empty():
		var empty:=W.text(detail,"尚未持有潮汐遗物\n\n在商店购买，或通过战斗与事件获得后，将收纳在这里。",19,W.MUTED)
		empty.name="CollectibleEmpty"; return
	var item: Dictionary=matches[0]
	var image_region:=CenterContainer.new(); image_region.name="CollectibleDetailImageRegion"
	image_region.size_flags_vertical=Control.SIZE_EXPAND_FILL; image_region.size_flags_stretch_ratio=1; detail.add_child(image_region)
	var art:=Placeholder.new(); art.configure(item.id,assets); image_region.add_child(art)
	image_region.resized.connect(func():
		var side:=maxf(1,minf(image_region.size.x,image_region.size.y)-8)
		art.custom_minimum_size=Vector2(side,side))
	var scroll:=ScrollContainer.new(); scroll.name="CollectibleDetailScroll"
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.size_flags_stretch_ratio=2
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; detail.add_child(scroll)
	var copy:=VBoxContainer.new(); copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(copy)
	W.text(copy,item.name,25,W.GOLD)
	W.text(copy,item.description,18)
	for effect in item.effects:
		if effect.type in ["install_level","grant_card","temporary_max"]:
			W.text(copy,"剩余次数：%d%s" % [effect.remaining," · 本场生效中" if effect.active else ""],16,W.MUTED)
	W.text(copy,"获得时奖励保留；丢弃后不再享受持有效果。",15,W.MUTED)
	var allowed: bool=context.get("can_base",false) and context.get("mode","")!="tutorial"
	var discard:=W.button(copy,"丢弃此遗物",func():send("discard_collectible",{"uid":item.uid}),not allowed,"仅可在航行导航、准备与收尾阶段丢弃。" if not allowed else "")
	discard.name="DiscardCollectible"
