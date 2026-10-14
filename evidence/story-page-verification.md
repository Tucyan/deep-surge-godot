# 独立剧情页面验证 · 2026-10-14

环境：Godot 4.7.2 stable，Windows，OpenGL Compatibility，NVIDIA RTX 4060 Laptop GPU。

当次运行 `./launch-story.ps1 -Verify` 退出码 0：

```text
STORY PLAYER: 31 checks, 0 failures
STORY PAGE GPU: PASS, failures=0
```

状态验证：加载/重置、深拷贝、非法命令不修改状态、两条分支、选择日志、跳过选择屏障、终点信号一次、重复推进拒绝、坏 schema、空内容、重复 ID、悬空引用、环路、超长/多段文本拒绝。

GPU 验证采用 viewport 鼠标事件（非直接发 pressed 信号），覆盖继续先显全文、SKIP、LOG 打开/关闭/暂停、历史翻页不改变播放、实际选择、完成、素材不回退占位、1600×900 / 1280×720 按钮范围、复用页面、三选项和最大长度文本。无滚动条。

已实际查看截图：

- [对白 1600](story-page-dialogue-1600.png)
- [选项 1600](story-page-choices-1600.png)
- [LOG 1600](story-page-log-1600.png)
- [对白 1280](story-page-dialogue-1280.png)
- [结束 1280](story-page-completed-1280.png)
- [三选项 / 长文本 1280](story-page-three-choices-1280.png)
- [LOG 1280](story-page-log-1280.png)

检查发现并修复：日志复用横框造成装饰压字，改为原比例生成标题条+独立纸面；Godot Label 最小高度随长文扩张，改为用字体排版测量固定安全区域，再缩小字号；测试坐标适配 Window 最终缩放，等待初始窗口布局稳定。

既有剧情回归测试当次通过，退出码均为 0：

```text
STORY: PASS (15站学者A/B/C、独航、夜间与存档)
STORY EDGES: PASS (委托仅一次、夜间原子操作、危机零资源出口、移动死亡)
```

三张生成素材和布局源 hash 检查通过，AssetId 依赖存在。没有修改主程序启动入口或为此页面添加主路由；工作区原有未提交改动保留。仅验证本机编辑器/命令行运行，未验证独立导出构建、移动端或任意极端宽高比。没有存档恢复、语音或玩法奖励执行。

已通过 Godot MCP 启动独立 `scenes/story_demo.tscn` 供交互查看。调试输出没有运行错误；现有共享模块有两条命名遮蔽警告（`widgets.gd:95`、`asset_catalog.gd:10`），保留记录，没有把日志描述为完全无警告。文档相对链接、素材 hash 和主路由隔离检查通过。
