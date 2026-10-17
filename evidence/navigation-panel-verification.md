# 导航面板布局验证

2026-10-17。按照用户第二张截图蓝框调整右侧共享区域；导航操作区说明置顶、按钮组置底。1600×900、100% UI 的面板边界为 (1248,108)，大小 328×476。无规则、存档或随机流更改，无资产更新。

执行并通过：

```powershell
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/verify_navigation_panel.gd
```

GPU：OpenGL Compatibility / NVIDIA RTX 4060 Laptop。输出 `NAVIGATION PANEL: PASS`。覆盖 1600×900、1280×720、1920×820，各 100%/125% UI；检查面板与按钮在视口内、按钮距面板底边18逻辑像素、面板避开手牌顶栏、布局不修改状态/RNG，原生按钮信号仍能出发进入准备阶段。直接实例化 flow_app，绕过首启序章和用户存档。

已查看 [1600×900 截图](navigation-panel-1600x900-100.png)，标题与说明在上方，三个目的地按钮在底部。

本次未执行完整规则路线重放，也未验证移动端或导出构建。事件区域同步相同锚点范围；剧情多选项压力测试未运行。
