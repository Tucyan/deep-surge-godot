@tool
extends Control
## Reference-art-backed four-stat panel. Exact ornate texture, live value overlays.
signal status_changed(stat: StringName, value: float, maximum: float)

const DESIGN_SIZE := Vector2(2837.12,190.0)
const ART = preload("res://addons/deep_surge_status/textures/status_art.png")
const BLUE := Color("285cac")
const BLUE_LIGHT := Color("497bc3")
const CREAM := Color("f2e6cd")
const INK := Color("171b22")

@export var two_columns := false:
    set(v): two_columns = v; minimum_size_changed.emit(); queue_redraw()
@export var minimum_row_width := 800.0:
    set(v): minimum_row_width=maxf(0.0,v); minimum_size_changed.emit()

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
## Chinese labels use a deliberate dark inset, covering the baked English text.
@export var chinese_labels := true:
    set(v): chinese_labels = v; queue_redraw()
@export var fill_color: Color = BLUE:
    set(v): fill_color = v; queue_redraw()
@export var use_stat_colors := true:
    set(v): use_stat_colors = v; queue_redraw()
@export var text_color: Color = INK:
    set(v): text_color = v; queue_redraw()
@export var font_size: int = 36:
    set(v): font_size = clampi(v,12,48); queue_redraw()
@export var art_override: Texture2D:
    set(v): art_override = v; queue_redraw()

func _ready() -> void:
    mouse_filter = MOUSE_FILTER_IGNORE
    if size == Vector2.ZERO:
        custom_minimum_size = DESIGN_SIZE
    queue_redraw()

func _get_minimum_size() -> Vector2:
    return Vector2(400,108) if two_columns else Vector2(minimum_row_width,54)

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
    var texture: Texture2D = art_override if art_override != null else ART
    var design := Vector2(1418.56,380) if two_columns else DESIGN_SIZE
    var scale_factor := minf(size.x/design.x,size.y/design.y)
    var origin := (size-design*scale_factor)*0.5 if two_columns else Vector2.ZERO
    var values := [health,satiety,water,sanity]
    var maxima := [max_health,max_satiety,max_water,max_sanity]
    var labels := ["生命","饱食","水分","理智"]
    var colors := [Color("ab6b61"),Color("a68a48"),Color("548da7"),Color("8276a6")]
    var source_rows := [0.0,160.0,321.0,485.0]
    for i in range(4):
        var cell_x := float(i%2) if two_columns else float(i)
        var cell_y := floorf(float(i)/2.0)*190.0 if two_columns else 0.0
        draw_set_transform(origin+Vector2(cell_x*709.28*scale_factor,cell_y*scale_factor),0.0,Vector2.ONE*scale_factor)
        var source_y: float = source_rows[i]
        # Separate each row's bar and circular medallion; avoid carrying the
        # neighbouring row's decorations into the new horizontal arrangement.
        draw_texture_rect_region(texture,Rect2(181,35,501,112),Rect2(181,45+source_y,501,112))
        var vertices := PackedVector2Array()
        var uv := PackedVector2Array()
        for j in range(96):
            var offset := Vector2.RIGHT.rotated(TAU*float(j)/96.0)*86.0
            vertices.append(Vector2(108,97)+offset)
            uv.append((Vector2(108,104+source_y)+offset)/Vector2(texture.get_size()))
        draw_polygon(vertices,PackedColorArray([Color.WHITE]),uv,texture)
        # Row placement is already applied by draw_set_transform(). All overlays
        # remain local to the same cell as its artwork.
        var dy := -10.0
        var track := StyleBoxFlat.new()
        track.bg_color = CREAM
        track.set_corner_radius_all(12)
        draw_style_box(track,Rect2(198,106+dy,278,31))
        var fraction := clampf(values[i]/maxf(maxima[i],1.0),0.0,1.0)
        var bar_tint: Color = colors[i] if use_stat_colors else fill_color
        _draw_fill(Vector2(200,109+dy),272.0,25.0,fraction,bar_tint)
        var font := get_theme_font("font")
        if font != null:
            if chinese_labels:
                var label_plate := StyleBoxFlat.new()
                label_plate.bg_color = Color("0d1721")
                label_plate.border_color = Color("69644f")
                label_plate.border_width_bottom = 1
                label_plate.corner_radius_top_left = 6
                label_plate.corner_radius_top_right = 6
                draw_style_box(label_plate,Rect2(187,49+dy,264,49))
                draw_circle(Vector2(205,74+dy),4.0,bar_tint)
                draw_string(font,Vector2(224,84+dy),labels[i],HORIZONTAL_ALIGNMENT_LEFT,218,38,CREAM)
            if show_numbers:
                var txt := "%d/%d" % [int(values[i]),int(maxima[i])]
                var fitted_size := font_size
                while fitted_size > 18 and font.get_string_size(txt,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted_size).x > 116:
                    fitted_size -= 1
                var number_color := Color("843e34") if fraction <= 0.25 else text_color
                draw_string(font,Vector2(494,119+dy+float(fitted_size)*0.34),txt,HORIZONTAL_ALIGNMENT_CENTER,120,fitted_size,number_color)
    draw_set_transform(Vector2.ZERO)

func _draw_fill(origin: Vector2, width: float, height: float, fraction: float, tint: Color) -> void:
    if fraction <= 0.0:
        return
    var fill_width := width*fraction
    fill_width = minf(fill_width,width)
    var r := minf(height,fill_width)/2.0
    var left := origin + Vector2(r,height/2.0)
    draw_circle(left,r,tint)
    if fill_width > 2.0*r:
        draw_rect(Rect2(origin+Vector2(r,0),Vector2(fill_width-2.0*r,height)),tint)
        draw_circle(origin+Vector2(fill_width-r,height/2.0),r,tint)
    # Delicate decorative moving light line, does not alter the original trim.
    if fill_width > 45.0:
        var end_x := origin.x+fill_width-11.0
        var pts := PackedVector2Array()
        for j in range(13):
            var x := origin.x+12.0+(end_x-origin.x-12.0)*float(j)/12.0
            var y := origin.y+height*0.41+sin(float(j)*0.7)*2.0
            pts.append(Vector2(x,y))
        draw_polyline(pts,tint.lightened(0.28),1.5,true)
