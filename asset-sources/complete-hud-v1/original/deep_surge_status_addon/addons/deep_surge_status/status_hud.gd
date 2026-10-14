@tool
extends Control
## Four status bars drawn directly in Godot. No runtime textures or image dependencies.

signal status_changed(stat: StringName, value: float, maximum: float)

const DESIGN_SIZE := Vector2(650.0, 310.0)
const INK := Color("151820")
const NAVY := Color("18243a")
const BLUE := Color("354f84")
const IVORY := Color("eee3cd")
const PALE := Color("fff8e9")
const SOFT := Color("aaa18f")

@export_group("Values")
@export_range(0.0, 9999.0, 1.0) var health: float = 30.0:
    set(v): health = maxf(v, 0.0); queue_redraw()
@export_range(1.0, 9999.0, 1.0) var max_health: float = 30.0:
    set(v): max_health = maxf(v, 1.0); queue_redraw()
@export_range(0.0, 9999.0, 1.0) var satiety: float = 80.0:
    set(v): satiety = maxf(v, 0.0); queue_redraw()
@export_range(1.0, 9999.0, 1.0) var max_satiety: float = 100.0:
    set(v): max_satiety = maxf(v, 1.0); queue_redraw()
@export_range(0.0, 9999.0, 1.0) var water: float = 80.0:
    set(v): water = maxf(v, 0.0); queue_redraw()
@export_range(1.0, 9999.0, 1.0) var max_water: float = 100.0:
    set(v): max_water = maxf(v, 1.0); queue_redraw()
@export_range(0.0, 9999.0, 1.0) var sanity: float = 80.0:
    set(v): sanity = maxf(v, 0.0); queue_redraw()
@export_range(1.0, 9999.0, 1.0) var max_sanity: float = 100.0:
    set(v): max_sanity = maxf(v, 1.0); queue_redraw()

@export_group("Appearance")
@export var show_numbers := true:
    set(v): show_numbers = v; queue_redraw()
@export var show_english_labels := false:
    set(v): show_english_labels = v; queue_redraw()
@export var panel_opacity: float = 0.96:
    set(v): panel_opacity = clampf(v, 0.0, 1.0); queue_redraw()
@export var bar_color: Color = Color("526fae"):
    set(v): bar_color = v; queue_redraw()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if size == Vector2.ZERO:
        custom_minimum_size = DESIGN_SIZE
    queue_redraw()

func _get_minimum_size() -> Vector2:
    return Vector2(325, 155)

## Change a value in gameplay: hud.set_stat(&"health", 24, 30).
func set_stat(stat: StringName, amount: float, maximum: float = -1.0) -> void:
    var value_name := String(stat)
    if value_name not in ["health", "satiety", "water", "sanity"]:
        push_warning("Unknown HUD stat: " + value_name)
        return
    if maximum > 0.0:
        set("max_" + value_name if value_name != "sanity" else "max_sanity", maximum)
    set(value_name, amount)
    status_changed.emit(stat, amount, float(get("max_" + value_name)))

func _draw() -> void:
    if size.x <= 0.0 or size.y <= 0.0:
        return
    draw_set_transform(Vector2.ZERO, 0.0, size / DESIGN_SIZE)
    var names := ["生命", "饱食", "水分", "理智"]
    var english := ["HEALTH", "SATIETY", "WATER", "SAN"]
    var values := [health, satiety, water, sanity]
    var maxima := [max_health, max_satiety, max_water, max_sanity]
    for i in 4:
        _draw_status(i, english[i] if show_english_labels else names[i], values[i], maxima[i])
    draw_set_transform(Vector2.ZERO)

func _draw_status(index: int, label: String, value: float, maximum: float) -> void:
    var y := 5.0 + 77.0 * index
    var alpha := clampf(panel_opacity, 0.0, 1.0)
    var base := Color(INK.r, INK.g, INK.b, alpha)
    # Large main slab, slim trim, restrained geometric endcaps.
    draw_rect(Rect2(80, y + 11, 540, 54), base)
    draw_rect(Rect2(82, y + 13, 537, 50), NAVY.darkened(0.10) * Color(1, 1, 1, alpha))
    draw_line(Vector2(95, y + 16), Vector2(595, y + 16), IVORY, 1.8, true)
    draw_line(Vector2(93, y + 59), Vector2(601, y + 59), IVORY, 1.8, true)
    draw_line(Vector2(345, y + 22), Vector2(535, y + 22), SOFT, 0.9)
    _star(Vector2(554, y + 24), 8, IVORY)
    _star(Vector2(621, y + 37), 11, IVORY)
    # Icon medallion (larger than the status bar, shared between all four).
    var c := Vector2(48, y + 37)
    draw_circle(c, 34, INK)
    draw_arc(c, 34, 0.0, TAU, 56, IVORY, 2.2, true)
    draw_arc(c, 28, 0.0, TAU, 56, BLUE, 7.5, true)
    draw_arc(c, 22, 0.0, TAU, 56, IVORY, 1.0, true)
    _star(c + Vector2(0, -34), 7, IVORY)
    _star(c + Vector2(0, 34), 7, IVORY)
    _star(c + Vector2(-34, 0), 5, IVORY)
    _star(c + Vector2(34, 0), 5, IVORY)
    _icon(index, c)
    # Bar track, explicit geometric cap, actual progression.
    var track := Rect2(202, y + 39, 266, 13)
    draw_rect(track.grow(2), IVORY)
    draw_rect(track, INK)
    var fill_width := track.size.x * clampf(value / maxf(maximum, 1.0), 0.0, 1.0)
    if fill_width > 0.0:
        draw_rect(Rect2(track.position, Vector2(fill_width, track.size.y)), bar_color)
        draw_line(track.position + Vector2(3, 4), track.position + Vector2(maxf(3, fill_width - 3), 4), bar_color.lightened(0.22), 1.2)
    var font := ThemeDB.fallback_font
    if font:
        draw_string(font, Vector2(103, y + 35), label, HORIZONTAL_ALIGNMENT_LEFT, 220, 20, IVORY)
        if show_numbers:
            var numbers := "%d / %d" % [int(value), int(maximum)]
            draw_string(font, Vector2(484, y + 51), numbers, HORIZONTAL_ALIGNMENT_CENTER, 113, 16, PALE)

func _star(center: Vector2, radius: float, color: Color) -> void:
    var p := PackedVector2Array([
        center + Vector2(0, -radius), center + Vector2(radius * 0.22, -radius * 0.22),
        center + Vector2(radius, 0), center + Vector2(radius * 0.22, radius * 0.22),
        center + Vector2(0, radius), center + Vector2(-radius * 0.22, radius * 0.22),
        center + Vector2(-radius, 0), center + Vector2(-radius * 0.22, -radius * 0.22)
    ])
    draw_colored_polygon(p, color)

func _icon(which: int, c: Vector2) -> void:
    match which:
        0:
            # Heart, optionally split by negative-space line.
            var points := PackedVector2Array()
            points.append(c + Vector2(0, 17))
            points.append(c + Vector2(-17, 1))
            points.append(c + Vector2(-17, -9))
            points.append(c + Vector2(-9, -15))
            points.append(c)
            points.append(c + Vector2(9, -15))
            points.append(c + Vector2(17, -9))
            points.append(c + Vector2(17, 1))
            draw_colored_polygon(points, IVORY)
            _star(c + Vector2(0, 0), 4.7, INK)
        1:
            draw_arc(c + Vector2(0, -4), 10, PI, TAU, 20, IVORY, 3)
            draw_line(c + Vector2(-13, 1), c + Vector2(13, 1), IVORY, 3)
            draw_line(c + Vector2(-11, 7), c + Vector2(11, 7), IVORY, 2)
            for x in [-9.0, 0.0, 9.0]:
                draw_line(c + Vector2(x, -12), c + Vector2(x + 2, -19), IVORY, 1.7)
        2:
            var drop := PackedVector2Array([
                c + Vector2(0, -20), c + Vector2(-12, 0), c + Vector2(-11, 11),
                c + Vector2(-6, 16), c + Vector2(6, 16), c + Vector2(11, 11), c + Vector2(12, 0)
            ])
            draw_colored_polygon(drop, IVORY)
            _star(c + Vector2(1, 6), 5, INK)
        3:
            draw_arc(c, 14, 0, TAU, 30, IVORY, 3)
            draw_arc(c, 5, 0, TAU, 20, BLUE, 3)
            for j in 9:
                var a := float(j) / 9.0 * TAU
                draw_line(c + Vector2.RIGHT.rotated(a) * 13, c + Vector2.RIGHT.rotated(a) * 19, IVORY, 3)
