# 2026-10-19 发布验证

发布标签：`v0.2.0-20261019`，来源分支：`codex/origins-v1`，内容版本：`godot-flow-v02-26`。本次使用本机 Godot 4.7.2 重新导出，不安装依赖。测试 APPDATA/LOCALAPPDATA 均隔离于 `.planning/` 或忽略的 `builds/release-20261019/`，不访问玩家存档。

## 本次执行

- `python tools/check_docs.py`：44 个入口/专题文件、9 个当前文档，0 错误；文档检查单元测试 8/8。
- Node 内容测试 18/18；真实 Agent stdio 测试 3/3。
- `tools/validate_collectibles.py` 显式选择的 43 项中，42 项无头通过，`paper_grain` 因需要图形渲染拒绝无头运行；随后以真实 GPU 单独执行 `test_paper_grain.gd`，PASS。其余覆盖遗物效果、战斗、商店、配对保存、奖励恢复、回廊、获取动画、挑战继续及保存失败。
- `test_routes.gd -- --route <id>` 分别实际重放七条当前必需路线，7/7 通过，未使用 stale 路线替代。
- `test_archived_target_nodes.gd`：0 failures。
- GPU：`test_acquisition_ui.gd` PASS；`test_challenge_save_ui.gd` 8 checks、0 failures；纸纹 GPU 测试 PASS。设备为 NVIDIA GeForce RTX 4060 Laptop GPU。
- 资产首次检查发现 18 个既有界面脚本的登记 SHA256 过期；仅同步这些登记值，不修改对应源文件。重新执行 `python tools/check_supplied_assets.py`：270 个 hash 绑定通过。
- Windows `--export-release 'Windows Desktop'` 退出 0；成品在自身目录执行 `--quit-after 120`，GPU 初始化并退出 0，日志无脚本错误。初次附带 `--path` 的尝试被发行模板拒绝，改用成品直接启动后通过。
- Android `--export-debug 'Android APK'` 退出 0；apksigner v2/v3 验签、ZIP 全包 CRC、必需 JSON 解析和源目录排除检查通过。aapt2 确认包名 `com.tucyan.deepsurge`、名称“深潮”、版本 0.2/code 2、最低 API 24、目标 API 36、ARM64/ARMv7。

## 产物

产物与本次原始导出/路线/成品启动日志位于忽略的 `builds/release-20261019/`，产物另上传 GitHub Release。

| 文件 | 字节 | SHA256 |
|---|---:|---|
| DeepSurge.exe | 256674240 | `6e062f54e9a1e24ee1798395e1a212464c52b28332d07711f6fc152df2e94e9e` |
| DeepSurge-v0.2-android-debug.apk | 204492178 | `c7d94420fd1c430bd3e33863b7a14350838bcb8b32bcd1dcc74154b23ef56619` |

## 限制

Android 仍使用调试签名，未进行本次真机安装或触摸验收。aapt2 保留模板既有 `themed_icon.xml` 引用缺失警告；不将签名通过表述为已验证所有设备图标显示。旧版 aapt 解析同一 APK 的 `android:required` 属性报错，改用 aapt2 后元数据读取退出 0。Windows 启动检查不代表完整人工游玩验收。当前不兼容旧内容版本存档，拒绝而不迁移。
