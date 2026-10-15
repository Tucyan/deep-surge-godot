# 战斗与设备更新验证记录

日期：2026-10-15（Asia/Singapore）。执行模型：规则及UI子代理 `gpt-6-luna / high`，主代理负责集成、审查与结果核对。

## 范围

固定攻击/格挡、分层护盾、五种基础资源组合、三类发电机增益、盾架/发电机/捕捞网/箱子、额外战斗资源奖励、旧档迁移、临时视觉与正式模型替换接口。新增数值为开发默认值，未进行平衡调参。

## 本轮前状态

用户在开发期间确认变更：发电机增益槽允许超额产出，超额部分于下一个航行轮结算时消失；普通手牌仍按原轮末弃牌规则处理。

- 当前工作区已有大量未提交规则、UI与美术工作，本轮保留，不以HEAD作为干净基线。重点源文件副本位于根目录 `.planning/combat-equipment-v1-before/`。
- 历史 `tests/content.test.mjs` 仍要求Godot与旧实验完全相等，已不能表达此前免费安装/包扎包/矛架/修补配方修订。本轮更新为明确修订与原数值保护测试；新设备引用纳入检查。
- `python tools/check_supplied_assets.py` 初次运行发现 `ui.settlement` 的源码hash已漂移，发生于本轮修改该文件之前。后续资产维护需依据实际当前文件更新登记，不能声称初始资产检查通过。

## 已执行检查

- 新规则开发先运行失败测试，然后实现。`tests/test_battle_actions.gd`、`tests/test_new_equipment.gd` 已通过；其早期夹具错误（资源未提供、阶段错误、持有可变引用）已更正，没有为错误测试修改规则。
- `node --test tests/content.test.mjs`：包含困难标记保护断言的9项全部通过。
- 主代理实际运行并通过：`test_flow`、`test_save`、`test_mechanics`、`test_auto_progress`、`test_medkit_spear`、`test_catalog`、`test_routes`。包扎包/矛架测试的独立下一场战斗夹具恢复完好筏格，避免与新啃筏行为冲突；旧固定攻击测试改调用`battle_action`，原伤害/AP断言保持。
- 新增 `test_combat_integration.gd` 先确认两个真实失败：溢出增益存档被旧容量校验拒绝、已迁移遗迹二次存档失败。修复后主代理规则审查子代理及修复子代理均运行通过。另覆盖塑料只延续一次、绳索减伤保留、2/3奖励、JSON恢复后的相同随机序列，以及受损发电机清理到期溢出。
- 剧情首次回归完成四条15站路线，但JSON文本一致性失败；最小复现确认新增计数器被`int`转换而使1.0变1。恢复改为只补缺失字段，不弱化旧断言；最终 `test_story.gd` 复测PASS，四条15站路线及逐阶段存档全部通过。
- 独立核心规格审查：PASS。已撤回“实现前v5”误报，本轮前源码副本版本为v4；只接受已知旧版本与精确指纹组合。
- 独立核心代码质量审查：READY，无可复现P1/P2。发现一项测试夹具仍把发电机放在之前被啃坏的格上；主代理恢复独立夹具完好状态后 `test_battle_actions.gd` 再运行PASS，未改变设备停用规则。

## UI、资产与审查

- `test_battle_equipment_ui.gd`：主代理实际运行PASS，覆盖准确资源/增益UID、预览/取消不变、发电机燃料/领取/生产目标、合成分页、有效容量、模型AssetId与缺模型回退，以及密集布局两尺寸边界。
- 主代理实际运行PASS：`test_ui_layout_controls.gd`、`test_raft_interactions.gd`、`test_hand_fan.gd`、`test_hand_click.gd`。
- 独立UI规格审查：PASS。代码质量审查发现旧卡牌预览的`play_args`可残留到新资源行动，已修复并新增真实控件回归：屏障→箭矢预览→木头→格挡，确认保留箭矢、消耗正确资源和增益。随后又覆盖同一资源组合由攻击切换为格挡，确认预览与确认行动都使用最新选择；`test_battle_equipment_ui.gd` 复测 PASS。
- `flow_ui_smoke.gd` 的历史全流程脚本在首页查找旧名称“继续游戏”即发生空引用，未进入本轮战斗部分；主代理立即停止该测试进程，未将该烟测计为通过。首页已改版而脚本尚未跟进，当前新增功能由独立控件测试覆盖。
- 更新11项当前Godot源码绑定hash，保留所有图片/模型登记；`python tools/check_supplied_assets.py` 实际PASS：158个hash绑定，20张原图与原海面GLB校验通过。用户并发模型任务已登记的新设备AssetId被原样保留，不把文件完整性检查当作新模型美术验收。

## GPU验收：交由用户执行

首次截图脚本误以`--headless`启动，等待`RenderingServer.frame_post_draw`超过60秒，已停止并清理自建测试进程。遵照用户“超时后交本人执行”的约定，未重试GPU命令。修正脚本后仅做语法检查：现在明确拒绝headless、增加30秒总看门狗，使用帧等待截图，修正物理/逻辑坐标比较和合法设备夹具。没有把旧截图或其他模型任务截图当作本轮UI视觉证据。

在上层 `yongxian` 目录由用户运行：

```powershell
.\deep-surge-godot\verify-battle-equipment.ps1
```

或在本Godot项目目录运行：

```powershell
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/battle_equipment_visual.gd
```

预期输出：`BATTLE EQUIPMENT VISUAL: PASS`，并生成 `battle-equipment-1280.png`、`battle-equipment-1600.png`、`battle-equipment-generator.png` 于本目录。当前这些截图尚未验收。辅助PowerShell脚本仅做静态语法检查，未实际启动。

开发功能、规则/控件验收与图形验收分开记录。新数值尚未平衡；新增3D资源由用户独立模型工作流交付，缺失资源的临时回退不作为成品模型。
