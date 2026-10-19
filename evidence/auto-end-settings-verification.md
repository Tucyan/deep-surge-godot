# 自动结束航程设置与统一过渡验证

2026-10-19，Godot 4.7.2，Windows / OpenGL Compatibility / RTX 4060 Laptop GPU。所有运行使用独立 APPDATA / LOCALAPPDATA，主场景测试关闭 persistence；配置读写使用测试专用文件。

- `test_auto_end_settings.gd`：PASS（无头与 GPU）。默认开启，配置关闭后重载保持；设置控件立即同步会话，重建新局和重开设置仍关闭；关闭后等待手动结束，手动结束仍播放过渡。GPU `-- --capture` 保存首页和游戏内设置截图。
- `test_auto_progress.gd`：PASS。关闭自动航程结束仍可手动结算，不改变战斗自动回合；既有有效免费操作、设备、超限整理和探测无副作用回归通过。
- `test_voyage_transition.gd`：PASS（无头与 GPU）。手动结束、最后弃牌、使用最后一张有效恢复牌、确认节点结果触发自动结束均播放深色过渡；自动结算超限先停留弃牌，最后弃牌才换轮。动画期间重复命令被阻止，最终状态与一次真实 dispatch 一致，终局和非法命令无下一轮动画。
- `test_loading_transition.gd`、`test_display_settings.gd`：PASS。
- `test_narrative_flow.gd`：19 checks，0 failures。
- `test_routes.gd`：PASS，executed=7，stale=13，failed=0。7 条当前版本必需路线全部实际回放，13 条历史轨迹仅计数。
- `python tools/check_docs.py`：PASS，0 errors。

截图：`auto-end-settings.png`、`auto-end-settings-game.png`、`voyage-transition.png`。

本地开关存于配置，不改变玩法存档 schema 或内容版本。直接规则/Agent 新建会话默认保持自动结束；UI 应用本地偏好。未执行手机触摸或发行导出验证。
