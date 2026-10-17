# 工作台材料选择与布局验证

日期：2026-10-17。当前工作区内容版本 `godot-flow-v02-20`，schema 2；本次未改变核心规则、存档、Agent 操作契约或资产映射。复用已有资源图和 Godot 原生控件，无新增外部资产。

## 改动

左侧大材料卡只显示图标与已选/持有数量；初始空选，单击投入一张。中央原料槽只显示图标，单击撤回其对应实例。去掉材料加减按钮、智能推荐和批次数量区域，界面按单批执行。快捷转化保留明确的立即执行文字。核心和 Agent 的既有合法操作边界保持。

中央标题“开始转化”；右上 X 左侧为圆圈问号，打开工作台操作说明。配方和转化的基准文字、按钮和图标尺寸增大。

## 已执行

Godot 4.7.2 Windows / OpenGL Compatibility / NVIDIA RTX 4060 Laptop GPU。

在工程目录执行：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_transmute_and_install_ap.gd -- --capture
Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_craft_grid.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_action_query.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_agent_session.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_routes.gd
node --test tests/content.test.mjs tests/node_content.test.mjs
python -m unittest discover -s tests -p test_agent_stdio.py -v
```

结果：上述入口均通过，内容检查 15 项、Agent stdio 3 项。完整路线覆盖标准/困难/噩梦挑战及剧情模式，记录中的失败航程是合法终局，测试整体通过。

专项 GPU 测试使用实际指针事件，验证空选禁用、零库存不能选择、比例更新、三个槽位满选、拒绝第四张、撤回特定 UID、空槽无操作、切换目标清空、帮助窗口、选择/帮助不改状态与 RNG，以及执行后扣 1 AP、产出 2 张、消耗实例不自动补料。1280×720 / 1600×900 / 1920×820，UI 100% 与 125% 的代表组合检查控件与图示槽位边界；配方页另外检查 1280×720 125% 和 1600×900 100%。不宣称已验证 Android 真机。

旧配方页测试原先要求第二页恰有五个子节点，与现有固定八格补位规则冲突；已改为八格并继续验证第五格为额外测试配方。窗口调整后增加等待布局稳定的帧数，实际点击合成与 AP 消耗验证通过。

## 截图

- [已选择三种材料](workbench-selected.png)
- [1280×720 / 125%](workbench-1280x720-125.png)
- [1600×900 / 100%](workbench-1600x900-100.png)
- [1920×820 / 125%](workbench-1920x820-125.png)
- [配方页 1280×720 / 125%](workbench-recipes-1280x720-125.png)
- [工作台说明](workbench-help.png)

`tests/verify_transmute_visual.gd` 的第二张图改为显式选三张木头，避免旧批次截图名称继续暗示页面存在批次控件。该单独截图脚本本轮未运行；本记录图片均来自专项 GPU 测试。


## 2026-10-17 连线及产物显示补充验证

本次专项 GPU 命令再次执行通过：`Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_transmute_and_install_ap.gd -- --capture`。新增断言检查顶部输入与产物之间有可见间隔、产物槽只有数量 `2` 一项文字，并保留原实际鼠标选择/撤回/执行及各分辨率边界测试。已查看更新后的 `workbench-selected.png` 和 `workbench-1280x720-125.png`：顶部绿色箭头可见，产物仅有图标与下方数量，1600×900 下操作区整体下移，紧凑窗口内控件保持可见。

当前 `scenes/main.tscn` 已接入 `game_bootstrap.gd` 开场流程；专项测试改为直接创建真实 `flow_app.gd` 并铺满视口，关闭持久化，避免进入开场流程及读取玩家存档。第一次旧入口运行因 bootstrap 没有 persistence 属性而失败，已停止该进程；适配后先确认新增布局断言失败，再实现并验证通过。本小改动未重新执行前文全套规则/路线命令，前文结果属于此前一轮验证。
