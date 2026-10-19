extends Control
signal completed
signal arrived
const W=preload("res://presentation/widgets.gd")
const ItemCard=preload("res://presentation/item_card.gd")
const RelicArt=preload("res://presentation/collectible_art.gd")
@export var backdrop_color:=Color(.03,.08,.11,.86)
@export var flight_duration:=.48
var batch: Dictionary
var assets: RefCounted
var destination:=Vector2.ZERO
var collecting:=false
var prepare_collection: Callable
var page_index:=0
var per_page:=6
var tiles: Array[Control]=[]
var title: Label
var description: Label
var hint: Label
var card_area: Control
var inspection: PanelContainer
var pagination: HBoxContainer

func configure(data: Dictionary, visual_assets: RefCounted, target: Vector2) -> void:
	batch=data; assets=visual_assets; destination=target
	name="AcquisitionOverlay"; z_index=4090; mouse_filter=Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade:=ColorRect.new(); shade.name="AcquisitionShade"; shade.color=backdrop_color
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title=W.text(self,"你获得了 %d 件潮汐遗物：" % batch.items.size() if batch.kind=="collectible" else "你通过%s获得了 %d 张卡牌：" % [batch.source,batch.items.size()],28,W.GOLD)
	title.name="AcquisitionTitle"; title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card_area=Control.new(); card_area.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(card_area)
	inspection=PanelContainer.new(); inspection.name="AcquisitionInspection"; add_child(inspection)
	inspection.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new(); style.bg_color=Color(.04,.1,.13,.94); style.border_color=W.GOLD
	style.set_border_width_all(1); style.set_corner_radius_all(8)
	style.content_margin_left=20; style.content_margin_right=20; style.content_margin_top=12; style.content_margin_bottom=12
	inspection.add_theme_stylebox_override("panel",style)
	description=W.text(inspection,"",18); description.name="AcquisitionDescription"; description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	description.mouse_filter=Control.MOUSE_FILTER_IGNORE
	inspection.hide()
	pagination=HBoxContainer.new(); pagination.alignment=BoxContainer.ALIGNMENT_CENTER; add_child(pagination)
	hint=W.text(self,"点击卡牌查看说明 · 点击空白处收入手牌" if batch.kind=="card" else "点击藏品查看说明 · 点击空白处收入仓库",16,W.MUTED)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	gui_input.connect(_background_input); resized.connect(_layout)
	_layout()
	modulate.a=0
	create_tween().tween_property(self,"modulate:a",1.0,.18)

func _layout() -> void:
	if collecting or not is_instance_valid(title): return
	title.position=Vector2(size.x*.08,size.y*.14); title.size=Vector2(size.x*.84,70)
	card_area.position=Vector2(size.x*.08,size.y*.27); card_area.size=Vector2(size.x*.84,size.y*.43)
	inspection.position=Vector2(size.x*.18,size.y*.73); inspection.size=Vector2(size.x*.64,0)
	inspection.custom_minimum_size.y=70
	hint.position=Vector2(size.x*.08,size.y*.9); hint.size=Vector2(size.x*.84,36)
	pagination.position=Vector2(size.x*.35,size.y*.69); pagination.size=Vector2(size.x*.3,30)
	per_page=clampi(int(card_area.size.x/145.0),1,6)
	_build_page()

func _build_page() -> void:
	for tile in tiles: card_area.remove_child(tile); tile.queue_free()
	tiles.clear()
	for child in pagination.get_children(): pagination.remove_child(child); child.queue_free()
	var pages:=maxi(1,ceili(float(batch.items.size())/per_page))
	page_index=clampi(page_index,0,pages-1)
	var items: Array=batch.items.slice(page_index*per_page,(page_index+1)*per_page)
	var height:=minf(270,card_area.size.y-8)
	var width:=height*2.0/3.0 if batch.kind=="card" else height*.65
	width=minf(width,card_area.size.x/maxi(1,items.size())-14)
	if batch.kind=="card": height=minf(height,width*1.5)
	var span:=items.size()*(width+14)-14
	for i in range(items.size()):
		var item: Dictionary=items[i]
		var tile:=Control.new(); tile.name="AcquiredItem_"+str(page_index*per_page+i)
		tile.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card_area.add_child(tile); tile.position=Vector2((card_area.size.x-span)*.5+i*(width+14),(card_area.size.y-height)*.5)
		tile.size=Vector2(width,height); tile.set_meta("item",item); tiles.append(tile)
		if batch.kind=="card":
			var card:=ItemCard.new(); tile.add_child(card); card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card.create(assets,item,item.definition.name,func():inspect(item),width,height)
		else:
			var art:=RelicArt.new(); tile.add_child(art); art.configure(item.id,assets)
			art.position=Vector2(0,(height-width)*.3); art.size=Vector2(width,width)
			var label:=W.text(tile,item.name,19,W.GOLD); label.position=Vector2(-10,(height-width)*.3+width+14); label.size=Vector2(width+20,52)
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var button:=Button.new(); tile.add_child(button); button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			button.flat=true; button.accessibility_name=item.name; button.pressed.connect(func():inspect(item))
			for state in ["normal","hover","pressed","focus"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	if pages>1:
		W.button(pagination,"上一页",func():page_index-=1; _build_page(),page_index==0)
		W.text(pagination,"%d / %d" % [page_index+1,pages],15)
		W.button(pagination,"下一页",func():page_index+=1; _build_page(),page_index==pages-1)

func inspect(item: Dictionary) -> void:
	if collecting: return
	description.text=(str(item.name)+"\n"+str(item.description)) if batch.kind=="collectible" else (str(item.definition.name)+"\n"+str(item.definition.description))
	inspection.show()

func _background_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		accept_event(); collect()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled(); collect()

func collect() -> void:
	if collecting: return
	collecting=true; inspection.hide(); pagination.hide(); hint.hide(); title.hide()
	if prepare_collection.is_valid(): await prepare_collection.call(batch)
	var tween:=create_tween().set_parallel(true)
	# Fly every displayed card; additional pages join from the central stack.
	var count: int=batch.items.size()
	for i in range(count):
		var item: Dictionary=batch.items[i]
		var local_index: int=i-page_index*per_page
		var tile: Control=tiles[local_index] if local_index>=0 and local_index<tiles.size() else null
		if tile==null:
			tile=Control.new(); card_area.add_child(tile); tile.size=Vector2(90,135)
			tile.position=card_area.size*.5-tile.size*.5
			if batch.kind=="card":
				var card:=ItemCard.new(); tile.add_child(card); card.create(assets,item,item.definition.name,func():pass,90,135)
			else:
				var art:=RelicArt.new(); tile.add_child(art); art.configure(item.id,assets); art.size=Vector2(90,90)
		var delay:=minf(i*.045,.4)
		tile.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var target: Vector2=item.get("destination_position",destination-tile.size*.06)
		var target_scale: Vector2=item.destination_size/tile.size if item.has("destination_size") else Vector2(.12,.12)
		tween.tween_property(tile,"global_position",target,flight_duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(tile,"scale",target_scale,flight_duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if not item.has("destination_size"): tween.tween_property(tile,"modulate:a",0.0,.12).set_delay(delay+flight_duration-.12)
	await tween.finished
	arrived.emit()
	await create_tween().tween_property(self,"modulate:a",0.0,.12).finished
	completed.emit()
