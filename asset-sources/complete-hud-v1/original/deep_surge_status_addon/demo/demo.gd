extends Control

@onready var hud: Control = $HUD
@onready var ap_hud: Control = $APHUD
@onready var event_panel: PanelContainer = $EventPanel

func _ready() -> void:
    event_panel.choice_selected.connect(_on_event_choice)

func _on_event_choice(index: int, choice: String) -> void:
    print("Event option selected: ", index, " / ", choice)
    event_panel.event_number += 1

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_1: hud.set_stat(&"health", maxf(0, hud.health - 5))
        KEY_2: hud.set_stat(&"satiety", maxf(0, hud.satiety - 10))
        KEY_3: hud.set_stat(&"water", maxf(0, hud.water - 10))
        KEY_4: hud.set_stat(&"sanity", maxf(0, hud.sanity - 10))
        KEY_5: ap_hud.set_ap(maxi(0, ap_hud.current_ap - 1))
        KEY_6: ap_hud.set_ap(mini(ap_hud.max_ap, ap_hud.current_ap + 1))
        KEY_R:
            for stat in ["health", "satiety", "water", "sanity"]:
                hud.set_stat(StringName(stat), hud.get("max_" + stat))
            ap_hud.set_ap(ap_hud.max_ap)
