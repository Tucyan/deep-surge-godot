# 独立剧情页无图片界面验证

日期：2026-10-17。仅修改独立 story_page，不接入或改动主游戏剧情规则。

- 移除 AssetCatalog、Widgets 依赖和全部 TextureRect；使用纯色矩形、系统字体及 Godot 原生按钮。
- 历史图片保留，ui.story.layout v2 的 dependencies 为空，同步脚本 SHA256。
- `Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/story_page_visual.gd`：PASS，0 failures。1600×900 / 1280×720；验证无图片控件、对白推进、选项、LOG 模态/翻页、结束状态及长文本。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_story_player.gd`：31 checks，0 failures。
- 截图：story-page-choices-1600.png、story-page-log-1600.png 和其他 story-page-* 页面截图为本次重新生成。

布局修订：移除底部操作提示，LOG 与继续按钮同在 y=832、按钮高度58。GPU 页面验证首次运行输入检查失败并中止；重跑 PASS，0 failures，截图已刷新。

2026-10-17：SKIP 底板移除。GPU 验证首次 LOG/分支输入检查失败，重跑 PASS，0 failures；截图刷新。

2026-10-17 LOG 滚动修订：移除分页控件与页码，ScrollContainer 显示全部记录，旧记录在上、最新在下；容器完成排版后滚至底部，每次重开重定位。固定21号字体，不再因日志长度缩字。GPU：PASS，0 failures；覆盖20条长记录溢出、时间顺序、默认底部、向上滚动不推进及重开回底部；剧情数据测试31 checks，0 failures。新增 story-page-log-scroll-1280.png 为长记录测试截图。原无 TextureRect 断言调整为不引用 res:// 图片资产（Godot 滚动控件内部会创建无外部图片的 TextureRect）。
