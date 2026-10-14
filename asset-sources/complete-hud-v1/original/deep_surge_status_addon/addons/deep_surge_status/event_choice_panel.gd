@tool
extends PanelContainer
## Event choice panel. Native Godot buttons, keyboard focus and signals.
signal choice_selected(index: int, choice: String)

const INK := Color("151820")
const NAVY := Color("18243a")
const BLUE := Color("354f84")
const IVORY := Color("eee3cd")
const PALE := Color("fff8e9")

@export var event_title: String = "远方的微光":
    set(v): event_title = v; _refresh()
@export_multiline var event_description: String = "迷雾深处，一点微光忽明忽暗。\n那是废弃的灯塔，还是某种警告？":
    set(v): event_description = v; _refresh()
@export var choices: PackedStringArray = PackedStringArray(["驶向微光", "远处观察", "转身离开"]):
    set(v): choices = v; _refresh()
@export var show_event_number: bool = true:
    set(v): show_event_number = v; _refresh()
@export var event_number: int = 1:
    set(v): event_number = v; _refresh()

var _heading: Label
var _description: Label
var _list: VBoxContainer
var _counter: Label

func _ready() -> void:
    custom_minimum_size = Vector2(330, 280)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build()
    _refresh()

func set_event(title: String, description: String, options: PackedStringArray) -> void:
    event_title = title
    event_description = description
    choices = options
    _refresh()

func _style(bg: Color, border_color: Color, width: int = 2) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border_color
    s.set_border_width_all(width)
    s.set_corner_radius_all(4)
    s.content_margin_left = 13
    s.content_margin_right = 13
    s.content_margin_top = 8
    s.content_margin_bottom = 8
    return s

func _build() -> void:
    if _list != null:
        return
    add_theme_stylebox_override("panel", _style(INK, IVORY))
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 11)
    margin.add_theme_constant_override("margin_bottom", 11)
    add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 7)
    margin.add_child(column)
    var head := HBoxContainer.new()
    column.add_child(head)
    _heading = Label.new()
    _heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _heading.add_theme_color_override("font_color", IVORY)
    _heading.add_theme_font_size_override("font_size", 22)
    head.add_child(_heading)
    _counter = Label.new()
    _counter.add_theme_color_override("font_color", BLUE.lightened(0.5))
    _counter.add_theme_font_size_override("font_size", 13)
    head.add_child(_counter)
    var divider := HSeparator.new()
    column.add_child(divider)
    _description = Label.new()
    _description.add_theme_color_override("font_color", PALE)
    _description.add_theme_font_size_override("font_size", 17)
    _description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _description.custom_minimum_size.y = 66
    column.add_child(_description)
    _list = VBoxContainer.new()
    _list.add_theme_constant_override("separation", 6)
    column.add_child(_list)

func _refresh() -> void:
    if _heading == null or _list == null:
        return
    _heading.text = "✦  " + event_title
    _description.text = event_description
    _counter.text = ("EVENT %02d" % event_number) if show_event_number else ""
    for node in _list.get_children():
        _list.remove_child(node)
        node.queue_free()
    for i in choices.size():
        var button := Button.new()
        button.text = "✧  " + choices[i] + "    ›"
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.custom_minimum_size.y = 39
        button.add_theme_color_override("font_color", PALE)
        button.add_theme_color_override("font_hover_color", PALE)
        button.add_theme_color_override("font_pressed_color", INK)
        button.add_theme_font_size_override("font_size", 17)
        button.add_theme_stylebox_override("normal", _style(NAVY, IVORY, 1))
        button.add_theme_stylebox_override("hover", _style(BLUE, IVORY))
        button.add_theme_stylebox_override("pressed", _style(IVORY, BLUE))
        button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, BLUE))
        button.pressed.connect(_select.bind(i))
        _list.add_child(button)

func _select(index: int) -> void:
    choice_selected.emit(index, choices[index])
