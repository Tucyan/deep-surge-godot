@tool
extends Control
## Independent supplied medallions with procedural tracks and real stat values.
signal status_changed(stat: StringName, value: float, maximum: float)
var icon_catalog=preload("res://presentation/asset_catalog.gd").new()

const DESIGN_SIZE := Vector2(760.0,56.0)
const BLUE := Color("285cac")
const CREAM := Color("f2e6cd")

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
@export var fill_color: Color = BLUE:
    set(v): fill_color = v; queue_redraw()
@export var use_stat_colors := true:
    set(v): use_stat_colors = v; queue_redraw()
@export var text_color: Color = CREAM:
    set(v): text_color = v; queue_redraw()
@export var font_size: int = 16:
    set(v): font_size = clampi(v,12,48); queue_redraw()

func _ready() -> void:
    mouse_filter = MOUSE_FILTER_PASS
    texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    if size == Vector2.ZERO:
        custom_minimum_size = DESIGN_SIZE
    resized.connect(queue_redraw)
    if tooltip_text.is_empty(): tooltip_text="生命 / 饱食 / 水分 / 理智"
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

const TRACK_WIDTH := 72.0

func stat_layout() -> Array:
    var values=[health,satiety,water,sanity]
    var maxima=[max_health,max_satiety,max_water,max_sanity]
    var columns=2 if two_columns else 4
    var cell=Vector2(size.x/columns,size.y/(2 if two_columns else 1))
    var icon_size=minf(50,cell.y-2)
    var number_size=font_size
    var font=get_theme_font("font")
    var texts=[]
    var widest=0.0
    for i in range(4):
        var text="%d/%d" % [int(values[i]),int(maxima[i])]
        texts.append(text)
        widest=maxf(widest,font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size).x)
    # All four tracks switch together; their width never responds to the window.
    var show_tracks=cell.x>=icon_size+3+TRACK_WIDTH+7+widest+10
    var result=[]
    for i in range(4):
        var origin=Vector2((i%columns)*cell.x,floorf(float(i)/columns)*cell.y)
        var start=origin+Vector2(icon_size+3,cell.y*.5-6)
        var number_start=start.x+(TRACK_WIDTH+7 if show_tracks else 0.0)
        result.append({
            "icon":Rect2(origin+Vector2(0,(cell.y-icon_size)*.5),Vector2.ONE*icon_size),
            "track":Rect2(start,Vector2(TRACK_WIDTH,12)) if show_tracks else Rect2(),
            "number":Rect2(Vector2(number_start,origin.y),Vector2(widest,cell.y)),
            "text":texts[i], "font_size":number_size,
        })
    return result

func _draw() -> void:
    if size.x <= 0 or size.y <= 0: return
    var values=[health,satiety,water,sanity]
    var maxima=[max_health,max_satiety,max_water,max_sanity]
    var names=["health","hunger","water","sanity"]
    var colors=[Color("bb5352"),Color("e6b665"),Color("639dca"),Color("9a7ac0")]
    var font=get_theme_font("font")
    var cells=stat_layout()
    for i in range(4):
        var cell: Dictionary=cells[i]
        draw_texture_rect(icon_catalog.texture("texture.hud.nautical."+names[i]),cell.icon,false)
        var bar: Rect2=cell.track
        if bar.has_area():
            var track=StyleBoxFlat.new(); track.bg_color=Color("152332"); track.border_color=Color("ad9d7d")
            track.set_border_width_all(1); track.set_corner_radius_all(6)
            draw_style_box(track,bar)
            var fraction=clampf(values[i]/maxf(maxima[i],1),0,1)
            if fraction>0:
                var fill=StyleBoxFlat.new(); fill.bg_color=colors[i] if use_stat_colors else fill_color; fill.set_corner_radius_all(4)
                draw_style_box(fill,Rect2(bar.position+Vector2.ONE,Vector2((TRACK_WIDTH-2)*fraction,10)))
                draw_line(bar.position+Vector2(4,3),bar.position+Vector2(maxf(4,(TRACK_WIDTH-2)*fraction-3),3),Color(1,1,1,.24),1,true)
        var number: Rect2=cell.number
        if show_numbers or not bar.has_area():
            draw_string(font,Vector2(number.position.x,number.get_center().y+cell.font_size*.35),cell.text,HORIZONTAL_ALIGNMENT_LEFT,-1,cell.font_size,text_color)
        if i>0:
            var icon: Rect2=cell.icon
            draw_line(icon.position+Vector2(-5,10),Vector2(icon.position.x-5,icon.end.y-10),Color(.7,.62,.47,.25),1,true)
