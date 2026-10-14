@tool
extends "res://presentation/hud_frame.gd"
## Event choice panel. Native Godot buttons, keyboard focus and signals.
signal choice_selected(index: int, choice: String)

const ART = preload("res://addons/deep_surge_status/textures/event_art.png")
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

var choice_details := PackedStringArray()
var choice_disabled := PackedByteArray()
var _banner: TextureRect
var _heading: Label
var _description: Label
var _list: VBoxContainer
var _counter: Label

func _ready() -> void:
    custom_minimum_size.x = maxf(custom_minimum_size.x,420)
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
    var frame := _style(Color("0c1720"),Color("887e64"),1)
    frame.content_margin_left = 0; frame.content_margin_right = 0
    frame.content_margin_top = 0; frame.content_margin_bottom = 0
    add_theme_stylebox_override("panel",frame)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 7)
    margin.add_child(column)
    var banner := TextureRect.new()
    _banner = banner
    var atlas := AtlasTexture.new(); atlas.atlas = ART; atlas.region = Rect2(0,0,678,282)
    banner.texture = atlas
    banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    banner.custom_minimum_size.y = 145
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(banner)
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
    _description.custom_minimum_size.y = 0
    column.add_child(_description)
    _list = VBoxContainer.new()
    _list.add_theme_constant_override("separation", 6)
    column.add_child(_list)

func _refresh() -> void:
    if _heading == null or _list == null:
        return
    _banner.visible = choices.size() <= 3
    _banner.custom_minimum_size.y = 145 if choices.size() <= 1 else 65
    _heading.text = "✦  " + event_title
    _description.text = event_description
    _description.visible = not event_description.is_empty()
    _counter.text = ("EVENT %02d" % event_number) if show_event_number else ""
    for node in _list.get_children():
        _list.remove_child(node)
        node.queue_free()
    for i in choices.size():
        var button := Button.new()
        button.text = choices[i]
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.disabled = i < choice_disabled.size() and choice_disabled[i] != 0
        button.tooltip_text = choice_details[i] if i < choice_details.size() else ""
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.custom_minimum_size.y = 38 if choices.size() > 3 else 46
        button.add_theme_color_override("font_color", PALE)
        button.add_theme_color_override("font_hover_color", PALE)
        button.add_theme_color_override("font_pressed_color", PALE)
        button.add_theme_font_size_override("font_size", 16 if choices.size() > 3 else 18)
        var choice_style := StyleBoxTexture.new()
        choice_style.texture = ART
        choice_style.region_rect = Rect2(48,489,560,65)
        choice_style.set_texture_margin(SIDE_LEFT,0); choice_style.set_texture_margin(SIDE_RIGHT,0)
        choice_style.set_texture_margin(SIDE_TOP,0); choice_style.set_texture_margin(SIDE_BOTTOM,0)
        choice_style.content_margin_left = 68; choice_style.content_margin_right = 30
        choice_style.content_margin_top = 6 if choices.size() > 3 else 9
        choice_style.content_margin_bottom = choice_style.content_margin_top
        button.add_theme_stylebox_override("normal", choice_style)
        var disabled_style := choice_style.duplicate(); disabled_style.modulate_color = Color(0.6,0.6,0.6,1)
        button.add_theme_stylebox_override("disabled",disabled_style)
        var hover_style := choice_style.duplicate(); hover_style.modulate_color = Color(1.2,1.2,1.2,1)
        button.add_theme_stylebox_override("hover",hover_style)
        var pressed_style := choice_style.duplicate(); pressed_style.modulate_color = Color(0.8,0.9,1.1,1)
        button.add_theme_stylebox_override("pressed",pressed_style)
        button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, BLUE))
        button.pressed.connect(_select.bind(i))
        _list.add_child(button)
        if choices.size() <= 3 and i < choice_details.size() and not choice_details[i].is_empty():
            var detail := Label.new()
            detail.text = choice_details[i]
            detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            detail.add_theme_font_size_override("font_size", 14)
            detail.add_theme_color_override("font_color", Color("b9bdba"))
            _list.add_child(detail)

func _select(index: int) -> void:
    if index < 0 or index >= choices.size(): return
    if index < choice_disabled.size() and choice_disabled[index] != 0: return
    choice_selected.emit(index, choices[index])
