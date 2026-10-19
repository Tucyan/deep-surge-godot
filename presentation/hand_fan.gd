extends Control
const ItemCard = preload("res://presentation/item_card.gd")
const W = preload("res://presentation/widgets.gd")
const CardStack = preload("res://presentation/card_stack.gd")
const Border = preload("res://presentation/hand_border.gd")
signal activated(card: Dictionary)
signal inspected(card: Dictionary)
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
var press_origin := Vector2.ZERO
var pointer_point := Vector2.ZERO
var drop_index := -1
var touch_index := -1
const DESKTOP_HOLD_SECONDS := 0.2
const MOBILE_HOLD_SECONDS := 0.05
var mobile := false
var hold_seconds := DESKTOP_HOLD_SECONDS
var cards: Array = []
var tiles: Array = []
var stack_bases: Array = []
var stack_targets: Array[Vector2] = []
var buttons: Array = []
var context: Dictionary
var visual_assets: RefCounted
var hovered := -1
var focus_x := 0.0
var dwell := 0.0
var border: Control
var tip: PanelContainer
var tip_text: Label
var card_width := 120.0
var card_height := 184.0
var card_face_width := 103.65
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
	mobile = bool(view.get("mobile", OS.has_feature("mobile")))
	set_meta("mobile_ui",mobile)
	hold_seconds = MOBILE_HOLD_SECONDS if mobile else DESKTOP_HOLD_SECONDS
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
				"description": "消耗 1 AP。基础造成 1 点伤害。可使用资源牌附魔，打出后消耗资源。"
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
				"description": "消耗 1 AP。基础获得 1 点护盾。可使用资源牌附魔，打出后消耗资源。"
			}
		}
		cards.append(attack_card)
		cards.append(block_card)
	custom_minimum_size = Vector2(0,238)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_STOP
	border = Border.new(); add_child(border); border.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	border.z_index = 0
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		var backing: Control=null
		if card.definition.kind=="resource" and not card.get("temporary",false) and int(card.get("stack_count",1))>1:
			backing=CardStack.new(); backing.name="StackRear_"+str(card.uid); add_child(backing)
			backing.setup(assets.texture("ui.card.front"),card.stack_count); backing.z_index=1
		stack_bases.append(backing)
		var tile := ItemCard.new(); add_child(tile)
		tile.z_index = 2
		var disabled: bool = context.phase == "discard" and (card.id in ["punch","pollution"] or tutorial_currency(card))
		if context.phase == "battle":
			var quote: Dictionary=combat_quote(card)
			disabled=not bool(quote.get("allowed",quote.get("enabled",card.definition.cost<=context.battle.ap)))
		tile.create(assets,card,action_name(card),func():
			if mobile: inspected.emit(card)
			else: activated.emit(card),120,184,disabled)
		ignore_mouse(tile)
		var button: Button = tile.get_child(0).get_child(tile.get_child(0).get_child_count()-1)
		if card.uid == "virtual_action_attack": button.name = "BattleAttack"
		elif card.uid == "virtual_action_block": button.name = "BattleBlock"
		elif card.definition.kind == "resource": button.name = "BattleFanResource_" + str(card.uid)
		button.tooltip_text = ""; buttons.append(button)
		button.focus_entered.connect(func(): focus_card(tiles.find(tile)))
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
	var positions := {}; var entries := {}; var scales := {}; var actions := {}; var stack_positions := {}
	for i in range(cards.size()):
		positions[cards[i].uid] = tiles[i].position; entries[cards[i].uid] = cards[i]; scales[cards[i].uid] = tiles[i].scale; actions[cards[i].uid] = action_name(cards[i])
		if stack_bases[i]!=null: stack_positions[cards[i].uid]=stack_bases[i].position
	var exiting := []
	for exit in departures:
		exiting.append({"card":exit.card,"origin":exit.origin,"scale":exit.scale,"elapsed":exit.elapsed,"action":exit.get("action","")})
	return {"stack_positions":stack_positions,"selected_uids":selected_uids.duplicate(),"stack_resources":hand_layout.stack_resources,"actions":actions,"entries":entries,"scales":scales,"departures":exiting,"refill_delay":refill_delay,"positions":positions,"hover_uid":cards[hovered].uid if hovered>=0 else "","dwell":dwell,"tip_visible":tip.visible}
func restore_visual(saved: Dictionary) -> void:
	if saved.is_empty(): return
	if saved.has("selected_uids"):
		selected_uids = saved.selected_uids.duplicate()
	arrange()
	hovered = -1
	for i in range(cards.size()):
		if saved.positions.has(cards[i].uid): tiles[i].position = saved.positions[cards[i].uid]
		if stack_bases[i]!=null and saved.get("stack_positions",{}).has(cards[i].uid): stack_bases[i].position=saved.stack_positions[cards[i].uid]
		if not mobile and cards[i].uid == saved.hover_uid: hovered = i
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
func tutorial_currency(card: Dictionary) -> bool:
	return context.get("mode","") == "tutorial" and context.get("phase","") == "discard" and (card.id == "coin" or card.id == "corpse" and int(context.get("voyage",0)) == 2)
func tutorial_trade_reason(card: Dictionary) -> String:
	return "请保留尸体用于接下来的出售教学，选择其他可弃手牌。" if card.id == "corpse" else "请保留贝币用于接下来的交易，选择其他可弃手牌。"
func action_name(card: Dictionary) -> String:
	if tutorial_currency(card): return "保留 · " + ("尸体" if card.id == "corpse" else "贝币")
	if card.get("is_fixed_action", false): return "选择 · "+card.definition.name
	if card.id == "coin": return "弃置全部 · 贝币" if context.phase == "discard" else "查看 · 贝币"
	if context.phase == "discard": return "弃置 · "+card.definition.name
	if context.phase == "battle" and card.definition.kind == "resource": return "选择 · "+card.definition.name
	if context.phase == "battle" or (context.can_base and card.definition.kind == "survival"): return "使用 · "+card.definition.name
	return "查看 · "+card.definition.name
func usage(card: Dictionary) -> String:
	if not mobile: return desktop_usage(card)
	if tutorial_currency(card): return tutorial_trade_reason(card)
	if context.phase == "discard":
		return "此牌不能主动弃置。" if card.id in ["punch","pollution"] else "按住0.05秒后向上滑出手牌区松开，弃置此牌；滑回取消。"
	if context.phase == "battle":
		if card.definition.kind == "resource": return "轻点资源牌，再拖出攻击或防御操作牌，打出附魔；打出后消耗资源。"
		return "按住0.05秒后向上滑出手牌区松开，确认出牌；滑回取消。AP不足或无效组合不会消耗。"
	if context.can_base and card.definition.kind == "survival": return "按住0.05秒后向上滑出手牌区松开使用；滑回取消。"
	if card.definition.kind == "equipment": return "按住0.05秒后拖到木筏完好空格安装，或同类1级设备上升级；无效投放不消耗。"
	if card.id in ["wood","corpse"] and context.can_base: return "按住0.05秒后拖到已安装的灯上松开投入燃料；无效投放不消耗。"
	return desktop_usage(card).replace("点击", "轻点")

func combat_quote(card: Dictionary) -> Dictionary:
	if card.get("is_fixed_action",false) and not context.get("battle_actions",[]).is_empty(): return context.battle_actions[0]
	return card.get("ap_quote",{})

func desktop_usage(card: Dictionary) -> String:
	if tutorial_currency(card): return tutorial_trade_reason(card)
	if context.phase == "battle" and card.definition.kind == "resource": return "选择资源牌，再双击攻击或防御操作牌打出附魔；选择和预览不消耗，打出后消耗资源。"
	if card.id in ["wood","corpse"] and context.can_base: return "长按后拖到已安装的灯上松开，投入一份燃料，不消耗 AP；也可用于合成。"
	if card.id == "coin":
		return "整理手牌：点击弃置全部 %d 贝币，腾出一张容量。" % card.stack_count if context.phase == "discard" else "在商店选择商品时自动支付贝币；点击查看，全部贝币共占一张容量。"
	var cost := "消耗 %d AP" % card.definition.cost if card.definition.cost > 0 else "不消耗 AP"
	if context.phase == "discard": return "整理手牌：点击弃置此牌。" if card.id not in ["punch","pollution"] else "此牌不能主动弃置。"
	if context.phase == "battle":
		var quote: Dictionary=combat_quote(card)
		if not quote.is_empty():
			var payable: bool=bool(quote.get("allowed",quote.get("enabled",false)))
			var price: String="%d战意" % int(quote.get("origin_ap",0)) if int(quote.get("origin_ap",0))>0 else "%d AP" % int(quote.get("ordinary_ap",quote.get("ap",0)))
			return ("点击使用。" if payable else "AP不足。")+"消耗"+price
		return ("AP 不足。" if card.definition.cost > context.battle.ap else "点击使用。")+cost
	match card.definition.kind:
		"survival": return ("点击使用。" if context.can_base else "抵达后的准备或收尾阶段可以使用。")+cost
		"equipment": return "长按拖到木筏空格安装，或拖到同类1级设备合并升级；双击自动安装。安装不消耗 AP，升级消耗 1 AP。"
		"action": return "点击查看；在「木筏详情」选择目标执行。"+cost
		"combat","negative": return "战斗中查看与使用。"+cost
		_: return "制作材料：在「合成/转化」选择配方或转化；点击查看用途。"
func focus_card(index: int) -> void:
	if mobile: index = -1
	if hovered == index: return
	if index >= 0: focus_x = tiles[index].position.x
	hovered = index; dwell = 0.0
	if is_instance_valid(tip): tip.hide()
	arrange()
func arrange() -> void:
	card_height = maxf(1.0,size.y*.97); card_width = card_height*(1024.0/1536.0)
	card_face_width = card_width*(ItemCard.FACE_HORIZONTAL_BOUNDS.y-ItemCard.FACE_HORIZONTAL_BOUNDS.x)
	var plate_top := 0.0
	if is_instance_valid(border): border.offset_top = plate_top
	if tiles.is_empty(): return
	var left: float = context.get("hand_reserved_left",0.0)
	var available := maxf(1,size.x-left-40-card_width)
	var stack_space := 14.0*card_height/184.0 if stack_bases.any(func(b):return b!=null) else 0.0
	var step := minf(card_width+8.0+stack_space,available/maxi(1,cards.size()-1))
	var start := left+(size.x-left-(step*(cards.size()-1)+card_width))*0.5
	base_x.clear()
	target_positions.clear(); stack_targets.clear()
	for i in range(cards.size()): base_x.append(start+i*step)
	for i in range(cards.size()):
		var x: float = base_x[i]
		var is_selected: bool = selected_uids.has(cards[i].uid) or (cards[i].has("stack_uids") and cards[i].stack_uids.any(func(u): return selected_uids.has(u)))
		if hovered >= 0 and hand_layout.hover_mode=="spread":
			# Pointer focus needs clearance independently of battle selection.
			# Ignore minor overlaps; the shadow is not part of the card width.
			focus_x = base_x[hovered]
			var distance := i-hovered
			if distance > 0:
				var rear_extent := 0.0
				if stack_bases[i]!=null: rear_extent=CardStack.OFFSET*stack_bases[i].layer_count*card_height/184.0
				var overlap := maxf(0.0,card_face_width+rear_extent-step*distance)
				if overlap/card_face_width >= 0.05 or is_equal_approx(overlap/card_face_width,0.05):
					x = minf(x+overlap,size.x-card_width)
		var raise_y := 0.0
		var mobile_battle: bool = mobile and context.get("phase","")=="battle"
		if i == hovered and not mobile_battle: raise_y += 14.0
		if is_selected: raise_y += 12.0 if mobile_battle else card_height / 3.0
		var tile: Control = tiles[i]
		# ItemCard keeps its authored aspect ratio; scale its fixed base size.
		tile.size = Vector2(120,184); tile.scale = Vector2.ONE*(card_height/184)
		var target := Vector2(x,(size.y-card_height)*.5-raise_y)
		target_positions.append(target)
		if not laid_out: tile.position = target
		# Only the front can raise its drawing layer; rear cards keep sibling order.
		tile.z_index = 20 if i==hovered and hand_layout.hover_mode=="raise" else 1
		var rest := Vector2(x,(size.y-card_height)*.5)
		stack_targets.append(rest)
		if stack_bases[i]!=null:
			stack_bases[i].size=Vector2(120,184); stack_bases[i].scale=tile.scale
			if not laid_out: stack_bases[i].position=rest
		tile.modulate = Color(1.15, 1.1, 0.95) if is_selected else Color.WHITE
	laid_out = true
	if is_instance_valid(tip) and tip.visible: place_tip()
func show_description() -> void:
	if mobile or hovered < 0: return
	var card: Dictionary = cards[hovered]
	var reorder_hint := "" if mobile and context.get("phase","")=="discard" else "\n长按拖动调整顺序"
	tip_text.text = card.definition.name+(" ×%d" % card.stack_count if card.stack_count>1 else "")+"\n"+card.definition.description+"\n\n"+usage(card)+reorder_hint
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
		if not dragging and press_time>=hold_seconds:
			if mobile or not bool(cards[pressed_index].get("is_fixed_action", false)):
				dragging=true; drop_index=pressed_index; tip.hide()
		if dragging:
			var held_card: Dictionary = cards[pressed_index]
			var outside_hand := pointer_point.y < 0
			var can_drag_to_raft: bool = raft_draggable(held_card) and context.can_base
			var can_drag_to_use: bool = mobile and mobile_drag_playable(held_card)
			if outside_hand and (can_drag_to_raft or can_drag_to_use):
				tiles[pressed_index].position=pointer_point-press_point
				tiles[pressed_index].modulate.a=.62
				if can_drag_to_raft:
					equipment_dragged.emit(held_card,global_position+pointer_point)
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
	var single_card_discard: bool = dragging and mobile and context.get("phase","")=="discard"
	for i in range(mini(tiles.size(),target_positions.size())):
		if dragging and i==pressed_index: continue
		if single_card_discard: continue
		var tile: Control = tiles[i]
		if tile.position.distance_squared_to(target_positions[i]) < .04: tile.position = target_positions[i]
		else: tile.position = tile.position.lerp(target_positions[i],blend)
	for i in range(stack_bases.size()):
		var backing: Control=stack_bases[i]
		if backing==null: continue
		# Discard moves one instance, leaving the rest of the stack on the table.
		if single_card_discard: continue
		if dragging and i==pressed_index:
			backing.position=tiles[i].position+Vector2(0,14)
			backing.z_index=299
		else:
			backing.position=backing.position.lerp(stack_targets[i],blend)
			backing.z_index=1
		backing.modulate.a=tiles[i].modulate.a
	if tip.visible: place_tip()
	if not mobile and hovered >= 0 and pressed_index<0:
		dwell += delta
		if dwell >= 0.35 and not tip.visible: show_description()
func _gui_input(event: InputEvent) -> void:
	if pressed_index>=0: return
	if not mobile and event is InputEventMouseMotion and not cards.is_empty():
		var index := hit_card(event.position)
		focus_card(index)
	elif event is InputEventScreenTouch and event.pressed and touch_index<0:
		var index:=hit_card(event.position)
		if index>=0:
			touch_index=event.index; _begin_press(index,event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and touch_index<0:
		var index := hit_card(event.position)
		if index>=0:
			if not mobile and event.double_click and cards[index].definition.kind=="equipment" and context.can_base:
				accept_event(); equipment_double_clicked.emit(cards[index]); return
			if not mobile and event.double_click and context.get("phase","") == "battle":
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
	press_origin=point
	press_point=point-tiles[index].position; tip.hide()

func hit_card(point: Vector2) -> int:
	var result := -1
	var top_z := -1
	# Match painter order: each group's rear, then its front; later siblings win ties.
	for i in range(tiles.size()):
		var backing: Control=stack_bases[i]
		if backing!=null and backing.z_index>=top_z and backing.hit_rect().has_point(point):
			result=i; top_z=backing.z_index
		if tiles[i].z_index>=top_z and Rect2(tiles[i].position,tiles[i].size*tiles[i].scale).has_point(point):
			result=i; top_z=tiles[i].z_index
	return result

func _input(event: InputEvent) -> void:
	if pressed_index<0 or not is_visible_in_tree(): return
	if event is InputEventScreenTouch and event.index==touch_index and event.canceled:
		cancel_gesture(); get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		cancel_gesture(); get_viewport().set_input_as_handled(); return
	if (event is InputEventMouseMotion and touch_index<0) or (event is InputEventScreenDrag and event.index==touch_index):
		var next_point: Vector2 = get_global_transform().affine_inverse() * (event.position if event is InputEventScreenDrag else event.global_position)
		# Card easing can move its geometry under a stationary finger/mouse.
		# Gesture movement is measured from the pointer-down position, not the card.
		if not dragging and next_point.distance_to(press_origin)>10:
			cancel_gesture(); return
		pointer_point=next_point
		if dragging:
			get_viewport().set_input_as_handled()
			if mobile and context.get("phase","")=="discard": return
			if bool(cards[pressed_index].get("is_fixed_action",false)): return
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
				stack_targets[i].x=base_x[slot]
			get_viewport().set_input_as_handled()
	elif (event is InputEventMouseButton and touch_index<0 and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and event.index==touch_index and not event.pressed):
		var index := pressed_index; var was_dragging := dragging; var destination := drop_index
		var release_point: Vector2 = get_global_transform().affine_inverse() * (event.position if event is InputEventScreenTouch else event.global_position)
		var held_card: Dictionary=cards[index]
		var valid_outside: bool = release_point.y < -12 and release_point.x >= 0 and release_point.x < size.x and get_viewport_rect().has_point(get_global_transform() * release_point)
		var external_drop: bool=was_dragging and context.can_base and raft_draggable(held_card) and (valid_outside if mobile else release_point.y<0)
		var mobile_use: bool=was_dragging and mobile and mobile_drag_playable(held_card) and valid_outside
		cancel_gesture(); get_viewport().set_input_as_handled()
		if external_drop:
			equipment_released.emit(held_card,global_position+release_point)
		elif mobile_use:
			if context.phase == "battle" and held_card.definition.kind != "resource":
				battle_action_double_clicked.emit(held_card)
			else: activated.emit(held_card)
		elif was_dragging:
			if mobile and context.get("phase","")=="discard": return
			if mobile and (not Rect2(Vector2.ZERO,size).has_point(release_point) or held_card.get("is_fixed_action",false)): return
			var max_dest := cards.size() - 1
			if context.get("phase","") == "battle": max_dest = maxi(0, cards.size() - 3)
			if destination!=index and destination>=0 and destination <= max_dest:
				move_card_group(index,destination)
		elif (hit_card(release_point)==index or (release_point.distance_to(press_origin)<=10 and get_viewport_rect().has_point(get_global_transform()*release_point))) and not buttons[index].disabled:
			if mobile: inspected.emit(held_card)
			else: activated.emit(held_card)

## Reuse the controls and their current animation positions when sorting. Rebuilding
## the HUD here used to block the release frame and recreate every card subtree.
func move_card_group(from: int, to: int) -> void:
	var sortable: Array=cards.filter(func(c): return not c.get("is_fixed_action",false))
	hand_layout.move_group(sortable,from,to)
	for entries in [cards,tiles,buttons,stack_bases]:
		var moved=entries.pop_at(from)
		entries.insert(to,moved)
	# Equal z layers draw in sibling order; keep the hit test and stack painter
	# order consistent with the new slots, leaving the tooltip above the cards.
	var sibling := border.get_index()+1
	for i in range(cards.size()):
		if stack_bases[i]!=null:
			move_child(stack_bases[i],sibling)
			sibling+=1
		move_child(tiles[i],sibling)
		sibling+=1
	hovered=-1 if mobile else to
	arrange()
	reordered.emit()

func raft_draggable(card: Dictionary) -> bool:
	return card.definition.kind=="equipment" or card.id in ["wood","corpse"]

func mobile_drag_playable(card: Dictionary) -> bool:
	if pressed_index < 0 or pressed_index >= buttons.size() or buttons[pressed_index].disabled:
		return false
	if context.get("phase","") == "discard":
		return not (card.id in ["punch","pollution"] or tutorial_currency(card))
	if context.get("phase","") == "battle":
		return true
	if context.get("can_base",false):
		return card.definition.kind == "survival" or card.id in ["wood","corpse"]
	return false

func cancel_gesture() -> void:
	pressed_index=-1; dragging=false; press_time=0.0; drop_index=-1; touch_index=-1; arrange()
	for tile in tiles: tile.modulate.a=1.0
	drag_canceled.emit()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT] and pressed_index>=0: cancel_gesture()
