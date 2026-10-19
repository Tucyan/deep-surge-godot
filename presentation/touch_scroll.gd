extends Node
## Gesture ownership starts through GUI hit testing, so overlays and clipping win.
const DEADZONE := 10.0
var finger := -1
var movement := Vector2.ZERO
var origin := Vector2.ZERO
var scrolling := false

static func configure(control: Control) -> void:
	if control is ScrollContainer:
		if control.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			control.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		if control.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			control.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var ancestor: Node = control
	while ancestor != null and not ancestor is ScrollContainer:
		if ancestor is ScrollBar: return
		ancestor = ancestor.get_parent()
	if ancestor == null: return
	var handler = ancestor.get_node_or_null("TouchScroll")
	if handler == null:
		handler = load("res://presentation/touch_scroll.gd").new()
		handler.name = "TouchScroll"
		ancestor.add_child(handler)
	if not control.gui_input.is_connected(handler.begin):
		control.gui_input.connect(handler.begin)

func begin(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and finger == -1:
		finger = event.index
		movement = Vector2.ZERO
		origin = Vector2(get_parent().scroll_horizontal,get_parent().scroll_vertical)

func _input(event: InputEvent) -> void:
	if finger == -1: return
	var scroll := get_parent() as ScrollContainer
	if not scroll.is_visible_in_tree():
		finish()
		return
	if event is InputEventScreenTouch and event.index == finger and not event.pressed:
		finish()
	elif event is InputEventScreenDrag and event.index == finger:
		movement -= scroll.get_global_transform_with_canvas().affine_inverse().basis_xform(event.relative)
		var horizontal := scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		var vertical := scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		if not scrolling and ((horizontal and absf(movement.x) > DEADZONE) or (vertical and absf(movement.y) > DEADZONE)):
			scrolling = true
			# Godot buttons release their pending click on this notification.
			scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
			scroll.scroll_started.emit()
		if scrolling:
			if horizontal: scroll.scroll_horizontal = roundi(origin.x + movement.x)
			if vertical: scroll.scroll_vertical = roundi(origin.y + movement.y)
			get_viewport().set_input_as_handled()

func finish() -> void:
	if scrolling:
		get_parent().propagate_notification(Control.NOTIFICATION_SCROLL_END)
		get_parent().scroll_ended.emit()
	finger = -1
	scrolling = false

func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		finish()
