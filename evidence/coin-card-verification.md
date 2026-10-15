# 贝币卡牌验证

2026-10-14，Godot 4.7.2，Windows，兼容渲染器 / RTX 4060。

- 新测试在实现前以 `Positive balance appears as one hand card` 失败，实现后通过。
- `test_coin_card.gd`：零余额不显示；正余额唯一卡面、稳定 UID 和数量；叠牌开关保留货币数量；查看不消费或改变随机；支付更新及归零移除；存档恢复；轮末点击弃置全部并进入导航。headless 和实际 GPU 渲染均 PASS。
- 回归 PASS：`test_flow.gd`、`test_mechanics.gd`（含商店贝币支付）、`test_save.gd`、`test_routes.gd`（失败/成功航程）、`test_clean_ui.gd`、`test_story_edges.gd`、`test_settlement_integration.gd`、`test_hand_layout.gd`、`test_hand_fan.gd`、`test_hand_click.gd`、`test_hand_gestures.gd`。
- `python tools/check_supplied_assets.py`：PASS，106 个 hash 绑定。
- `test_story.gd`：PASS，学者 A/B/C 与独航四条 15 站路线，含夜间操作和每阶段存档恢复。
- 实际 1280×720 渲染：`coin-card-1280.png`，已检查一张贝币卡的 ×7 徽章及右侧持有数量/商店用途说明。画面使用隔离测试夹具，不覆盖用户存档。

复现：

```powershell
godot --headless --path . --script tests/test_coin_card.gd
godot --path . --script tests/test_coin_card.gd -- --capture
```

贝币余额依然保存于 `state.coins`，卡面由只读视图投影；未新增外部素材、存档格式或货币规则。未验证发行导出构建。
