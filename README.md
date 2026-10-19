# Deep Surge · 深潮（Godot）
<!-- doc-status: current; doc-role: entry; content-version: godot-flow-v02-25; reviewed: 2026-10-19 -->

当前开发工程使用 Godot 4.7.2 / GDScript / Compatibility。文档入口：[分类索引](docs/README.md) · [当前机制](docs/current-game-mechanics.md) · [应用架构](docs/application-architecture.md)。

## 启动

双击 `启动游戏.cmd` 或执行 `./launch.ps1`；编辑器导入 [project.godot](project.godot)，主场景为 [main.tscn](scenes/main.tscn)。`./launch.ps1 -Editor` 打开编辑器。本工程不要求下载新依赖；修改脚本后重新启动旧运行窗口。

## 模式与流程

| 模式/入口 | 当前行为 |
|---|---|
| 新手教程 | 手动选齐教学起手资源后开始，固定3次航行、35步；独立记录教程完成状态 |
| 挑战模式 | 选择难度、出身、种子与起手；10～15次航行，末站 Boss；不提供剧情档操作 |
| 剧情模式 | 先新建或读取配对剧情档；第一章11个节点，导航前播放章节剧情，其余玩法复用挑战规则 |
| 回溯潮涌 | 五幕开局序章及原本地旧归档只读回放；新独立剧情档已读场景暂未接入 |

常规循环：导航选择 → 出发 → 准备 → 节点文字/选项/商店/战斗 → 结果 → 收尾 → 老化与容量整理 → 食水结算 → 下一轮生产、涌泉与导航，或终局。

AP、候选、战斗和设备的详细数值以 [当前机制](docs/current-game-mechanics.md) 和相应专题为准。提案与历史演示不作为现行规则。

## 保存与当前边界

- 当前格式为 schema 2，内容 `godot-flow-v02-25`，随机算法 `xorshift32-godot-v1`；旧版本兼容/迁移不在范围，不兼容时明确拒绝并保留原文件。
- `user://godot-flow-v02.json` 保存共享 profile/最近结算，并保存教程局状态；挑战局可在当前进程返回继续，但没有跨进程恢复承诺。
- 剧情槽位 `user://narrative/<id>.json` 同时包含叙事状态和配对 gameplay 快照，必须从剧情模式明确加载；活动指针不代表启动时自动挂载。
- 教程完成、难度解锁等在独立 `user://deep-surge-meta.json`。保存失败应显示错误，不能冒充保存成功。
- 旧夜间/委托规则已移除；当前没有第二层或完整藏品系统。剧情坏结局可请求当前航程终局，但不提供玩法数值增益。

配对校验、奖励领取凭据和失败恢复见 [剧情与保存契约](docs/narrative-and-save.md)。

## 验证入口

在本目录执行。Godot 测试先设置隔离 APPDATA/LOCALAPPDATA，避免接触玩家实际数据。

```powershell
python tools/check_docs.py
python -m unittest discover -s tests -p test_check_docs.py -v
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_session.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_routes.gd
node --test tests/content.test.mjs tests/node_content.test.mjs
python -m unittest discover -s tests -p test_agent_stdio.py -v
```

真实图形局部刷新检查：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_partial_refresh.gd
```

实际运行范围和限制查 [验证索引](evidence/README.md)，不把列出的命令当作已经执行。GPU、真实触摸与发行导出单独验收。

## 开发导航与历史

- [Agent 协议与真实路线](docs/agent-interface.md)：独立无窗口会话，不读取玩家保存。
- [资产登记](assets/README.md)：稳定 AssetId、运行映射、源包与 hash；源包在 `asset-sources/`，运行时不引用个人下载目录。
- [文档维护规则](docs/documentation-governance.md)：当前契约、专题、计划、证据和历史的边界。
- 本工程保留独立 Git 仓库；根仓库与 Three.js/Unity 历史工程不合并。
- 此前按日期追加的说明完整保存在 [上下文归档](docs/archive/context-20261019/README.md)，用于追溯，不覆盖当前入口。
