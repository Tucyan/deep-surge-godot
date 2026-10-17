# 全屏图鉴验证

日期：2026-10-17。仅调整表现，不修改规则、内容版本、存档或随机算法。

- 顶部卡牌／怪物／藏品／结局四分类；全屏占用，右上 X 关闭。
- 左侧占较大区域，三列两行矩形卡片，每页六项，上图下标题；选中描边，图片和标题均可点击，底部分页，不使用滚动容器。末页空位维持网格比例。
- 右侧上图下文，包含名称、“故事”“说明”页签。默认说明，复用现有说明／意图；尚无故事文本时显示“故事内容暂未收录。”，不编造剧情。
- 未发现条目继续显示卡背、编号及解锁提示，不泄漏名称、图片或说明。藏品分类保留原数据与发现限制，不开放藏品机制。
- 复用既有 AssetId 卡图／怪物图／藏品图和 ui.card.back，无新增图片。

在工程目录执行，均退出码 0：

```powershell
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/verify_encyclopedia.gd
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_clean_ui.gd
```

结果：`encyclopedia GPU: 0 failures`、`CLEAN HUD: PASS`。

GPU 测试覆盖 1600×900 / 100%、1280×720 / 100%、1280×720 / 125%、1920×820 / 125%；验证全屏（容器取整误差小于1逻辑像素）、左宽右窄、上图下标题、图片/标题鼠标点击、详情两页签、真实已发现说明、故事占位、分类及分页、浏览前后完整 session 快照不变。

另验证未发现条目详情保持隐藏，以及实际点击右上 X 关闭全屏页；资产 SHA-256 校验通过。

截图：`encyclopedia-1600x900-100.png`、`encyclopedia-1280x720-100.png`、`encyclopedia-1280x720-125.png`、`encyclopedia-1920x820-125.png`、`encyclopedia-discovered.png`。人工检查了 1280×720 / 125% 和已发现条目的宽屏截图。

未验证：移动端独立导出及极端窗口尺寸。无规则变动，未重跑完整规则路线。
