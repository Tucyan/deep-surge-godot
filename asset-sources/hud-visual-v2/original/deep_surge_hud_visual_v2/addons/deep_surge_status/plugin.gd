@tool
extends EditorPlugin
const ICON=preload("res://addons/deep_surge_status/icon.svg")
func _enter_tree()->void:
    add_custom_type("SurgeStatusHUD","Control",preload("res://addons/deep_surge_status/status_hud.gd"),ICON)
    add_custom_type("SurgeActionPointHUD","Control",preload("res://addons/deep_surge_status/action_points_hud.gd"),ICON)
    add_custom_type("SurgeEventChoicePanel","Control",preload("res://addons/deep_surge_status/event_choice_panel.gd"),ICON)
func _exit_tree()->void:
    remove_custom_type("SurgeEventChoicePanel")
    remove_custom_type("SurgeActionPointHUD")
    remove_custom_type("SurgeStatusHUD")
