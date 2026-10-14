# 独立剧情页面实施计划

**目标：** 提供 Galgame 式剧情演示，不改 main.tscn、flow_app.gd 或主程序路由。
**架构：** JSON 内容 → 独立 RefCounted 会话 → Control 页面；资源与状态分离。选择只返回剧情分支，不执行玩法奖励。
**技术：** Godot 4 / GDScript / JSON / imagegen 透明 UI 图集。

- [x] 先写 tests/test_story_player.gd，检查缺失模块失败，再实现 story/story_player.gd。验证分支、SKIP 选择屏障、日志隔离、无效内容及完成信号。
- [x] 生图匹配首页黑白亮蓝风格，原图归档 asset-sources/story-ui-v1，裁切及 hash 单独登记；文字不烘焙到图片。
- [x] 实现 pages/story_page.gd：打字、旁白说明、底部文字框、右上 SKIP、文字框右上选项、LOG 分页回看并暂停推进。
- [x] 添加 scenes/story_demo.tscn、tests/story_demo.gd、launch-story.ps1，仅显式启动。
- [x] 添加 tests/story_page_visual.gd 实际 GPU 验证分支/日志/按钮、1600×900 和 1280×720 截图。
- [x] 分别记录 docs/story-data.md、docs/story-interface.md，文档写明接口、返回值、约束、测试命令和未接入玩法边界。
- [x] 运行模型与页面验证、既有故事测试，记录本次 evidence/story-page-verification.md。

用户已要求直接完成，按本计划在当前会话执行，不额外询问执行方式；不自动提交或推送。
