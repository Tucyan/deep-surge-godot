# 潮汐遗物命名统一验证

日期：2026-10-19。用户确定系统名称为“潮汐遗物”。工作分支 `codex/origins-v1`，仍为未提交的v26内容。

## 修改范围

- 当前游戏中的“藏品／收藏品”文案统一为“潮汐遗物”：航行入口、持有面板、图鉴分类、商店说明、运行日志、错误提示和内容描述。
- 主界面入口加宽，容纳更长名称及持有数量。
- README与当前专题/契约同步；历史归档、既有验证记录、实施计划及外部游戏参考保留当时名称。
- 英文ID、命令、状态字段、文件路径和效果数值保持原定义。物品自身名称未改；描述变化会更新内容指纹，因此重新生成当前路线。

## 已执行检查

- 对 core/pages/presentation/application/adapters/content 的运行脚本及JSON、docs顶层当前文档及README扫描：旧系统名称零残留。
- Node内容检查18项通过。
- Godot collectible_ui、formal_shop、collectible_integration、collectible_effects 共4项通过；clean_ui布局检查通过。
- 文档检查：44份入口/专题、9份当前契约、0错误；文档 unittest 8项通过。
- 本机RTX4060 / OpenGL Compatibility实际运行遗物页面与交易确认框检查通过，并查看截图确认新标题完整显示。截图保存在 `.planning/collectibles/ui/`。

七条公开路线已按新指纹重新生成且逐条重放通过；公开Agent购买、丢弃专项144步重放通过。最后以 `validate_collectibles.py routes` 执行整组门禁时触及30秒超时，已停止且未重试，不能将本次整组门禁报告为通过。按用户约定，提供 `tools/verify_routes_manual.ps1` 交用户手动执行；该脚本使用隔离APPDATA/LOCALAPPDATA且不设置代理运行时限，本轮未执行该脚本。

手机触摸及发行导出未新增验证。改动未提交或推送。
