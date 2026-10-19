# 架构收敛验证 · 2026-10-19

本次按用户指定的 **5 → 4 → 3 → 1 → 2** 顺序实施。基于现有未提交工作区，不回退已有出身、奖励补偿或存储修复。当前工程为 Godot 4.7.2；旧档兼容/迁移明确不在本次范围。

## 最终变化

| 项目 | 变化 |
|---|---|
| 5：当前工程 | 根 README 与 AGENTS 明确 Godot 为当前工程；Three.js/Unity 约定标为历史范围；独立仓库边界保留 |
| 4：应用层 | 原 `flow_app.gd` 1046 行拆为入口 570 行及 application 的页面宿主、剧情协调、存储协调、HUD 投影；保留调用方接口，状态由对应对象持有 |
| 4：不必要工作 | 普通 HUD 只读剧情档存在标记，元数据列表缓存到写入/挂载后失效；进入选档菜单显式刷新。保留签名排除非显示历史，战斗保留当前遭遇日志 |
| 3：路线门禁 | 七条当前版本必需路线，按内容指纹和真实重放验证；历史轨迹单列 stale，零执行、缺失身份、重复身份、指纹不符均失败 |
| 1：模式事务 | SessionCoordinator 先在候选中验证；玩法与剧情会话成功后一起替换。候选沿用当前 revision，错误请求不影响原会话、待选档或绑定 |
| 2：动作目录 | 加入普通 dismantle，覆盖完好和破损的在位设备；仍由真实 dispatch 校验。Agent 与 UI 同规则结算 |

规则内容版本仍为 `godot-flow-v02-25`，快照 schema 和随机算法未改变。本次没有修改内容 JSON 或引入新工具链。

## 先失败、再通过的证据

- 应用边界测试首次 15 项中 3 项失败：HUD 读档、列表缓存和历史签名。随后 15/15 通过；补充“战斗可见日志必须刷新”先失败再通过，最终无头 16/16。
- 旧路线脚本首次输出 `PASS (stale traces skipped: 13)`，实际没有执行路线。新增覆盖门禁测试先因缺少实现失败；实现后通过全部六个覆盖场景，真实路线最终 `executed=7, stale=13, failed=0`。
- 模式原回归 7 项中 1 项失败；扩展为出身/种子/资源/revision、会话身份和成功提交检查后 25 项中 7 项失败；修复后 25/25。
- 拆除动作回归先出现 2 个预期失败（普通和破损设备未枚举），补齐后 15/15，包含公开制造/安装/拆除、过期 revision、AP、材料、随机一致性和重放。

## 当次验证

测试进程的 APPDATA、LOCALAPPDATA 均指向根 `.planning/architecture-improvements-20261019/` 下的隔离目录。使用本机 Godot console；规则脚本每进程限45秒，无超时和下载。

### Godot 无头：22 个脚本均退出0，无脚本错误

```text
test_session                    test_save
test_action_query               test_action_catalogue
test_agent_session              test_mode_contract
test_application_boundaries     test_route_coverage
test_routes                     test_interaction_refresh
test_navigation_partial_refresh test_narrative
test_narrative_flow              test_narrative_repairs
test_reward_recovery            test_recall_restore
test_loading_transition         test_tutorial
test_tutorial_rules_repairs      test_tutorial_enchantment
test_origins_v2                  test_settlement_integration
```

单项命令（在 Godot 工程目录，先配置隔离环境变量）：

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_application_boundaries.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_mode_contract.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_action_catalogue.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_routes.gd
```

其中剧情纯层 53/53、剧情集成 19/19、剧情修复 27/27、奖励恢复 99/99、回廊 9/9；模式契约 25/25、动作目录 15/15、应用边界 16/16。

### 当前版本路线

通过 `python tools/generate_regression_routes.py` 使用真实公开 Agent 操作生成，所有轨迹跨 JSON 序列化后重放通过；旧证据未覆盖或迁移。策略来自现有 SmartPlayer，失败场景刻意不恢复生存属性。

| 路线 | 终局 | 完成节点 | 真实动作数 |
|---|---|---:|---:|
| standard-challenge | survived | 12 | 180 |
| standard-story | survived | 11 | 169 |
| hard-challenge | dead | 11 | 208 |
| hard-story | dead | 10 | 188 |
| nightmare-challenge | dead | 11 | 228 |
| nightmare-story | dead | 10 | 191 |
| standard-failure | mad | 7 | 56 |

最终 gate：`ROUTES: PASS (executed=7, stale=13, failed=0)`，在补齐动作目录后再次通过。每条路线还验证物资守恒、完整终局报告和同版本终局快照恢复。以上是规则回归样例，不是难度平衡、最优策略或所有组合均可通关的结论。

### GPU 与协议/内容

RTX 4060 Laptop / OpenGL Compatibility，真实绘制模式：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_partial_refresh.gd
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_application_boundaries.gd
node --test tests/content.test.mjs tests/node_content.test.mjs
python -m unittest discover -s tests -p test_agent_stdio.py -v
```

- `test_partial_refresh`：PASS，验证真实按钮回调与 HUD/手牌/木筏实例保留、设置局部更新。
- `test_application_boundaries`：17 项、0 失败。首次 GPU 运行断言通过，但退出有7个 ObjectDB 实例未释放警告；verbose 诊断与生命周期复核指向尚未完成的逐帧预热。测试增加最多120帧的明确预热完成等待后，最终复跑无该警告。没有据此宣称生产代码内存泄漏。
- Node 两份内容测试：15/15 通过。
- Python 真实进程 Agent 协议：3/3 通过。

### 复核与文档

- 独立只读代码复核按任务前文件快照比较，未发现阻断问题；复核指出的 GPU 测试退出生命周期问题已收尾。
- 根 README 新链接已检查；修改文件的空白检查通过。
- 本地详细日志及任务前快照在根 `.planning/architecture-improvements-20261019/`；该目录被 Git 忽略。未自动提交、推送、合并仓库或清理用户文件。

## 验证范围

没有运行整个历史测试目录，没有做 Android/Windows 发行导出、真实触摸或全分辨率视觉验收。本次未量化当前平台帧耗时改善；加载遮罩和整页重建回退仍存在，不宣称所有交互停顿已消失。
