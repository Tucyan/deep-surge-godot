# 独立剧情页面接口 v1

2026-10-14。数据定义见[数据结构](story-data.md)。独立入口 `scenes/story_demo.tscn`；当前 `main.tscn`、`flow_app.gd`、首页和原有剧情流程均不调用此页面。

## 纯数据会话：story/story_player.gd

| 方法 / 信号 | 行为 |
| --- | --- |
| load_story(data:Variant) -> Dictionary | 完整验证成功后重置并进入 entry；失败保持原状态 |
| get_view() -> Dictionary | 返回当前 StoryView 深拷贝 |
| get_log() -> Array | 返回已进入节点日志深拷贝 |
| advance() -> Dictionary | 无选择时走 next；终点变 completed；有选择、idle 或 completed 时拒绝 |
| choose(choice_id:String) -> Dictionary | 仅接受当前选择 ID，登记选择再进入目标；无效 ID 不修改状态 |
| skip() -> Dictionary | 连续走无选择节点，遇选择停下；终点完成；重复点选择处的 SKIP 不新增日志 |
| completed(result:Dictionary) | 每次成功加载后的播放最多发一次 StoryResult |

所有命令返回 `{ok:true}` 或 `{ok:false,error:String}`。错误是内容/当前状态错误，不执行玩法命令。不调用随机数，不消耗任何游戏属性。当前内容有向无环，不能跳回旧节点。

## 页面：pages/story_page.gd

| 方法 / 配置 / 信号 | 行为 |
| --- | --- |
| load_story(data:Variant) -> Dictionary | 调用会话验证；成功刷新页面和关闭 LOG。可 add_child 前加载，ready 时显示 |
| advance() -> void | 打字时先显全文；全文时才推进；LOG 打开时无动作 |
| choose(id:String) -> void | 全文已显示且 LOG 关闭时选择；选项随全文出现，不能双击跨分支 |
| skip() -> void | 走会话 SKIP，显示停止处全文和选项；LOG 打开时无动作 |
| open_log() / close_log() -> void | 分页回看 / 返回原位置；不修改会话游标、选项或日志 |
| characters_per_second:float | 默认 32；页面打字速度，单位字符/秒 |
| story_completed(result:Dictionary) | 转发独立 StoryResult；宿主未来自行决定后续路由 |

当前布局按 1600×900 等比缩放，已验证 1280×720。正文下方“继续”，右上 SKIP，文字框右上最多三项选择，左侧文字说明；LOG 两条/页、上一页/下一页、关闭，无滚动条。LOG 打开暂停打字和页面推进、遮挡鼠标，并取消底层按钮键盘焦点。Enter/Space 推进；L 打开/关闭 LOG；Esc 关闭 LOG；Tab 和方向键沿用 Godot 按钮焦点行为，Enter 激活焦点按钮。

```gdscript
var page = load("res://pages/story_page.gd").new()
add_child(page)
page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
page.story_completed.connect(func(result): print(result))
var data = JSON.parse_string(FileAccess.get_file_as_string("res://story/demo_story.json"))
var response = page.load_story(data)
if not response.ok:
    push_error(response.error)
```

## 独立启动与验证

在工程目录执行：

```powershell
./launch-story.ps1          # 可交互 Demo，不运行主程序
./launch-story.ps1 -Verify  # 数据测试 + GPU 页面测试，自动退出
```

或者 Godot 编辑器打开 `scenes/story_demo.tscn`，按 **F6**，不要按 F5（F5 仍运行现有主程序）。不修改 `project.godot` 的 main_scene。

测试入口：`tests/test_story_player.gd`，无头验证分支/边界/日志；`tests/story_page_visual.gd`，GPU 通过 viewport 鼠标输入验证按钮、LOG 模态、翻页、最大字数/三选项及两分辨率截图；`tests/story_demo.gd` 为交互入口脚本。结果见[当次验证记录](../evidence/story-page-verification.md)。

## 素材与维护

内置 imagegen 生成三种无文字透明框，运行目录 `assets/story_ui/`，原图、提示词和清单位于 `asset-sources/story-ui-v1/`。`tools/register_story_ui.py` 按固定矩形裁切并保留原 RGBA，登记尺寸、SHA256、裁切区域、AssetId 和源码布局依赖到 `assets/manifest.json`。素材通过现有 AssetCatalog 缓存复用；首页背景依赖 `texture.title.ocean-poster`，不烘焙对白。Label/按钮/模态纸面属于程序化表现资产，登记为 `ui.story.layout`。运行对象随页面释放，不进剧情状态。

当前没有语音、角色立绘、动态背景切换、自动播放、剧情存档恢复或玩法奖励绑定；LOG 是文本回看，不倒退执行分支。
