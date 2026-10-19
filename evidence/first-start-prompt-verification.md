# 首次开始教学提示验证

2026-10-18，Godot 4.7.2，1280×720。

- `tests/test_first_start_prompt.gd`：先在缺少功能时失败，实现后 headless 与 OpenGL 运行均 PASS。覆盖首次询问、接受直达教学选牌、跳过说明、确认后模式选择、选择持久化、跳过不算完成、挑战难度重新进入教程。
- `tests/test_tutorial_setup.gd`、`tests/tutorial_start.gd`、`tests/test_tutorial.gd`、`tests/test_difficulty.gd`：PASS；前两个 UI 测试等待现有切换动画结束再检查开局。
- `tests/test_recall_restore.gd`：9 checks，0 failures。
- 图形证据：`first-start-tutorial-prompt.png`、`first-start-skip-notice.png`、`first-start-mode-choice.png`。使用测试独立 meta 路径，不改玩家进度。
- 图形测试退出存在 ObjectDB 实例泄漏警告，未宣称引擎日志无警告。

未提交或推送；不改规则内容版本和单局存档格式。局外 meta version 1 新增可选 `tutorial_prompt_handled`，旧文件默认 false；教程完成仍单独读取 `tutorial_done`。
