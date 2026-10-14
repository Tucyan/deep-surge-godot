@tool
extends Control
## Decorative AP (Action Points) HUD drawn directly in Godot.

signal ap_changed(current: int, maximum: int)

const DESIGN_SIZE := Vector2(470.0, 104.0)
const INK := Color("151820")
const NAVY := Color("18243a")
const BLUE := Color("354f84")
const IVORY := Color("eee3cd")
const PALE := Color("fff8e9")
const SOFT := Color("aaa18f")

@export_group("Values")
@export_range(0, 20, 1) var current_ap: int = 3:
    set(v):
        current_ap = clampi(v, 0, max_ap)
        queue_redraw()
@export_range(1, 20, 1) var max_ap: int = 3:
    set(v):
        max_ap = maxi(v, 1)
        current_ap = mini(current_ap, max_ap)
        queue_redraw()

@export_group("Appearance")
@export var label_text: String = "行动点":
    set(v): label_text = v; queue_redraw()
@export var english_label: String = "ACTION POINTS":
    set(v): english_label = v; queue_redraw()
@export var show_english_label: bool = false:
    set(v): show_english_label = v; queue_redraw()
@export var show_numbers: bool = true:
    set(v): show_numbers = v; queue_redraw()
@export var panel_opacity: float = 0.96:
    set(v): panel_opacity = clampf(v, 0.0, 1.0); queue_redraw()
@export var active_fill: Color = Color("526fae"):
    set(v): active_fill = v; queue_redraw()
@export var inactive_fill: Color = Color("202734"):
    set(v): inactive_fill = v; queue_redraw()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if size == Vector2.ZERO:
        custom_minimum_size = DESIGN_SIZE
    queue_redraw()

func _get_minimum_size() -> Vector2:
    return Vector2(330, 72)

func set_ap(current: int, maximum: int = -1) -> void:
    if maximum > 0:
        max_ap = maximum
    current_ap = current
    ap_changed.emit(current_ap, max_ap)

func _draw() -> void:
    if size.x <= 0.0 or size.y <= 0.0:
        return
    draw_set_transform(Vector2.ZERO, 0.0, size / DESIGN_SIZE)
    var alpha := clampf(panel_opacity, 0.0, 1.0)
    var base := Color(INK.r, INK.g, INK.b, alpha)

    draw_rect(Rect2(65, 16, 377, 70), base)
    draw_rect(Rect2(68, 19, 371, 64), NAVY.darkened(0.10) * Color(1, 1, 1, alpha))
    draw_line(Vector2(81, 24), Vector2(421, 24), IVORY, 1.8, true)
    draw_line(Vector2(81, 78), Vector2(421, 78), IVORY, 1.8, true)
    draw_line(Vector2(232, 31), Vector2(390, 31), SOFT, 0.9)
    _star(Vector2(408, 37), 8.0, IVORY)
    _star(Vector2(441, 50), 10.0, IVORY)

    var medallion := Vector2(40, 51)
    draw_circle(medallion, 31, INK)
    draw_arc(medallion, 31, 0.0, TAU, 56, IVORY, 2.1, true)
    draw_arc(medallion, 25, 0.0, TAU, 56, BLUE, 6.5, true)
    draw_arc(medallion, 20, 0.0, TAU, 56, IVORY, 1.0, true)
    _star(medallion + Vector2(0, -31), 6.0, IVORY)
    _star(medallion + Vector2(0, 31), 6.0, IVORY)
    _star(medallion + Vector2(-31, 0), 4.5, IVORY)
    _star(medallion + Vector2(31, 0), 4.5, IVORY)
    _ap_icon(medallion)

    var font := ThemeDB.fallback_font
    if font:
        var label := english_label if show_english_label else label_text
        draw_string(font, Vector2(87, 43), label, HORIZONTAL_ALIGNMENT_LEFT, 170, 20, IVORY)
        if show_numbers:
            var txt := "%d / %d" % [current_ap, max_ap]
            draw_string(font, Vector2(338, 67), txt, HORIZONTAL_ALIGNMENT_CENTER, 78, 18, PALE)

    _draw_ap_pips(Vector2(175, 57))
    draw_set_transform(Vector2.ZERO)

func _draw_ap_pips(start: Vector2) -> void:
    var spacing := minf(44.0, 145.0 / float(maxi(max_ap - 1, 1)))
    var outer_r := 16.0
    var inner_r := 11.0
    var total_width := spacing * float(max_ap - 1)
    var origin_x := start.x - total_width * 0.5
    for i in range(max_ap):
        var c := Vector2(origin_x + spacing * float(i), start.y)
        var is_active := i < current_ap
        draw_circle(c, outer_r + 2.0, IVORY)
        draw_circle(c, outer_r, INK)
        draw_circle(c, inner_r + 2.0, active_fill if is_active else inactive_fill)
        draw_circle(c, inner_r * 0.72, IVORY if is_active else SOFT)
        if is_active:
            _star(c, 3.5, INK)
        else:
            draw_circle(c, 2.4, INK)

func _ap_icon(center: Vector2) -> void:
    var diamond := PackedVector2Array([
        center + Vector2(0, -15),
        center + Vector2(12, 0),
        center + Vector2(0, 15),
        center + Vector2(-12, 0)
    ])
    draw_colored_polygon(diamond, IVORY)
    draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), INK, 2.2)
    draw_line(center + Vector2(0, -6), center + Vector2(0, 6), INK, 2.2)

func _star(center: Vector2, radius: float, color: Color) -> void:
    var p := PackedVector2Array([
        center + Vector2(0, -radius), center + Vector2(radius * 0.22, -radius * 0.22),
        center + Vector2(radius, 0), center + Vector2(radius * 0.22, radius * 0.22),
        center + Vector2(0, radius), center + Vector2(-radius * 0.22, radius * 0.22),
        center + Vector2(-radius, 0), center + Vector2(-radius * 0.22, -radius * 0.22)
    ])
    draw_colored_polygon(p, color)
