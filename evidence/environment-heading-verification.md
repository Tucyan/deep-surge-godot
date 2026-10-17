# 环境状态标题同行验证

日期：2026-10-17。

环境状态容器移入航行标题横排，接在航次与阶段文字之后；沿用原状态标签、颜色与悬停说明。无规则、存档或资产映射变化。

在当前工程执行：

```powershell
& 'C:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/environment_ui.gd
```

结果：退出码 0，`ENVIRONMENT UI: PASS`。使用 NVIDIA OpenGL 图形后端，验证 1600×900、1280×720 中环境标签数量、悬停说明、容器位于视口内，以及渲染和悬停不改变规则/RNG。更新截图 `environment-1600x900.png`、`environment-1280x720.png`；人工查看 1280×720 截图，环境名称与“第 1 / 12 次航行 航行导航”同行。
