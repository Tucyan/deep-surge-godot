# 轮初生产修订验证 · 2026-10-15

用户要求避免设备刚生产完就进入弃牌。滤水器、土盆、捕捞网与发电机现于上一轮弃牌完成、新一轮计数推进后，在涌泉和导航开放前生产；新产物可以超限行动，等本轮末再整理。轮末仍处理筏格老化/脱落和临时增益到期；破损设备暂停。周期/产量/增压/燃料数量保留，安装后下一轮开始计进度，终局和章节停点不补产。

发电机超出长期容量的临时增益在产出当轮末到期，提供一整轮使用机会。运行内容版本 godot-flow-v02-6，保存 schema2 和随机算法不变。仅接受精确已知旧内容指纹；旧弃牌档已做过轮末生产，迁移时跳过紧接的一次轮初生产，跳过标记可保存。旧教学文本同步为轮初生产后可再次保存，不修改历史获得物资或重抽随机。

## 当次执行结果

Godot 4.7.2，使用 `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/<脚本>.gd`。

| 脚本 | 结果与范围 |
| --- | --- |
| test_round_start_production.gd | PASS；先观察旧实现因弃牌前生产、终局生产等断言失败，再修改实现。覆盖先弃牌后轮初产物超限、二轮周期、破损暂停、脱落先于生产、发电燃料/临时期限、终局无产物、夜间衔接、读档不重产/重抽、旧弃牌档防双计、旧教学定义迁移及未知指纹拒绝 |
| test_new_equipment.gd | PASS；捕捞网、发电机、增压、箱子与设备存档 |
| test_save.gd | PASS；JSON/文件保存恢复、非法档拒绝与随机恢复 |
| test_story.gd | PASS；学者A/B/C与独航15站、夜间和逐阶段存档 |
| test_routes.gd | PASS；种子0迷失路线及种子22十二航次生存路线 |
| test_auto_progress.gd | PASS；自动推进 |
| test_flow.gd | PASS；会话流程 |
| test_mechanics.gd | PASS；制造/安装/战斗/轮末等机制 |
| test_battle_equipment_ui.gd | PASS；无图形模式下真实UI节点与设备入口 |
| test_filter_stages.gd | PASS；滤水器等待/就绪/破损外观、轮初产水预告文案与实际周期一致 |

`node --test tests/content.test.mjs`：9/9 PASS。

按 Windows CRLF 口径执行 `git -c core.whitespace=cr-at-eol diff --check`，本次涉及的文件通过。普通 `git diff --check` 会将仓库大量既有 CRLF 行标记为尾部空白，未为此批量重写无关文件。

界面文案和V0.2契约已同步；本次没有进行GPU截图或人工试玩，不声称已验收渲染效果。
