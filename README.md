# Deep Surge · 深潮（Godot）
<!-- doc-status: current; doc-role: entry; content-version: godot-flow-v03-02; reviewed: 2026-10-20 -->

当前整合分支为 `codex/integrate-v03-relics`，保留原工作树。内容为三层挑战、20件新藏品、10个寻物节点和局部刷新/手机界面；当次验收见[整合记录](evidence/safe-integration-20261020.md)。

当前开发工程使用 Godot 4.7.2 / GDScript / Compatibility。文档入口：[分类索引](docs/README.md) · [当前机制](docs/current-game-mechanics.md) · [应用架构](docs/application-architecture.md)。

## 启动

双击 `启动游戏.cmd` 或执行 `./launch.ps1`；编辑器导入 [project.godot](project.godot)，主场景为 [main.tscn](scenes/main.tscn)。`./launch.ps1 -Editor` 打开编辑器。本工程不要求下载新依赖；修改脚本后重新启动旧运行窗口。

## 模式与流程

| 模式/入口 | 当前行为 |
|---|---|
| 新手教程 | 手动选齐教学起手资源后开始，固定3次航行、35步；独立记录教程完成状态 |
| 挑战模式 | 选择难度、出身、种子与起手；三层25次航行（5/10/10，含各层Boss），Ⅲ结算存活才通关；不提供剧情档操作 |
| 剧情模式（暂停） | 首页、选档、相关设置与帮助默认隐藏；保留原11节点代码及配对保存，不恢复开发 |
| 回溯潮涌 | 五幕开局序章及原本地旧归档只读回放；新独立剧情档已读场景暂未接入 |

常规循环：导航选择 → 出发 → 准备 → 节点文字/选项/商店/战斗 → 结果 → 收尾 → 老化与容量整理 → 食水结算 → 下一轮生产、涌泉与导航，或终局。

AP、候选、战斗和设备的详细数值以 [当前机制](docs/current-game-mechanics.md) 和相应专题为准。提案与历史演示不作为现行规则。

挑战基础食水航耗按层为20/30/40（试测），SAN保持15，愚者为10。挑战饥饿/缺水独立累计递增伤害，默认每项上限5；剧情与教程仍各1、合计最多2。细节见[配置与三层契约](docs/v03-configuration.md)。

## 保存与当前边界

- 当前格式为 schema 2，内容 `godot-flow-v03-02`，随机算法 `xorshift32-godot-v1`；旧版本兼容/迁移不在范围，不兼容时明确拒绝并保留原文件。
- `user://godot-flow-v02.json` 原子保存共享 profile/最近结算及单个当前教程或挑战局；异常退出后可从最后一次成功保存的完整操作继续，重启先进入首页。
- 剧情槽位 `user://narrative/<id>.json` 同时包含叙事状态和配对 gameplay 快照，必须从剧情模式明确加载；活动指针不代表启动时自动挂载。
- 教程完成、难度解锁等在独立 `user://deep-surge-meta.json`。保存失败应显示错误，不能冒充保存成功。
- 保存失败提供重试，未保存时阻止继续改变规则或替换航程；正常退出失败可选择返回或放弃未保存操作。新建/切入剧情会确认替换当前单档进度，候选保存成功才替换内存。拒绝的原档经明确新建会另存原始字节；不承诺物理断电可靠性。
- 旧夜间/委托规则已移除；挑战现有三层，剧情仍为单层11航次；正式商店已提供20种新定义中的三种潮汐遗物，支持持有查看、丢弃及组合效果，见[潮汐遗物契约](docs/collectible-effects.md)。剧情坏结局可请求当前航程终局，但不提供玩法数值增益。

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

0.3专项入口：`tests/test_v03_campaign.gd`、`test_v03_survival.gd`、`test_v03_journey_flow.gd`、`test_v03_encounters.gd`、`test_v03_weather.gd`、`test_v03_projection.gd`。实施代码已接入，当前验收进度见[0.3验证草稿](evidence/v03-development-verification.md)；路线已完成，图形、真机触摸和发行导出按记录分别核对。

实际运行范围和限制查 [验证索引](evidence/README.md)，不把列出的命令当作已经执行。GPU、真实触摸与发行导出单独验收。

## 开发导航与历史

- [Agent 协议与真实路线](docs/agent-interface.md)：独立无窗口会话，不读取玩家保存。
- [资产登记](assets/README.md)：稳定 AssetId、运行映射、源包与 hash；源包在 `asset-sources/`，运行时不引用个人下载目录。
- [文档维护规则](docs/documentation-governance.md)：当前契约、专题、计划、证据和历史的边界。
- 本工程保留独立 Git 仓库；根仓库与 Three.js/Unity 历史工程不合并。
- 此前按日期追加的说明完整保存在 [上下文归档](docs/archive/context-20261019/README.md)，用于追溯，不覆盖当前入口。
