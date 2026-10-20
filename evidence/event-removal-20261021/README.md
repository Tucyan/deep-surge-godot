# 绞盘与吊架退池验证

日期：2026-10-21；分支：`codex/integrate-v03-relics`。

- 搁浅的绞盘 `winch` 标记 retired，5 个池中的 entry 全部移除；浪中的吊架 `storm/surface` 原本已 retired 且不在池中，继续保持不投放。
- JSON 静态检查：两者 retired 且所有池无对应 entry，通过。
- `python tools/check_docs.py`：46 个入口/专题、12 个当前文档，0 错误。
- 隔离 APPDATA/LOCALAPPDATA 执行 `test_catalog.gd`、`test_v03_encounters.gd`、`test_navigation_partial_refresh.gd`，均 PASS；导航测试退出有 8 个 ObjectDB 与 4 个资源未释放提示，未处理。
- 实际 Agent：challenge / standard / seed 22，57 步到达终局，第 6 航次因生存消耗死亡；并非全层通关验收。结果与轨迹见本目录，不覆盖旧路线夹具。
- GPU、触控、发行导出及全套路线未执行；5 个新藏品节点和次数调整未实施。
