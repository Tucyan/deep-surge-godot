@tool
extends Control
## Fully image-backed event choice UI. The lighthouse is painted art; all text/options are live.
signal choice_selected(index:int, choice:String)
const DESIGN_SIZE:=Vector2(678.0,745.0)
const ART=preload("res://addons/deep_surge_status/textures/event_art.png")
const IVORY:=Color("f1e7d3")
const ACTIVE:=Color("164b92")
const MUTED:=Color("d2c7b1")
@export_group("Content")
@export var event_title:String="远方的微光":
    set(v):event_title=v;queue_redraw()
@export_multiline var event_description:String="迷雾深处，一点微光忽明忽暗。\n那是废弃的灯塔，还是某种警告？":
    set(v):event_description=v;queue_redraw()
@export var choices:PackedStringArray=PackedStringArray(["驶向微光","远处观察","转身离开"]):
    set(v):choices=v;queue_redraw()
@export_group("Appearance")
@export_range(15,40,1) var heading_font_size:int=29:
    set(v):heading_font_size=v;queue_redraw()
@export_range(12,32,1) var body_font_size:int=21:
    set(v):body_font_size=v;queue_redraw()
@export_range(12,32,1) var option_font_size:int=21:
    set(v):option_font_size=v;queue_redraw()
@export var show_selected_first:=true:
    set(v):show_selected_first=v;queue_redraw()
@export var accent_color:Color=ACTIVE:
    set(v):accent_color=v;queue_redraw()
@export var art_override:Texture2D:
    set(v):art_override=v;queue_redraw()
var hovered_index:int=-1

func _ready()->void:
    mouse_filter=MOUSE_FILTER_STOP
    focus_mode=FOCUS_ALL
    if size==Vector2.ZERO:
        custom_minimum_size=DESIGN_SIZE
    queue_redraw()
func _get_minimum_size()->Vector2:
    return Vector2(260,285)
func set_event(title:String,description:String,options:PackedStringArray)->void:
    event_title=title
    event_description=description
    choices=options
    hovered_index=-1
    queue_redraw()
func _local_index(p:Vector2)->int:
    var q:=p*DESIGN_SIZE/size
    for i in range(mini(choices.size(),3)):
        var y:=489.0+float(i)*72.0
        if Rect2(48,y,560,65).has_point(q):
            return i
    return -1
func _gui_input(event:InputEvent)->void:
    if event is InputEventMouseMotion:
        var idx:=_local_index(event.position)
        if hovered_index!=idx:
            hovered_index=idx
            queue_redraw()
    elif event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
            var idx:=_local_index(event.position)
            if idx>=0:
                choice_selected.emit(idx,choices[idx])
                accept_event()
func _notification(what:int)->void:
    if what==NOTIFICATION_MOUSE_EXIT:
        hovered_index=-1
        queue_redraw()
func _unhandled_key_input(event:InputEvent)->void:
    if not visible or not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.keycode>=KEY_1 and event.keycode<=KEY_3:
        var idx:=event.keycode-KEY_1
        if idx<choices.size():
            choice_selected.emit(idx,choices[idx])
func _draw()->void:
    if size.x<=0.0 or size.y<=0.0:
        return
    draw_set_transform(Vector2.ZERO,0.0,size/DESIGN_SIZE)
    var tex:Texture2D=art_override if art_override!=null else ART
    draw_texture_rect(tex,Rect2(Vector2.ZERO,DESIGN_SIZE),false)
    var font:=ThemeDB.fallback_font
    if font!=null:
        draw_string(font,Vector2(110,337),event_title,HORIZONTAL_ALIGNMENT_CENTER,460,heading_font_size,IVORY)
        var lines:=_lines_to_fit(event_description,font,body_font_size,503.0)
        var start_y:=360.0
        for i in range(mini(lines.size(),4)):
            draw_string(font,Vector2(86,start_y+float(i)*30),lines[i],HORIZONTAL_ALIGNMENT_CENTER,507,body_font_size,IVORY)
        for i in range(mini(choices.size(),3)):
            var y:=489.0+float(i)*72.0
            var is_current:=hovered_index==i or (hovered_index==-1 and show_selected_first and i==0)
            if is_current:
                draw_rect(Rect2(143,y+8,414,49),Color(accent_color.r,accent_color.g,accent_color.b,0.66))
            draw_string(font,Vector2(161,y+43),choices[i],HORIZONTAL_ALIGNMENT_LEFT,362,option_font_size,IVORY if is_current else MUTED)
    draw_set_transform(Vector2.ZERO)
func _lines_to_fit(source:String,font:Font,font_px:int,max_width:float)->PackedStringArray:
    var result:=PackedStringArray()
    for paragraph in source.split("\n"):
        var line:=""
        for ch in paragraph:
            if font.get_string_size(line+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,font_px).x>max_width and line!="":
                result.append(line)
                line=ch
            else:
                line+=ch
        result.append(line)
    return result
