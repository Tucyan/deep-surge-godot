@tool
extends EditorPlugin

func _enter_tree() -> void:
    add_custom_type("SurgeStatusHUD", "Control", preload("res://addons/deep_surge_status/status_hud.gd"), preload("res://addons/deep_surge_status/icon.svg"))
    add_custom_type("SurgeEventChoicePanel", "PanelContainer", preload("res://addons/deep_surge_status/event_choice_panel.gd"), preload("res://addons/deep_surge_status/icon.svg"))
    add_custom_type("SurgeActionPointHUD", "Control", preload("res://addons/deep_surge_status/action_points_hud.gd"), preload("res://addons/deep_surge_status/icon.svg"))

func _exit_tree() -> void:
    remove_custom_type("SurgeEventChoicePanel")
    remove_custom_type("SurgeActionPointHUD")
    remove_custom_type("SurgeStatusHUD")
