# Deep Surge Visual HUD v2.0 · Godot 4

本版直接修改 **Godot 插件实现**（不是另做效果图）。目标：尽量还原参考图的灯塔事件面板、四条状态栏和 AP 圆珠。

## 相比旧版本的重要变化

- 旧版用直角纯 GDScript 矩形近似美术；新版引用 `textures` 内的真实参考图装饰纹理，边框、图标、灯塔和星芒不再被简化掉。
- 数字、蓝色进度和文字仍在 Godot 内动态绘制；事件三选项能接受鼠标点击并发射信号。
- `SurgeStatusHUD`：四条状态（生命、饱食、水分、SAN）；默认使用参考图的英文铭文（HEALTH/FULLNESS/WATER/SAN），勾选 `chinese_labels` 可覆盖中文。
- `SurgeActionPointHUD`：3 个更大的环形 AP 圆珠，可调最大数量与显示比例。
- `SurgeEventChoicePanel`：灯塔主题事件背景；编辑标题、说明、三项选择。
- `hud_layout.gd` 提供随屏幕等比缩放的布局脚本；编辑器内可预览。

## 安装

复制 `addons/deep_surge_status` 到你的 Godot 4 项目对应目录，项目设置 -> 插件启用 **Deep Surge Visual HUD**。

可以直接把 `demo/hud_layout.tscn` 复制到你的工程，然后从 `CanvasLayer` 添加为子节点（要同时复制该场景及其依赖的插件目录）；或分别创建以下节点：

- `SurgeStatusHUD`
- `SurgeActionPointHUD`
- `SurgeEventChoicePanel`

推荐用打包里的整个示例工程先打开 `project.godot` 对比。

## 脚本操作

```gdscript
$DeepSurgeHUD/StatusHUD.set_stat(&"health",22,30)
$DeepSurgeHUD/APHUD.set_ap(2,3)
$DeepSurgeHUD/EventPanel.set_event("远方的微光","雾中隐约亮起了灯光……",PackedStringArray(["驶向灯塔","观察一番","离开"]))
$DeepSurgeHUD/EventPanel.choice_selected.connect(_on_choice)
func _on_choice(index:int,choice:String)->void:
    print(index,choice)
```

状态栏 `set_stat` 支持 `health/satiety/water/sanity`。事件栏可单独替换 `art_override` 贴图，也可编辑字号、色彩。

## 示例控制

`Q/W/E/T` 消耗四项状态；`A/S` 减少 / 增加 AP；`R` 恢复；鼠标点击任意事件选项会更新左上角提示。

## 适配提醒

设计基准为 **1672×941**（参考图原始大小）。`hud_layout.gd` 自动按画面宽高等比缩放，移动端横屏可继续缩放到 16:9 或 19.5:9。想移动模块时直接更改该布局脚本中的锚定偏移或把三个控件独立拖动。

视觉素材来源于你在对话中提供的那张 AI 设计参考，经过分层去字处理。被删除的文字和进度位置重新以 Godot 控件绘制，因字体渲染差异不可能逐像素一致，但美术结构已大幅接近原稿。

**验证状态**：已完成资源预览和源码检查；当前环境未安装 Godot，尚未在 Godot 引擎运行。
