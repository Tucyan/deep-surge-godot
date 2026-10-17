# 2026-10-17 手牌悬停遮挡修复

修复普通悬停被错误限制为必须战斗选中才能腾位的问题。上浮只调整纵向位置，所有常规牌保持相同 z_index，兄弟节点顺序不变。拖动、离场仍使用各自的既有表现。

卡框画布按1024:1536计算宽度；实际遮挡按当前图片 alpha>128 的横向边界80..945计算，透明留白与额外阴影不参与。重叠低于可见卡框宽度5%不移动，达到阈值才将右侧遮挡牌移至卡框边缘，窗口右边界限制仍生效。

新增回归断言先在原逻辑下复现 `HAND FAN: FAIL`，修复后通过。场景夹具不写入库存，悬停前后规则/RNG快照一致。

在工程根目录执行，全部退出码0：

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_hand_fan.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_hand_gestures.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/hand_hover_visual.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/nautical_hud_visual.gd
```

边界覆盖0%、4.9%、5%、5.1%、35%；检查普通悬停无需战斗选中、左邻与目标牌横坐标保持、悬停与选中上浮不改z_index。GPU Compatibility / RTX4060 Laptop实拍见 [hand-hover-clearance.png](hand-hover-clearance.png)：上排4.9%不横移，下排23.94%右侧腾位。后者移动32.69逻辑像素。
