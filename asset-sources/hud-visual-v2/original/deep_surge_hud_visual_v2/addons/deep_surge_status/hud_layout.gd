@tool
extends Control
## Arrange the three widgets in reference (1672x941) coordinates.
## Children are ordinary editable Controls; HUD can be used inside a CanvasLayer.
const REFERENCE_SIZE:=Vector2(1672,941)
@export var ui_scale_multiplier:float=1.0:
    set(v):ui_scale_multiplier=clampf(v,0.35,2.0);_reflow()
@export var event_panel_visible:bool=true:
    set(v):event_panel_visible=v;_reflow()
@export var ap_visible:bool=true:
    set(v):ap_visible=v;_reflow()
@export var statuses_visible:bool=true:
    set(v):statuses_visible=v;_reflow()
func _ready()->void:
    mouse_filter=MOUSE_FILTER_PASS
    _reflow()
func _notification(what:int)->void:
    if what==NOTIFICATION_RESIZED:
        _reflow()
func _reflow()->void:
    if not is_inside_tree():return
    var parent_size:=size
    if parent_size.x<10.0 or parent_size.y<10.0:return
    var s:=minf(parent_size.x/REFERENCE_SIZE.x,parent_size.y/REFERENCE_SIZE.y)*ui_scale_multiplier
    var right:=parent_size.x-111.0*s
    var status:=get_node_or_null("StatusHUD") as Control
    var ap:=get_node_or_null("APHUD") as Control
    var event_panel:=get_node_or_null("EventPanel") as Control
    if status:
        status.visible=statuses_visible
        status.position=Vector2(right-682.0*s,24.0*s)
        status.size=Vector2(682.0,679.0)*s
    if ap:
        ap.visible=ap_visible
        ap.position=Vector2(right-738.0*s,700.0*s)
        ap.size=Vector2(738.0,188.0)*s
    if event_panel:
        event_panel.visible=event_panel_visible
        event_panel.position=Vector2(91.0,142.0)*s
        event_panel.size=Vector2(678.0,745.0)*s
