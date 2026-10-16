extends Control
const ItemCard = preload("res://presentation/item_card.gd")
const W = preload("res://presentation/widgets.gd")
const Border = preload("res://presentation/hand_border.gd")
signal activated(card: Dictionary)
signal battle_action_double_clicked(card: Dictionary)
signal equipment_double_clicked(card: Dictionary)
signal equipment_dragged(card: Dictionary, point: Vector2)
signal equipment_released(card: Dictionary, point: Vector2)
signal drag_canceled
signal reordered
var hand_layout: RefCounted
var dragging := false
var pressed_index := -1
var press_time := 0.0
var press_point := Vector2.ZERO
var pointer_point := Vector2.ZERO
var drop_index := -1
var touch_index := -1
const HOLD_SECONDS := 0.2
var cards: Array = []
var tiles: Array = []
var buttons: Array = []
var context: Dictionary
var visual_assets: RefCounted
var hovered := -1
var focus_x := 0.0
var dwell := 0.0
var back_copy: BackBufferCopy
var glass: ColorRect
var border: Control
var tip: PanelContainer
var tip_text: Label
var card_width := 120.0
var card_height := 184.0
var base_x: Array = []
var target_positions: Array[Vector2] = []
var laid_out := false
var departures: Array = []
var refill_delay := 0.0
const EXIT_DURATION := 0.24
var selected_uids: Array = []
@export_range(0.05,0.5) var move_duration := 0.18
func set_selected_uids(uids: Array) -> void:
	selected_uids = uids.duplicate()
	arrange()

func create(assets: RefCounted, entries: Array, view: Dictionary) -> void:
	add_to_group("hand_fans")
	context = view; visual_assets = assets
	hand_layout = view.get("hand_layout",preload("res://presentation/hand_layout.gd").new())
	cards = hand_layout.build(entries)
	if view.get("phase","") == "battle":
		var attack_card: Dictionary = {
			"uid": "virtual_action_attack",
			"id": "action_attack",
			"action_id": "attack",
			"is_fixed_action": true,
			"temporary": false,
			"quantity": 1,
			"stack_count": 1,
			"stack_uids": ["virtual_action_attack"],
			"definition": {
				"id": "action_attack",
				"name": "攻击",
				"kind": "combat",
				"cost": 1,
				"damage": 1,
				"description": "消耗 1 AP。基础造成 1 点伤害。可与材料牌组合出招。"
			}
		}
		var block_card: Dictionary = {
			"uid": "virtual_action_block",
			"id": "action_block",
			"action_id": "block",
			"is_fixed_action": true,
			"temporary": false,
			"quantity": 1,
			"stack_count": 1,
			"stack_uids": ["virtual_action_block"],
			"definition": {
				"id": "action_block",
				"name": "防御",
				"kind": "combat",
				"cost": 1,
				"damage": 0,
				"description": "消耗 1 AP。基础获得 1 点护盾。可与材料牌组合出招。"
			}
		}
		cards.append(attack_card)
		cards.append(block_card)
	custom_minimum_size = Vector2(0,238)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_STOP
	back_copy = BackBufferCopy.new(); back_copy.copy_mode = BackBufferCopy.COPY_MODE_RECT; add_child(back_copy)
	glass = ColorRect.new(); glass.mouse_filter = MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new(); mat.shader = preload("res://assets/shaders/hand_glass.gdshader"); glass.material = mat
	add_child(glass); glass.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	border = Border.new(); add_child(border); border.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	border.z_index = 2
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		var tile := ItemCard.new(); add_child(tile)
		tile.z_index = 2
		var disabled: bool = context.phase == "discard" and card.id in ["punch","pollution"]
		if context.phase == "battle": disabled = card.definition.cost > context.battle.ap
		tile.create(assets,card,action_name(card),func(): activated.emit(card),120,184,disabled)
		ignore_mouse(tile)
		var button: Button = tile.get_child(0).get_child(tile.get_child(0).get_child_count()-1)
		if card.uid == "virtual_action_attack": button.name = "BattleAttack"
		elif card.uid == "virtual_action_block": button.name = "BattleBlock"
		elif card.definition.kind == "resource": button.name = "BattleFanResource_" + str(card.uid)
		button.tooltip_text = ""; buttons.append(button)
		button.focus_entered.connect(func(): focus_card(i))
		tiles.append(tile)
	tip = PanelContainer.new(); tip.mouse_filter = MOUSE_FILTER_IGNORE; tip.z_index = 100
	var style := StyleBoxFlat.new(); style.bg_color = Color(0.025,0.065,0.09,0.97); style.border_color = W.GOLD; style.set_border_width_all(1)
	style.content_margin_left = 18; style.content_margin_right = 18; style.content_margin_top = 14; style.content_margin_bottom = 14
	tip.add_theme_stylebox_override("panel",style); add_child(tip)
	tip_text = Label.new(); tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tip_text.add_theme_font_size_override("font_size",17); tip_text.mouse_filter = MOUSE_FILTER_IGNORE; tip.add_child(tip_text); tip.hide()
	resized.connect(arrange)
	mouse_exited.connect(func(): focus_card(-1))
	arrange.call_deferred()
func capture_visual() -> Dictionary:
	var positions := {}; var entries := {}; var scales := {}; var actions := {}
	for i in range(cards.size()):
		positions[cards[i].uid] = tiles[i].position; entries[cards[i].uid] = cards[i]; scales[cards[i].uid] = tiles[i].scale; actions[cards[i].uid] = action_name(cards[i])
	var exiting := []
	for exit in departures:
		exiting.append({"card":exit.card,"origin":exit.origin,"scale":exit.scale,"elapsed":exit.elapsed,"action":exit.get("action","")})
	return {"selected_uids":selected_uids.duplicate(),"stack_resources":hand_layout.stack_resources,"actions":actions,"entries":entries,"scales":scales,"departures":exiting,"refill_delay":refill_delay,"positions":positions,"hover_uid":cards[hovered].uid if hovered>=0 else "","dwell":dwell,"tip_visible":tip.visible}
func restore_visual(saved: Dictionary) -> void:
	if saved.is_empty(): return
	if saved.has("selected_uids"):
		selected_uids = saved.selected_uids.duplicate()
	arrange()
	hovered = -1
	for i in range(cards.size()):
		if saved.positions.has(cards[i].uid): tiles[i].position = saved.positions[cards[i].uid]
		if cards[i].uid == saved.hover_uid: hovered = i
	laid_out = true; dwell = saved.dwell if hovered>=0 else 0.0
	arrange()
	if hovered>=0 and saved.tip_visible: show_description()
	refill_delay = saved.get("refill_delay",0.0)
	for exit in saved.get("departures",[]): add_departure(exit)
	for uid in saved.get("entries",{}):
		if cards.any(func(c): return c.uid == uid): continue
		if context.hand.any(func(c):return c.uid==uid): continue
		add_departure({"card":saved.entries[uid],"origin":saved.positions[uid],"scale":saved.scales[uid],"elapsed":0.0,"action":saved.get("actions",{}).get(uid,"")})
		refill_delay = maxf(refill_delay,.12)
func add_departure(exit: Dictionary) -> void:
	var tile := ItemCard.new(); tile.name = "DepartingCard"; tile.set_meta("departing_uid",exit.card.uid); add_child(tile)
	tile.create(visual_assets,exit.card,exit.get("action",""),func(): pass,120,184)
	ignore_mouse(tile); tile.size = Vector2(120,184); tile.pivot_offset = Vector2(60,92); tile.z_index = 30
	var record := exit.duplicate(); record["tile"] = tile; departures.append(record); draw_departure(record)
func draw_departure(exit: Dictionary) -> void:
	var t := clampf(exit.elapsed/EXIT_DURATION,0.0,1.0)
	var eased := t*t*(3.0-2.0*t)
	exit.tile.position = exit.origin+Vector2(0,-24)*eased
	exit.tile.scale = exit.scale*(1.0-.22*eased)
	exit.tile.modulate.a = 1.0-eased
func ignore_mouse(node: Control) -> void:
	node.mouse_filter = MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: ignore_mouse(child)
func action_name(card: Dictionary) -> String:
	if card.get("is_fixed_action", false): return "选择 · "+card.definition.name
	if card.id == "coin": return "弃置全部 · 贝币" if context.phase == "discard" else "查看 · 贝币"
	if context.phase == "discard": return "弃置 · "+card.definition.name
	if context.phase == "battle" and card.definition.kind == "resource": return "选择 · "+card.definition.name
	if context.phase == "battle" or (context.can_base and card.definition.kind == "survival"): return "使用 · "+card.definition.name
	return "查看 · "+card.definition.name
func usage(card: Dictionary) -> String:
	if context.phase == "battle" and card.definition.kind == "resource": return "选择该资源后，再选攻击或格挡；确认前不会消耗。"
	if card.id in ["wood","corpse"] and context.can_base: return "长按后拖到已安装的灯上松开，投入一份燃料，不消耗 AP；也可用于合成。"
	if card.id == "coin":
		return "整理手牌：点击弃置全部 %d 贝币，腾出一张容量。" % card.stack_count if context.phase == "discard" else "在商店选择商品时自动支付贝币；点击查看，全部贝币共占一张容量。"
	var cost := "消耗 %d AP" % card.definition.cost if card.definition.cost > 0 else "不消耗 AP"
	if context.phase == "discard": return "整理手牌：点击弃置此牌。" if card.id not in ["punch","pollution"] else "此牌不能主动弃置。"
	if context.phase == "battle": return ("AP 不足。" if card.definition.cost > context.battle.ap else "点击使用。")+cost
	match card.definition.kind:
		"survival": return ("点击使用。" if context.can_base else "抵达后的准备或收尾阶段可以使用。")+cost
		"equipment": return "长按拖到木筏空格安装，或拖到同类1级设备合并升级；双击自动安装。安装不消耗 AP，升级消耗 1 AP。"
		"action": return "点击查看；在「木筏详情」选择目标执行。"+cost
		"combat","negative": return "战斗中查看与使用。"+cost
		_: return "制作材料：在「合成/转化」选择配方或转化；点击查看用途。"
func focus_card(index: int) -> void:
	if hovered == index: return
	if index >= 0: focus_x = tiles[index].position.x
	hovered = index; dwell = 0.0
	if is_instance_valid(tip): tip.hide()
	arrange()
func arrange() -> void:
	if is_instance_valid(back_copy): back_copy.rect = Rect2(Vector2.ZERO,size).grow(24)
	card_height = clampf(size.y-40,160,190); card_width = card_height*0.651
	var plate_top := maxf(0.0,size.y-card_height-28.0)
	if is_instance_valid(glass): glass.offset_top = plate_top
	if is_instance_valid(border): border.offset_top = plate_top
	if tiles.is_empty(): return
	var left: float = context.get("hand_reserved_left",0.0)
	var available := maxf(1,size.x-left-40-card_width)
	var step := minf(card_width+8.0,available/maxi(1,cards.size()-1))
	var crowded := step < card_width
	var start := left+(size.x-left-(step*(cards.size()-1)+card_width))*0.5
	base_x.clear()
	target_positions.clear()
	for i in range(cards.size()): base_x.append(start+i*step)
	for i in range(cards.size()):
		var x: float = base_x[i]
		if hovered >= 0:
			# Only the closest two cards on each side make a small amount of room.
			# The raised card renders above overlap; the rest of the hand stays anchored.
			focus_x = base_x[hovered]
			var distance := absi(i-hovered)
			if crowded and distance > 0 and distance <= 2:
				# Move only by the overlap with this neighbour, with no added gap.
				var visible_width := card_width*.5 if i<hovered else card_width
				var overlap := maxf(0.0,visible_width-step*distance)
				var movement := minf(overlap,step*.45)
				x += movement*(-1.0 if i<hovered else 1.0)
				x = clampf(x,left+20,size.x-20-card_width)
		var is_selected: bool = selected_uids.has(cards[i].uid) or (cards[i].has("stack_uids") and cards[i].stack_uids.any(func(u): return selected_uids.has(u)))
		var raise_y := 0.0
		if i == hovered: raise_y += 14.0
		if is_selected: raise_y += card_height / 3.0
		var tile: Control = tiles[i]
		# ItemCard keeps its authored aspect ratio; scale its fixed base size.
		tile.size = Vector2(120,184); tile.scale = Vector2.ONE*(card_height/184)
		var target := Vector2(x,size.y-card_height-14-raise_y)
		target_positions.append(target)
		if not laid_out: tile.position = target
		tile.z_index = 25 if is_selected else (20 if i == hovered else 1)
		tile.modulate = Color(1.15, 1.1, 0.95) if is_selected else Color.WHITE
	laid_out = true
	if is_instance_valid(tip) and tip.visible: place_tip()
func show_description() -> void:
	if hovered < 0: return
	var card: Dictionary = cards[hovered]
	tip_text.text = card.definition.name+(" ×%d" % card.stack_count if card.stack_count>1 else "")+"\n"+card.definition.description+"\n\n"+usage(card)+"\n长按拖动调整顺序"
	tip_text.custom_minimum_size.x = minf(360,size.x-24)-36
	tip.size = Vector2(minf(360,size.x-24),0); tip.show(); place_tip(); place_tip.call_deferred()
func place_tip() -> void:
	var width := minf(360,size.x-24)
	tip.size = Vector2(width,0)
	tip.position = Vector2(clampf(focus_x+card_width*0.5-width*0.5,8,size.x-width-8),-tip.size.y-12)
	if tip.global_position.y < 8: tip.global_position.y = 8
func _process(delta: float) -> void:
	if pressed_index>=0:
		press_time+=delta
		if not dragging and press_time>=HOLD_SECONDS:
			if not bool(cards[pressed_index].get("is_fixed_action", false)):
				dragging=true; drop_index=pressed_index; tip.hide()
		if dragging:
			if raft_draggable(cards[pressed_index]) and context.can_base and pointer_point.y<0:
				tiles[pressed_index].position=pointer_point-press_point
				tiles[pressed_index].modulate.a=.62
				equipment_dragged.emit(cards[pressed_index],global_position+pointer_point)
			else:
				tiles[pressed_index].modulate.a=1.0
				tiles[pressed_index].position=Vector2(clampf(pointer_point.x-press_point.x,context.get("hand_reserved_left",0.0),maxf(0,size.x-card_width)),size.y-card_height-34)
				drag_canceled.emit()
			tiles[pressed_index].z_index=300

	for i in range(departures.size()-1,-1,-1):
		var exit: Dictionary = departures[i]; exit.elapsed += delta; draw_departure(exit)
		if exit.elapsed >= EXIT_DURATION: exit.tile.queue_free(); departures.remove_at(i)
	var move_delta := maxf(0.0,delta-refill_delay)
	refill_delay = maxf(0.0,refill_delay-delta)
	var blend := 1.0-exp(-move_delta*4.0/maxf(.05,move_duration))
	for i in range(mini(tiles.size(),target_positions.size())):
		if dragging and i==pressed_index: continue
		var tile: Control = tiles[i]
		if tile.position.distance_squared_to(target_positions[i]) < .04: tile.position = target_positions[i]
		else: tile.position = tile.position.lerp(target_positions[i],blend)
	if tip.visible: place_tip()
	if hovered >= 0 and pressed_index<0:
		dwell += delta
		if dwell >= 0.35 and not tip.visible: show_description()
func _gui_input(event: InputEvent) -> void:
	if pressed_index>=0: return
	if event is InputEventMouseMotion and not cards.is_empty():
		# Keep the raised card while the pointer is inside it; hit-test the
		# visible neighbours only after leaving. This avoids layout feedback.
		if hovered >= 0 and Rect2(tiles[hovered].position,tiles[hovered].size*tiles[hovered].scale).has_point(event.position): return
		var index := -1
		for i in range(tiles.size()-1,-1,-1):
			if Rect2(tiles[i].position,tiles[i].size*tiles[i].scale).has_point(event.position):
				index = i; break
		focus_card(index)
	elif event is InputEventScreenTouch and event.pressed and touch_index<0:
		var index:=hit_card(event.position)
		if index>=0:
			touch_index=event.index; _begin_press(index,event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and touch_index<0:
		var index := hit_card(event.position)
		if index>=0:
			if event.double_click and cards[index].definition.kind=="equipment" and context.can_base:
				accept_event(); equipment_double_clicked.emit(cards[index]); return
			if event.double_click and context.get("phase","") == "battle":
				var c: Dictionary = cards[index]
				if c.get("is_fixed_action", false) or c.get("uid","") in ["virtual_action_attack", "virtual_action_block"] or c.get("action_id","") in ["attack", "block"]:
					accept_event()
					battle_action_double_clicked.emit(c)
					return
				var def: Dictionary = c.get("definition", {})
				if def.get("kind", "") in ["combat", "survival", "negative"] and c.get("id", "") not in ["coin", "corpse"]:
					accept_event()
					battle_action_double_clicked.emit(c)
					return
			_begin_press(index,event.position)
		accept_event()

func _begin_press(index: int,point: Vector2) -> void:
	focus_card(index); pressed_index=index; press_time=0.0; pointer_point=point
	press_point=point-tiles[index].position; tip.hide()

func hit_card(point: Vector2) -> int:
	if hovered>=0 and Rect2(tiles[hovered].position,tiles[hovered].size*tiles[hovered].scale).has_point(point): return hovered
	for i in range(tiles.size()-1,-1,-1):
		if Rect2(tiles[i].position,tiles[i].size*tiles[i].scale).has_point(point): return i
	return -1

func _input(event: InputEvent) -> void:
	if pressed_index<0 or not is_visible_in_tree(): return
	if event is InputEventScreenTouch and event.index==touch_index and event.canceled:
		cancel_gesture(); get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		cancel_gesture(); get_viewport().set_input_as_handled(); return
	if (event is InputEventMouseMotion and touch_index<0) or (event is InputEventScreenDrag and event.index==touch_index):
		var next_point: Vector2 = (event.position if event is InputEventScreenDrag else event.global_position)-global_position
		if not dragging and next_point.distance_to(tiles[pressed_index].position+press_point)>10:
			cancel_gesture(); return
		pointer_point=next_point
		if dragging:
			var step: float = base_x[1]-base_x[0] if base_x.size()>1 else card_width
			var max_drop := cards.size() - 1
			if context.get("phase","") == "battle": max_drop = maxi(0, cards.size() - 3)
			drop_index=clampi(roundi((pointer_point.x-press_point.x-base_x[0])/maxf(1,step)),0,max_drop)
			# Open a destination slot while the held card follows the pointer.
			arrange()
			for i in range(cards.size()):
				if i==pressed_index: continue
				var slot := i
				if pressed_index<drop_index and i>pressed_index and i<=drop_index: slot=i-1
				elif pressed_index>drop_index and i>=drop_index and i<pressed_index: slot=i+1
				target_positions[i].x=base_x[slot]
			get_viewport().set_input_as_handled()
	elif (event is InputEventMouseButton and touch_index<0 and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and event.index==touch_index and not event.pressed):
		var index := pressed_index; var was_dragging := dragging; var destination := drop_index
		var release_point: Vector2 = (event.position if event is InputEventScreenTouch else event.global_position)-global_position
		var held_card: Dictionary=cards[index]
		var external_drop: bool=was_dragging and context.can_base and raft_draggable(held_card) and release_point.y<0
		cancel_gesture(); get_viewport().set_input_as_handled()
		if external_drop:
			equipment_released.emit(held_card,global_position+release_point)
		elif was_dragging:
			var max_dest := cards.size() - 1
			if context.get("phase","") == "battle": max_dest = maxi(0, cards.size() - 3)
			if destination!=index and destination>=0 and destination <= max_dest:
				hand_layout.move_group(cards,index,destination); reordered.emit()
		elif hit_card(release_point)==index and not buttons[index].disabled:
			activated.emit(cards[index])

func raft_draggable(card: Dictionary) -> bool:
	return card.definition.kind=="equipment" or card.id in ["wood","corpse"]

func cancel_gesture() -> void:
	pressed_index=-1; dragging=false; press_time=0.0; drop_index=-1; touch_index=-1; arrange()
	for tile in tiles: tile.modulate.a=1.0
	drag_canceled.emit()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT] and pressed_index>=0: cancel_gesture()
