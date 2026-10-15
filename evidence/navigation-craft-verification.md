# 航行前操作、配方分页、设备双击安装验证

2026-10-14，Godot 4.7.2 / Windows。实际 GPU：RTX 4060 Laptop / OpenGL Compatibility。

当次通过：`test_navigation_actions`、`test_craft_grid`、`test_auto_install`、`test_mechanics`、`test_flow`/`test_session`、`test_save`、`test_hand_fan`、`test_hand_click`、`test_hand_gestures`、`test_clean_ui`、`test_supplied_assets`、`test_routes`。`test_story` 三种学者路线与独航路线通过。

- 新回归测试先运行失败，再实施。覆盖导航使用淡水、合成消耗材料/AP、目的地和随机流不变、出发不重置 AP、弃牌阶段拒绝合成。
- 合成网格每页八项/四列，科技禁用正确；测试夹具第九项独占第二页，返回第一页恢复八项，翻页不改快照。真实鼠标点击配方按钮制造灯，扣一 AP 并发放产物。
- 设备鼠标单击查看后 HUD 重建，第二次双击经 viewport 输入仍安装到首个完好空位，扣一 AP 且消耗卡牌；无空位/AP 时拒绝并完整回滚，战斗阶段拒绝安装。
- GPU 合成截图：`craft-grid-1280.png`、`craft-grid-1600.png`；导航布局：`navigation-actions-1600.png`。截图使用明确测试材料，不表示正常初始库存。
- GPU 事件预览：`node-event-embedded.png`、`node-event-choices.png`；事件右侧框与普通阶段框共用范围。
- 当前旧 `flow_ui_smoke.gd` 全航程鼠标入口检查仍引用已替换为 TextureButton 的「继续游戏」，在首页报空引用，未作为本次通过项。规则完整挑战由固定种子 `test_routes` 验证；本次合成按钮和设备双击另有实际 GPU 鼠标输入验证。
- 未验证独立导出构建和其他屏幕比例。
