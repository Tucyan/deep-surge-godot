@tool
extends Control
## Reference-art-backed four-stat panel. Exact ornate texture, live value overlays.
signal status_changed(stat: StringName, value: float, maximum: float)

const DESIGN_SIZE := Vector2(682.0,679.0)
const ART = preload("res://addons/deep_surge_status/textures/status_art.png")
const BLUE := Color("285cac")
const BLUE_LIGHT := Color("497bc3")
const CREAM := Color("f2e6cd")
const INK := Color("171b22")

@export_group("Stats")
@export_range(0,9999,1) var health: float = 30.0:
    set(v): health = maxf(v,0.0); queue_redraw()
@export_range(1,9999,1) var max_health: float = 30.0:
    set(v): max_health = maxf(v,1.0); queue_redraw()
@export_range(0,9999,1) var satiety: float = 80.0:
    set(v): satiety = maxf(v,0.0); queue_redraw()
@export_range(1,9999,1) var max_satiety: float = 100.0:
    set(v): max_satiety = maxf(v,1.0); queue_redraw()
@export_range(0,9999,1) var water: float = 80.0:
    set(v): water = maxf(v,0.0); queue_redraw()
@export_range(1,9999,1) var max_water: float = 100.0:
    set(v): max_water = maxf(v,1.0); queue_redraw()
@export_range(0,9999,1) var sanity: float = 80.0:
    set(v): sanity = maxf(v,0.0); queue_redraw()
@export_range(1,9999,1) var max_sanity: float = 100.0:
    set(v): max_sanity = maxf(v,1.0); queue_redraw()

@export_group("Art & Label")
@export var show_numbers := true:
    set(v): show_numbers = v; queue_redraw()
## Default leaves the original English print visible, like the reference screenshot.
@export var chinese_labels := false:
    set(v): chinese_labels = v; queue_redraw()
@export var fill_color: Color = BLUE:
    set(v): fill_color = v; queue_redraw()
@export var text_color: Color = INK:
    set(v): text_color = v; queue_redraw()
@export var font_size: int = 24:
    set(v): font_size = clampi(v,12,48); queue_redraw()
@export var art_override: Texture2D:
    set(v): art_override = v; queue_redraw()

func _ready() -> void:
    mouse_filter = MOUSE_FILTER_IGNORE
    if size == Vector2.ZERO:
        custom_minimum_size = DESIGN_SIZE
    queue_redraw()

func _get_minimum_size() -> Vector2:
    return Vector2(260,260)

func set_stat(stat: StringName, value: float, maximum: float = -1.0) -> void:
    var key := String(stat)
    if key not in ["health","satiety","water","sanity"]:
        push_warning("Unknown Deep Surge stat: " + key)
        return
    if maximum > 0.0:
        set("max_" + key,maximum)
    set(key,clampf(value,0.0,float(get("max_"+key))))
    status_changed.emit(stat,float(get(key)),float(get("max_"+key)))

func _draw() -> void:
    if size.x <= 0.0 or size.y <= 0.0:
        return
    draw_set_transform(Vector2.ZERO,0.0,size / DESIGN_SIZE)
    var texture: Texture2D = art_override if art_override != null else ART
    draw_texture_rect(texture,Rect2(Vector2.ZERO,DESIGN_SIZE),false)
    var values := [health,satiety,water,sanity]
    var maxima := [max_health,max_satiety,max_water,max_sanity]
    var labels := ["生命","饱食","水分","SAN"]
    for i in range(4):
        var dy := float([0,159,318,478][i])
        _draw_fill(Vector2(199,107+dy),258.0,23.0,clampf(values[i]/maxf(maxima[i],1.0),0.0,1.0))
        var font := ThemeDB.fallback_font
        if font != null:
            if chinese_labels:
                draw_rect(Rect2(187,52+dy,169,35),Color("111a26"))
                draw_string(font,Vector2(189,82+dy),labels[i],HORIZONTAL_ALIGNMENT_LEFT,158,25,CREAM)
            if show_numbers:
                var txt := "%d / %d" % [int(values[i]),int(maxima[i])]
                draw_string(font,Vector2(509,130+dy),txt,HORIZONTAL_ALIGNMENT_CENTER,90,font_size,text_color)
    draw_set_transform(Vector2.ZERO)

func _draw_fill(origin: Vector2, width: float, height: float, fraction: float) -> void:
    if fraction <= 0.0:
        return
    var fill_width := maxf(height, width*fraction)
    fill_width = minf(fill_width,width)
    var r := height/2.0
    var left := origin + Vector2(r,r)
    draw_circle(left,r,fill_color)
    if fill_width > height:
        draw_rect(Rect2(origin+Vector2(r,0),Vector2(fill_width-height,height)),fill_color)
        draw_circle(origin+Vector2(fill_width-r,r),r,fill_color)
    # Delicate decorative moving light line, does not alter the original trim.
    if fill_width > 45.0:
        var end_x := origin.x+fill_width-11.0
        var pts := PackedVector2Array()
        for j in range(13):
            var x := origin.x+12.0+(end_x-origin.x-12.0)*float(j)/12.0
            var y := origin.y+height*0.41+sin(float(j)*0.7)*2.0
            pts.append(Vector2(x,y))
        draw_polyline(pts,BLUE_LIGHT,2.0,true)
