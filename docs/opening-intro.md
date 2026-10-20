# 首次进入的世界观序章

2026-10-17，表现层功能，内容与规则版本不变。

- `scenes/main.tscn` 进入 `presentation/game_bootstrap.gd`；读取显示偏好后，在原首页之前判断首次观看标记。启动根节点继承 `flow_app.gd`，播完后调用其初始化，保留原根节点的 session/persistence/handle_command 等接口；测试关闭 persistence 时不播首进入序章。
- 五幕依次为海堤洪水、城市沉没、幸存者船队、异常漩涡、木筏苏醒。旁白保留用户原文，不将未知遗迹描述当作玩法已开放。
- 黑底，上方居中插图，下方左对齐白字；1600×900 设计坐标，整体等比适配窗口，图片不拉伸。仅通过 AtlasTexture 显示画面区域去除原图黑色留白，不改源图片。
- 文字约每秒12字，标点和换行停顿，0.65秒淡入；全文显示后停留2.8秒（含0.65秒淡出）进入下一幕。完整自动播放实测约41秒，受帧率影响。
- 使用用户提供的 Blip Voice 2.0，独立 `OpeningNarrator` 节点调用 `play_char`；动物森友会预设，按字哈希音高，gain 0.22，标点不响。无需注册全局 Autoload 或启用编辑器面板。插件原文件不改动。
- BGM 循环播放，音量 -16dB。换幕、补全文字、跳过和退出停止当前狸语；离开序章停止 BGM。快进不补播所有字音。
- 点击画面、继续按钮、空格/回车/右方向键：先补全本幕文字，再次操作进入下一幕。跳过按钮或 Esc 直接结束。
- 完成或主动跳过后写 `user://opening-intro.cfg` 的 `[opening] watched=true`，以后启动直接进入首页；中途关闭未写完成标记，下次从第一幕重播。写入失败会警告并保留下次重播行为。
- 标记属于本机应用数据，不随游戏存档复制；清除本机应用数据后会再次播放。没有改动核心状态、dispatch、Agent 接口、规则随机流、游戏存档及恢复协议。

素材来源、SHA256 和运行映射见 [源记录](../asset-sources/opening-intro-v1/README.md) 与 `assets/manifest.json`。Android/Windows 导出预设显式包含 `assets/opening-intro/*.json`。

验证见 [开场序章验证](../evidence/opening-intro-verification.md)。

2026-10-17：序章作为特殊剧情收录于[剧情回廊](story-gallery.md)。回顾使用 `persist_completion=false`，跳过/完成均不改首次观看标记。
