extends Control
@onready var hud:Node=$DeepSurgeHUD/StatusHUD
@onready var ap_hud:Node=$DeepSurgeHUD/APHUD
@onready var event_panel:Node=$DeepSurgeHUD/EventPanel
@onready var hint:Label=$Hint
func _ready()->void:
    event_panel.connect("choice_selected",Callable(self,"_on_choice_selected"))
func _on_choice_selected(index:int,choice:String)->void:
    hint.text="已选择事件选项 %d：%s"%[index+1,choice]
func _unhandled_key_input(event:InputEvent)->void:
    if not event is InputEventKey or not event.pressed or event.echo:return
    match event.keycode:
        KEY_Q:hud.call("set_stat",&"health",maxf(0.0,float(hud.get("health"))-5.0))
        KEY_W:hud.call("set_stat",&"satiety",maxf(0.0,float(hud.get("satiety"))-10.0))
        KEY_E:hud.call("set_stat",&"water",maxf(0.0,float(hud.get("water"))-10.0))
        KEY_T:hud.call("set_stat",&"sanity",maxf(0.0,float(hud.get("sanity"))-10.0))
        KEY_A:ap_hud.call("set_ap",maxi(0,int(ap_hud.get("current_ap"))-1))
        KEY_S:ap_hud.call("set_ap",mini(int(ap_hud.get("max_ap")),int(ap_hud.get("current_ap"))+1))
        KEY_R:
            for stat in ["health","satiety","water","sanity"]:
                hud.call("set_stat",StringName(stat),float(hud.get("max_"+stat)))
            ap_hud.call("set_ap",int(ap_hud.get("max_ap")))
