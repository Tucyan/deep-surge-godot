# 剧情模式结算奖励恢复验证

日期：2026-10-18（Asia/Singapore）。引擎：本机 Godot 4.7.2 console，全部使用 `--headless`。

## 修复

- `core/run_rewards.gd` 为剧情模式的玩法 `run_id` 记录实际已发奖励。领取凭据与积分一起写入共享 profile，配对剧情槽位也携带凭据。
- 共享 profile 成功而槽位失败：加载旧槽位再次结束时不重复增加涌潮点。
- 槽位成功而共享 profile 失败：加载终局槽位只恢复当前航程缺失的奖励，不回滚共享消费、购买或其他航程的领取记录。
- 手动保存同时重试槽位和共享 profile，任一失败保留错误；共享存储检查 flush 后的 I/O 错误。
- 同内容版本下无凭据旧档兼容；历史终局档不追溯补发，避免把已到账的旧奖励再次发放。未改变挑战/教程的原有发点方式。

## 红绿验证

新增 `tests/test_reward_recovery.gd`，通过目录占用目标 `.tmp` 注入真实文件写入失败。

1. 实现前：74 checks，12 failures。剧情坏结局/主动放弃 × 槽位失败/共享文件失败，均复现重复或丢失奖励。
2. 增加保存重试与旧档校验后：99 checks，2 failures，定位手动保存遗漏共享 profile 重试。
3. 最终：99 checks，0 failures，退出码 0；独立代码审查也在另一隔离目录运行该脚本，结果一致，未发现可确认的新增缺陷。

检查还覆盖磁盘 profile 重新恢复、复制结算前槽位、积分消费后的重复读取、购买保留、凭据 JSON 往返、旧档兼容、损坏凭据原子拒绝及仅恢复当前航程记录。

## 原有回归

| 脚本 | 本轮结果 |
| --- | --- |
| `test_chapter1_import.gd` | 119 checks，0 failures |
| `test_chapter1_saves.gd` | 15 checks，0 failures |
| `test_narrative.gd` | 53 checks，0 failures |
| `test_narrative_repairs.gd` | 27 checks，0 failures |
| `test_narrative_flow.gd` | 19 checks，0 failures |
| `test_recall_restore.gd` | 9 checks，0 failures |
| `test_save.gd` | SAVE / RECOVERY: PASS |
| `test_settlement.gd` | SETTLEMENT: PASS |
| `test_settlement_integration.gd` | SETTLEMENT INTEGRATION: PASS |
| `test_tutorial.gd` | TUTORIAL: PASS |

以上脚本退出码均为 0。新增测试和原有带计数测试共 341 项检查；其他四份脚本只报告 PASS，不计入该项数。改动文件执行 `git -c core.whitespace=cr-at-eol diff --check` 通过；该配置兼容工程已有 CRLF。

APPDATA 隔离在根 `tmp/reward-fix-*` 与独立审查 `tmp/reward-review-appdata` 下，未访问真实玩家存档。已有未提交修改保留，修改前涉及文件另备份在根 `tmp/reward-fix-before-20261018-232127`。

此次无 UI 布局改动，未做 GPU 视觉验收、导出或发布。两文件都未成功写入后强制退出的最新内存进度无法恢复；无凭据历史档已经发生的奖励差异也无法自动追溯。
