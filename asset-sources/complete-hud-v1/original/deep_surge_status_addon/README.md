# Deep Surge HUD Addon (Godot 4)

Procedural Godot 4 addon for the **Deep Surge** prototype.

Included widgets:
- **SurgeStatusHUD** — top-right four-stat panel (Health / Satiety / Water / SAN)
- **SurgeActionPointHUD** — enlarged action-point circles (AP)
- **SurgeEventChoicePanel** — interactive event choices with `choice_selected(index, choice)` signal

Both widgets are drawn in pure GDScript and do not depend on image atlases.

## Installation
1. Copy the `addons/deep_surge_status` folder into your Godot 4 project under `res://addons/`.
2. Open **Project > Project Settings > Plugins**.
3. Enable **Deep Surge Status HUD**.
4. Add either `SurgeStatusHUD` or `SurgeActionPointHUD` from the Create Node dialog.

## Quick usage

### Status HUD
```gdscript
$HUD.set_stat(&"health", 25, 30)
$HUD.set_stat(&"water", 70, 100)
```

### Action Point HUD
```gdscript
$APHUD.set_ap(2, 3)
```

If you only want to update the current AP:
```gdscript
$APHUD.set_ap(1)
```

## Inspector-exposed settings
### SurgeStatusHUD
- `health`, `max_health`
- `satiety`, `max_satiety`
- `water`, `max_water`
- `sanity`, `max_sanity`
- `show_numbers`
- `show_english_labels`
- `panel_opacity`
- `bar_color`

### SurgeActionPointHUD
- `current_ap`, `max_ap`
- `label_text`, `english_label`
- `show_english_label`
- `show_numbers`
- `panel_opacity`
- `active_fill`
- `inactive_fill`

## Demo controls
- `1 / 2 / 3 / 4` decrease Health / Satiety / Water / SAN
- `5 / 6` decrease / increase AP
- `R` restore all values

## Event choice panel
Add `SurgeEventChoicePanel` under your HUD and connect its signal:
```gdscript
$EventPanel.choice_selected.connect(func(index, choice): print(index, choice))
$EventPanel.set_event("漂流物", "你发现一只密封木箱。", PackedStringArray(["打开", "带走", "忽略"]))
```
The demo places a compact 4-stat HUD in the upper right, enlarged AP indicators below, and the event panel at the bottom right.
