# Deep Surge / 深潮 · 封面菜单素材包

共 **13 张 PNG**：6 个按钮的深色、浅色两种状态（12 张），以及最新游戏 LOGO（1 张）。

## 素材索引

| Index | 文件名 | 内容 | 状态 |
|---:|---|---|---|
| 01 | `assets/01_start_game_dark.png` | 开始游戏 | 深色底 |
| 02 | `assets/01_start_game_light.png` | 开始游戏 | 浅色底（悬停/高亮） |
| 03 | `assets/02_continue_dark.png` | 继续游戏 | 深色底 |
| 04 | `assets/02_continue_light.png` | 继续游戏 | 浅色底（悬停/高亮） |
| 05 | `assets/03_journal_dark.png` | 航海笔记 | 深色底 |
| 06 | `assets/03_journal_light.png` | 航海笔记 | 浅色底（悬停/高亮） |
| 07 | `assets/04_shop_dark.png` | 局外商店 | 深色底 |
| 08 | `assets/04_shop_light.png` | 局外商店 | 浅色底（悬停/高亮） |
| 09 | `assets/05_rewind_dark.png` | 回溯潮涌 | 深色底 |
| 10 | `assets/05_rewind_light.png` | 回溯潮涌 | 浅色底（悬停/高亮） |
| 11 | `assets/06_exit_dark.png` | 退出游戏 | 深色底 |
| 12 | `assets/06_exit_light.png` | 退出游戏 | 浅色底（悬停/高亮） |
| 13 | `assets/07_deep_surge_logo.png` | 游戏 LOGO | 透明底 |

## 设计与状态说明

1. 六个按钮每个都有 **dark**（深色）与 **light**（浅色）两张。第一项「开始游戏」初始视觉为浅色，而其他五项初始视觉为深色。
2. 想还原最初封面效果：开始游戏加载 `01_start_game_light.png`，其余五项使用对应 `_dark.png`。悬停某项时，把该项换成对应 `_light.png`，其他项切回 `_dark.png`。
3. 最新生成的变体中，**深色开始游戏**不带最右侧十字星，其余五项**浅色版本**带最右侧十字星。
4. 每张图是单独裁切、去除外部展示矩形框后的 **RGBA 透明 PNG**；图中文字属于美术图的一部分，不能直接通过 Godot 的 Label 改字。
5. 按钮统一输出为 `1100×370` 透明画布，适合同一套尺寸切换；LOGO 是独立透明 PNG，按实际尺寸等比缩放。

## Godot 4 使用方式

- 把 `assets/` 拷贝到项目（例如 `res://assets/title_ui/`）。
- 推荐每个按钮使用一个 **TextureButton**，`texture_normal` 对应 `_dark.png`，`texture_hover` 和 `texture_pressed` 对应 `_light.png`。
- 开始游戏要在默认状态呈浅色：可以把 `01_start_game_light.png` 设为 normal，`01_start_game_dark.png` 设为 hover；若希望统一成“悬停亮色”，则在代码中统一管理默认选中项。
- 六个 `TextureButton` 保持相同尺寸并使用相同坐标系，勾选 `ignore_texture_size=false` 或按照你的屏幕分辨率统一设定尺寸。建议 `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED`。
- 可以在 `mouse_entered`/`mouse_exited` 时用 Tween 让节点 `scale` 从 `1.0` 变到 `1.06~1.1`；确保 `pivot_offset=size/2` 防止放大时漂移。
- 如需用默认选中高亮，记得在切换鼠标悬停时将其他按钮还原为深色。
- `07_deep_surge_logo.png` 用 **TextureRect**，开启保持比例显示，避免拉伸。

### GDScript 示例（按钮鼠标悬停放大）

```gdscript
extends TextureButton

func _ready()->void:
    pivot_offset=size/2
    mouse_entered.connect(func():_animate_scale(1.08))
    mouse_exited.connect(func():_animate_scale(1.0))

func _animate_scale(value:float)->void:
    create_tween().tween_property(self,"scale",Vector2.ONE*value,0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
```

## 注意事项

- 本素材包只含图片及说明，不包括完整封面插件、场景或保存系统。
- 素材来自本次对话中已生成的四张三按钮图及最新 LOGO，裁切时未重新设计按钮内容。
- 由于原三按钮图具有白色展示底，已做透明背景分离；建议在 Godot 深色背景下检查所有边缘。
