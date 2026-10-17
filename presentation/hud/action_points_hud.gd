@tool
extends Control
## Ornate, large-token action-points widget based on the user-selected visual.
signal ap_changed(current: int, maximum: int)
const DESIGN_SIZE := Vector2(1814.0,454.0)
var art_catalog=preload("res://presentation/asset_catalog.gd").new()
const ORB_FULL = preload("res://assets/ui/hud/ap_orb_full.png")
const ORB_EMPTY = preload("res://assets/ui/hud/ap_orb_empty.png")
const IVORY := Color("f2e6cd")
@export_group("AP")
@export_range(0,10,1) var current_ap: int = 3:
    set(v): current_ap=clampi(v,0,max_ap); queue_redraw()
@export_range(1,10,1) var max_ap: int = 3:
    set(v): max_ap=clampi(v,1,10); current_ap=mini(current_ap,max_ap); queue_redraw()
@export_group("Appearance")
@export var label_text: String = "行动点":
    set(v): label_text=v; queue_redraw()
@export var show_numbers := true:
    set(v): show_numbers=v; queue_redraw()
@export var token_scale: float = 1.0:
    set(v): token_scale=clampf(v,0.7,1.4); queue_redraw()
@export var art_override: Texture2D:
    set(v): art_override=v; queue_redraw()

func _ready() -> void:
    mouse_filter=MOUSE_FILTER_IGNORE
    texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    if size == Vector2.ZERO:
        custom_minimum_size=DESIGN_SIZE
    resized.connect(queue_redraw)
    queue_redraw()
func _get_minimum_size() -> Vector2:
    return Vector2(280,70)
func set_ap(value:int,maximum:int=-1)->void:
    if maximum > 0:
        max_ap=maximum
    current_ap=value
    ap_changed.emit(current_ap,max_ap)
func _draw()->void:
    if size.x<=0.0 or size.y<=0.0:
        return
    var fit := minf(size.x/DESIGN_SIZE.x,size.y/DESIGN_SIZE.y)
    draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE*fit)
    var texture: Texture2D = art_override if art_override != null else art_catalog.texture("texture.hud.nautical.action-points")
    draw_texture_rect(texture,Rect2(Vector2.ZERO,DESIGN_SIZE),false)
    var font:=get_theme_font("font")
    if font!=null:
        # Reuse an empty navy patch from this same artwork under the live label.
        # This supports the night label without leaving the baked daytime text.
        draw_texture_rect_region(texture,Rect2(465,118,370,110),Rect2(470,240,370,110))
        draw_string(font,Vector2(490,201),label_text,HORIZONTAL_ALIGNMENT_LEFT,600,78,IVORY)
        if show_numbers:
            draw_string(font,Vector2(1210,333),"%d / %d" % [current_ap,max_ap],HORIZONTAL_ALIGNMENT_CENTER,450,84,IVORY)
    var token_space:=minf(210.0,570.0/maxf(1.0,float(max_ap-1)))
    var start_x:=800.0-token_space*float(max_ap-1)/2.0
    var diameter:=minf(128.0*token_scale,token_space*0.86)
    for i in range(max_ap):
        var c:=Vector2(start_x+token_space*float(i),303)
        draw_texture_rect(ORB_FULL if i<current_ap else ORB_EMPTY,Rect2(c-Vector2.ONE*diameter/2.0,Vector2.ONE*diameter),false)
    draw_set_transform(Vector2.ZERO)
