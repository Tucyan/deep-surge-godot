extends Control
const W=preload("res://presentation/widgets.gd")
const CELL_POPUP_OVERLAP := .2
var app: Control
var policy=preload("res://presentation/raft_actions.gd").new()
var surface: Node3D
var popup: PanelContainer
var selected: Dictionary={}
var _pressed: Dictionary={}
var _press_point:=Vector2.ZERO
var _touch_index: int=-1
var _popup_anchor_y: float=0.0
var _popup_vertical_placed:=false
func create(owner_app: Control) -> void:
	app=owner_app; name="RaftInteraction"; mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); z_index=150
	policy.refresh(app.session)
	surface=preload("res://presentation/raft_surface.gd").new(); surface.create(app.world_view,policy.expansions())
	app.world_view.mouse_filter=Control.MOUSE_FILTER_STOP
	app.world_view.gui_input.connect(_surface_input)
	for fan in get_tree().get_nodes_in_group("hand_fans"):
		if app.layout.is_ancestor_of(fan):
			fan.equipment_dragged.connect(_dragged); fan.equipment_released.connect(_released); fan.drag_canceled.connect(_clear_drop)
func _exit_tree() -> void:
	if is_instance_valid(surface): surface.hide(); surface.queue_free()
func _surface_input(event: InputEvent) -> void:
	if not is_inside_tree(): return
	if event is InputEventScreenTouch:
		if event.canceled: _touch_index=-1; _pressed={}; return
		if event.pressed and _touch_index<0: _touch_index=event.index; _press(event.position)
		elif not event.pressed and event.index==_touch_index: _touch_index=-1; _release(event.position)
	elif _touch_index<0 and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: _press(event.position)
		else: _release(event.position)
func _press(local_point: Vector2) -> void:
	_press_point=app.world_view.get_global_transform()*local_point
	_pressed=surface.pick(_press_point,policy.targets())
func _release(local_point: Vector2) -> void:
	var point: Vector2=app.world_view.get_global_transform()*local_point
	var target: Dictionary=surface.pick(point,policy.targets())
	if point.distance_to(_press_point)<18 and target.get("id","")==_pressed.get("id",""):
		if target.get("kind","")=="cell" and target.id==selected.get("id",""): target={}
		select_target(target)
	_pressed={}
func select_target(target: Dictionary) -> void:
	selected=target; surface.select(target)
	_popup_anchor_y=0.0; _popup_vertical_placed=false
	if is_instance_valid(popup): remove_child(popup); popup.queue_free()
	popup=null
	if target.is_empty(): return
	var column:=W.panel(self); popup=column.get_parent(); popup.name="RaftCellPopup"
	popup.z_index=1
	var style: StyleBoxFlat=popup.get_theme_stylebox("panel").duplicate()
	style.content_margin_left=10; style.content_margin_right=10; style.content_margin_top=8; style.content_margin_bottom=8
	popup.add_theme_stylebox_override("panel",style); column.add_theme_constant_override("separation",5)
	var header:=HBoxContainer.new(); column.add_child(header)
	W.text(header,"新建筏格" if target.kind=="expand" else "筏格 %d,%d" % [target.x+1,target.y+1],16,W.GOLD)
	if target.kind=="expand":
		W.text(column,"消耗：木头 %d · AP %d" % [target.cost.wood,target.ap],15)
		if not target.allowed: W.text(column,target.reason,14,Color("efaaa0"))
		var confirm:=W.button(column,"确认新建",func(): _execute(target)); confirm.name="ConfirmRaftExpansion"; confirm.disabled=not target.allowed
	else:
		var actions: Array=policy.cell_actions(target.id)
		for operation in ["install","upgrade","craft_upgrade","repair"]:
			var options: Array=actions.filter(func(a):return a.get("operation",a.command)==operation or (operation=="repair" and a.command in ["repair_cell","action_card"]))
			if options.is_empty(): continue
			if options.size()==1:
				var item: Dictionary=options[0]
				var button:=W.button(column,item.label,func(): _execute(item),not item.allowed,item.reason)
				button.name="RaftAction_"+operation; button.custom_minimum_size.y=38
				var hint:=W.text(column,_action_hint(item),14,W.MUTED if item.allowed else Color("efaaa0"))
				hint.name="RaftHint_"+operation; hint.visible=not hint.text.is_empty()
			else:
				var choices:=OptionButton.new(); choices.custom_minimum_size.y=36; column.add_child(choices)
				for item in options: choices.add_item(item.label); choices.set_item_disabled(choices.item_count-1,not item.allowed)
				var first: int=options.find(options.filter(func(a):return a.allowed)[0]) if options.any(func(a):return a.allowed) else 0
				choices.select(first)
				var button:=W.button(column,{"install":"安装","upgrade":"升级 · AP1","repair":"修复 · AP1"}[operation],func(): _execute(options[choices.selected]),not options[first].allowed)
				button.name="RaftAction_"+operation; button.custom_minimum_size.y=38
				var hint:=W.text(column,_action_hint(options[first]),14,Color("efaaa0")); hint.name="RaftHint_"+operation; hint.visible=not hint.text.is_empty()
				choices.item_selected.connect(func(index):
					button.disabled=not options[index].allowed; button.tooltip_text=options[index].reason
					hint.text=_action_hint(options[index]); hint.visible=not hint.text.is_empty())
		if actions.is_empty(): W.text(column,"手牌中没有可安装设备，先在合成中制作。" if target.equipment.is_empty() else "暂无可用操作",14,W.MUTED)
	popup.custom_minimum_size.x=250 if target.get("equipment",{}).size()>0 else 210
	# Freeze the vertical anchor at selection time; do not clamp it against HUD or viewport edges.
	_popup_anchor_y=surface.screen_point(target).y-global_position.y+12
	_position_popup.call_deferred()
func _action_hint(item: Dictionary) -> String:
	var lines: PackedStringArray=[]
	if not item.get("detail","").is_empty(): lines.append(item.detail)
	if not item.allowed and not item.reason.is_empty(): lines.append(item.reason)
	return "\n".join(lines)
func _execute(item: Dictionary) -> void:
	app.handle_command.call_deferred(item.command,item.args)
func _process(_delta: float) -> void:
	if is_instance_valid(popup): _position_popup()
func _position_popup() -> void:
	if not is_instance_valid(popup) or selected.is_empty(): return
	# Autowrapped labels initially measure before the popup width settles.
	# Shrink back to the final minimum instead of keeping that transient height.
	popup.reset_size()
	# Permit the requested small overlap with the selected cell's right fifth.
	# Use projected geometry so it stays proportional at every UI/camera scale.
	var bounds: Rect2=surface.screen_rect(selected)
	bounds.position-=global_position
	var allowed_left: float=bounds.end.x-bounds.size.x*CELL_POPUP_OVERLAP
	var desired_x: float=allowed_left
	popup.position.x=clampf(desired_x,8,maxf(8,size.x-popup.size.x-8))
	# Choose the vertical position once. Y-axis HUD/viewport obstruction checks are intentionally disabled.
	if not _popup_vertical_placed:
		popup.position.y=_popup_anchor_y
		if popup.position.x<allowed_left: popup.position.x=maxf(8,bounds.position.x-popup.size.x-12)
		_popup_vertical_placed=true
func _dragged(card: Dictionary,point: Vector2) -> void:
	var item: Dictionary=_drop_action(card,point)
	surface.show_drop(item.get("target",{}),card,item.get("allowed",false),item.get("command","")=="upgrade")
func _drop_action(card: Dictionary,point: Vector2) -> Dictionary:
	var fuel: bool=card.id in ["wood","corpse"]
	if not fuel and card.definition.kind!="equipment": return {}
	# Pick every real cell first so occupied devices occlude cells behind them.
	var target: Dictionary=surface.pick(point,policy.targets().filter(func(c):return c.kind=="cell"))
	if target.is_empty(): return {}
	if fuel and target.equipment.get("id","")!="lamp": return {}
	if not fuel and target.status!="intact": return {}
	if not fuel and not target.equipment.is_empty() and target.equipment.id!=card.id: return {}
	var args: Dictionary={"cell":target.id,"uid":card.uid}
	if fuel: args.material=card.id
	var command: String="fuel" if fuel else ("install" if target.equipment.is_empty() else "upgrade")
	var item: Dictionary=policy.quote(command,args).duplicate()
	item.target=target
	return item
func _clear_drop() -> void:
	if is_instance_valid(surface): surface.show_drop({}, {},false)
func _released(card: Dictionary,point: Vector2) -> void:
	var item: Dictionary=_drop_action(card,point)
	_clear_drop()
	if item.get("allowed",false): _execute(item)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: select_target({})
