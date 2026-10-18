# 桌面战斗空间验证（2026-10-18）

问题：桌面战斗布局固定 y190，可用高度固定为视口高度减486，导致状态栏下出现大块空白。

修复：按实际状态栏底边+16、行动点区域顶边-8计算可用区；环境/休整文字行有内容时避让该行底边+8。全局坐标转回战斗视图局部坐标后计算，四张原图仍等比缩放，紧凑字号沿用原策略，手机布局不变。

1280×720、100% UI下，逻辑坐标从 y190..604 改为 y96..576，高度414→480；对应屏幕上方空白减少75.2像素，面板高度增加15.94%。125% UI下逻辑高度234→300；有环境/休整提示时分别使用 y123..576、y123..396。

## 当次验证

- `tests/test_battle_space.gd`：修复前六组几何断言失败；修复后 headless 与 RTX 4060 / OpenGL Compatibility 渲染全部 PASS。
- 六组窗口/UI组合：1280×720、1600×900、1920×1080、1920×900（100%），1280×720、1920×900（125%）；另有1280×720环境+休整提示两档缩放，共八场景。
- 检查顶部紧凑间距、充分使用可用高度、不遮AP与手牌、四面板不交叠、原图比例、正文/按钮边界。实看普通、125%及有环境提示截图。
- `tests/test_battle_panel_art.gd`、`tests/test_battle_equipment_ui.gd`、`tests/test_interaction_refresh.gd`：PASS。
- `tests/probe_interaction_latency.gd`：图形模式注入鼠标事件，105/105次松开后首个绘制即显示正确状态，无需追加点击；选牌/设置/合成沿用原HUD，没有整页重建。该回归用于检查布局没有破坏先前交互修复，不把帧完成延迟等同纯GPU渲染时间。
- 战斗材料点击：中位数31.24ms，最大54.09ms；攻击牌：中位数27.10ms，最大50.54ms。原始记录见 [JSON](battle-space-interaction.json)。
- `tools/check_supplied_assets.py`：PASS，254个hash绑定；资产清单中`ui.battle.panels`更新为v5。
- CRLF兼容的 `git diff --check`：PASS。只读复查发现的环境行问题已补回归并修复，无未处理问题。

## 渲染证据

- [1280×720](battle-space-1280x720.png)
- [1280×720 / 125%](battle-space-1280x720-125.png)
- [环境+休整 / 125%](battle-space-1280x720-125-buffs.png)
- [点击布条后的首个绘制](battle-space-input-battle_resource.png)

未提交、未推送；保留之前性能与交互修复。
