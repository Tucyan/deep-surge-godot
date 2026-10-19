extends RefCounted
const Overlay=preload("res://presentation/acquisition_overlay.gd")
var _hidden: Array=[]
var _capacity_text:=""

func present(app, batches: Array) -> void:
	if batches.is_empty(): return
	var old_mode: int=app.layout.process_mode
	app.layout.process_mode=Node.PROCESS_MODE_DISABLED
	app.world_view.set_camera_input_enabled(false)
	await app.get_tree().process_frame
	for fan in app.layout.find_children("hand_fan","",true,false):
		fan.cancel_gesture(); fan.arrange()
		for exit in fan.departures: exit.tile.queue_free()
		fan.departures.clear(); fan.refill_delay=0.0
		for i in range(fan.tiles.size()):
			fan.tiles[i].position=fan.target_positions[i]
			if i<fan.stack_bases.size() and is_instance_valid(fan.stack_bases[i]): fan.stack_bases[i].position=fan.stack_targets[i]
	for batch in batches:
		var target: Control=app.layout.find_child("CollectiblesEntry" if batch.kind=="collectible" else "VoyageHandTray",true,false)
		var point: Vector2=app.size*Vector2(.5,.87)
		if is_instance_valid(target): point=target.get_global_rect().get_center()
		var overlay:=Overlay.new(); app.add_child(overlay); app.acquisition_overlay=overlay
		if batch.kind=="card":
			overlay.prepare_collection=func(data):await _prepare_hand(app,data)
			overlay.arrived.connect(func():_reveal_hand(app))
		overlay.configure(batch,app.assets,point)
		await overlay.completed
		app.remove_child(overlay); overlay.queue_free(); app.acquisition_overlay=null
	if is_instance_valid(app.layout): app.layout.process_mode=old_mode
	app.world_view.set_camera_input_enabled(app.session.screen=="game" and app.world_view.visible and app.local_panel=="" and app.session.panel in ["","story","battle"] and not app.narrative_playing)

func _hide_tile(node: Control) -> void:
	_hidden.append({"node":weakref(node),"color":node.modulate}); node.modulate.a=0

func _prepare_hand(app, batch: Dictionary) -> void:
	var counter=app.layout.find_child("HandCapacityBadge",true,false)
	_capacity_text=counter.get_child(0).text if is_instance_valid(counter) else ""
	var incoming: Array=[]
	for item in batch.items:
		incoming.append(item.uid)
		if item.id=="coin": app._pending_receipt.coins=maxi(0,int(app._pending_receipt.coins)-int(item.get("stack_count",1)))
		else: app._pending_receipt.uids.erase(item.uid)
	# Build the confirmed layout once; the arriving groups stay hidden in it.
	await app.render()
	app.layout.process_mode=Node.PROCESS_MODE_DISABLED
	app.world_view.set_camera_input_enabled(false)
	for fan in app.layout.find_children("hand_fan","",true,false):
		for i in range(fan.cards.size()):
			if fan.cards[i].get("stack_uids",[fan.cards[i].uid]).any(func(uid):return uid in incoming):
				_hide_tile(fan.tiles[i])
				if i<fan.stack_bases.size() and is_instance_valid(fan.stack_bases[i]): _hide_tile(fan.stack_bases[i])
	counter=app.layout.find_child("HandCapacityBadge",true,false)
	if is_instance_valid(counter): counter.get_child(0).text=_capacity_text
	await app.get_tree().process_frame
	for fan in app.layout.find_children("hand_fan","",true,false):
		fan.cancel_gesture(); fan.arrange()
		for i in range(fan.cards.size()):
			# Use the final rest position, never a restored/interpolating old position.
			fan.tiles[i].position=fan.target_positions[i]
			if i<fan.stack_bases.size() and is_instance_valid(fan.stack_bases[i]): fan.stack_bases[i].position=fan.stack_targets[i]
			var uids: Array=fan.cards[i].get("stack_uids",[fan.cards[i].uid])
			for item in batch.items:
				if item.uid in uids:
					var destination: Rect2=fan.tiles[i].get_global_rect()
					item.destination_position=destination.position
					item.destination_size=destination.size
	for entry in _hidden:
		var node=entry.node.get_ref()
		if is_instance_valid(node): node.modulate.a=0

func _reveal_hand(app) -> void:
	for entry in _hidden:
		var node=entry.node.get_ref()
		if is_instance_valid(node): node.modulate=entry.color
	_hidden.clear()
	var counter=app.layout.find_child("HandCapacityBadge",true,false)
	if is_instance_valid(counter): counter.get_child(0).text="%d/%d" % [app.hud_view().capacity,app.hud_view().player.limit]
