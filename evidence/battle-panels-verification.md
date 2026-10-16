# 战斗四大板块验证 · 2026-10-17

用户要求战斗界面应用附件 UI，只应用四个大板块。源为 `deep_surge_ui_panels (1).zip`；四张 PNG 原样保存在 `asset-sources/battle-ui-panels-v1/`，运行副本在 `assets/battle_ui/panels_v1/`。附件 README 仅作为素材说明，没有将其当作新增任务要求。

运行映射：`pages/battle_hud_view.gd`，左怪物、中上意图、中下预览、右日志。图片等比，原生文字及按钮叠加于内部；图片本身不拦截输入。怪物图后原生圆形底色遮挡底层木筏标签。125% UI 模式可用区域更小，内容与图片同步缩放。既有 dispatch、预览、取消、迎击、打捞、手牌与规则代码未变。

所有命令在 `deep-surge-godot/` 执行，Godot 可执行文件为 `C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`。

| 验证 | 命令/方式 | 结果 |
|---|---|---|
| 首次失败 | `--headless --path . --script res://tests/test_battle_panel_art.gd` | 修正夹具缺少节点后，因原界面缺少四张素材与独立意图面板而失败，符合预期 |
| 正式素材导入 | `--headless --editor --path . --quit` | 退出 0 |
| 最终 GPU 布局 | `--path . --script res://tests/test_battle_panel_art.gd` | PASS，退出 0；RTX 4060 Laptop / Compatibility |
| 战斗设备交互 | `--headless --path . --script res://tests/test_battle_equipment_ui.gd` | PASS，退出 0；资源选择、预览/取消不改快照，确认消费选定 UID，增益与密集手牌布局 |
| 战斗动作回归 | `--headless --path . --script res://tests/test_battle_actions.gd` | PASS，退出 0 |
| 本次资产核验 | Python 核对四个 `texture.battle.panel.*` 与 `ui.battle.panels` 的文件/hash/尺寸，比较运行 PNG 与源字节 | 五项 PASS |
| 全量旧资产检查 | `python tools/check_supplied_assets.py` | 失败：原有 `ui.item-card` hash mismatch；本次未修改该脚本及资产 |

GPU 夹具以真实敌方意图与发电机增益测试：1280×720、1600×900、1920×1080、1920×900 自由比例 100%，以及 1280×720、1920×900 自由比例 125%。检查四图原比例、视口边界、彼此不相交、不压住手牌顶栏，以及文字/按钮没有越过所属大板块。布局使用原始设计比例统一拟合，因此 125% 设置下战斗内容也会变小。

截图：`battle-panels-1280x720.png`、`battle-panels-1600x900.png`、`battle-panels-1920x1080.png`、`battle-panels-1920x900.png`、`battle-panels-1280x720-125.png`、`battle-panels-1920x900-125.png`。已人工查看 1280、1600 和 125% 截图。

仅表现层变化，未更改内容版本；未执行完整路线重放或移动端设备验证，也未提交或推送。
