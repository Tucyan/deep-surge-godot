# 背景音乐与音频
<!-- doc-status: current; doc-role: contract; content-version: godot-flow-v03-02; reviewed: 2026-10-20 -->

表现层的非剧情背景音乐（BGM）。只读运行摘要决定放哪首，不写 `GameSession`、不消耗规则随机、不改变任何结算。开场序章与回廊重播自带配乐与旁白，不走本导演。

## cue 判定

判定是纯函数 `music_director.gd/cue_for(screen, phase, boss)`，界面、导演和测试共用同一份规则。

| cue | 触发条件 | 曲目 |
|---|---|---|
| `home` | `screen == "home"`，或阶段为 `finished` / `chapterComplete`（结算与章节停点） | 巴赫 BWV82 咏叹调（吉他四重奏） |
| `boss` | 阶段为 `preparation` 或 `battle`，且当前节点 `boss == true` | 待补；当前回退 `voyage` |
| `voyage` | 其余阶段：`navigation`、`story`、`interaction`、`aftermath` 等 | 巴赫 BWV578 赋格（吉他四重奏） |

Boss 音乐从战前准备页开始，击败后的 `aftermath` 回到航行音乐；不做击破后的延迟切歌。普通战斗节点不带 `boss` 标记，保持航行音乐。

## 曲目表与回退

曲目表为 `assets/music/music.json`：每个 cue 有 `tracks` 列表与可选的 `fallback`。

- 按列表顺序取第一条能加载的曲目；加载失败或文件不存在时继续下一条。
- 整条 cue 都不可用时沿 `fallback` 链找，最多 4 层；仍为空则淡出并保持静音，不报错、不阻断流程。
- 当前配置：`home → aria`、`voyage → fuga`、`boss → []` 且 `fallback: "voyage"`。用户提供的 `boss配乐(1).zip` 内只有空目录，没有音频，因此 Boss 阶段先播放航行音乐；补齐曲目后只需在 `tracks` 填路径，规则与代码不用改。

## 播放与切换

- 两个 `AudioStreamPlayer` 交叉淡入，默认 `fade_seconds = 1.5`；同一时刻只有一路可听，旧轨淡到 -80 dB。
- 每条 cue 单曲循环：MP3 导入参数 `loop=true`，导演加载后仍再写一次，避免换曲时漏配。
- 只在 cue 名变化或当前无播放时切歌；同一 cue 内的翻页、开关面板、局部刷新都不重播、不回开头。
- 静音、0% 音量与挂起只改目标音量，不重置播放进度。

## 环境音（海浪）

背景海浪是**持续层**：不随 cue 切换、不重播、不占 cue 表，单独由 `ambience_director.gd` 播放。

- 音频：`assets/audio/ambience/waves-loop-v1.ogg`，48.000 秒的无缝循环，导入参数 `loop=true`，运行时再写一次 `loop=true`。
- 底噪由 OpenGameArt 的 CC0 海浪录音拼接而成（jasinski 沙滩碎浪 + transitking 海浪冲刷），来源与处理见[海浪源记录](../asset-sources/ocean-waves-20261020/README.md)。
- 配置：`assets/audio/ambience.json`，字段为 `tracks` / `trim_db` / `fade_seconds`；`trim_db` 默认 **-16 dB**，海浪压在配乐下面，不与旋律抢。
- 播放：一个 `AudioStreamPlayer` 循环播放，音量用 `linear_to_db(音量) + trim_db`；静音、0% 音量与挂起只改目标音量，**不重置播放进度**。
- 与音乐的关系：切 cue、换曲、战斗结算都不打断海浪；回廊重播打开时海浪与配乐一起挂起，关闭后一起恢复。
- 音量来源：与配乐共用同一组本机偏好（`music_volume` / `music_enabled`），因此**关闭配乐会同时关闭海浪**，设置面板目前没有独立的环境音开关。

## 音量与保存

- 线性音量 0.00–1.00，默认 0.60；输出 `linear_to_db(音量) + trim_db`，`trim_db` 默认 -6 dB，避免成品曲过响。海浪用同一音量值，另加自己的 `trim_db`（-16 dB）。
- 保存于 `user://display-settings.cfg` 的 `[audio]` 段：`music_volume`、`music_enabled`。属于本机显示偏好，**不进入航程存档，也不进入剧情配对存档**；读档、开局、换难度都不改变音量。
- 设置面板「游戏偏好」页首两行：`MusicEnabled` 开关与 `MusicVolume` 滑条（0–100%，步进 5）。拖动中只在松手时落盘，避免每帧写文件。该开关同时控制配乐与环境音。

## 与序章、回廊的关系

- 首启序章在 `game_bootstrap.gd` 内播完才进入主流程，此时导演尚未创建，两者不会重叠。
- 回廊重播（`StoryReplay`）打开时导演挂起，关闭后恢复；轮询间隔 0.25 秒，用于覆盖不触发重新渲染的打开路径。重播不改 `watched` 标记，也不写任何进度。
- 序章与回廊音乐仍是 `opening.music`，与本导演的曲目互不复用。

## 失败与边界

- 配置缺失或格式错误：`music_director.error` 记录原因，游戏照常运行，只是没有配乐；不在界面弹提示。
- 单个曲目加载失败：跳过该条并尝试下一条或回退；不会因音乐问题中断航程。
- 无头运行：音频驱动为 Dummy，测试仍能断言 cue、当前曲目、循环标记与目标音量。

## 换曲步骤

1. 音频放入 `assets/music/`，命名带稳定后缀（如 `daily-arsnova-bwv82-aria-v1.mp3`），不要直接改原文件字节。
2. 在 `music.json` 的对应 cue 填 `res://assets/music/...`；新 cue 同时补 `fallback`。
3. `python tools/register_music.py` 重算 hash 并登记 manifest。
4. `Godot --headless --import --path .` 生成导入缓存，确认 `.import` 中 `loop=true`。
5. 运行 `tests/test_music_director.gd`。

## 换环境音步骤

1. 音频放入 `assets/audio/ambience/`，命名带稳定后缀（如 `waves-loop-v1.ogg`）。
2. 在 `assets/audio/ambience.json` 的 `tracks` 填 `res://assets/audio/ambience/...`。
3. `python tools/register_ambience.py` 重算 hash 并登记 manifest。
4. `Godot --headless --import --path .` 生成导入缓存，确认 `.import` 中 `loop=true`。
5. 运行 `tests/test_ambience_director.gd`。
6. 需要重做素材本身时用 `python tools/build_waves_ambience.py --fetch --cache .cache/ocean-waves`（需要 numpy、soundfile、ffmpeg，仅创作期使用）。

来源、字节与时长见[音乐源记录](../asset-sources/music-daily-20261020/README.md)与[海浪源记录](../asset-sources/ocean-waves-20261020/README.md)。

## 已知限制

- MP3 没有采样级无缝接缝，循环点为整段重播；需要无缝时换 OGG 并填 `loop_offset`。海浪循环本身是采样级无缝的，但 Vorbis 编码仍有约 1.4 ms 的解码前导。
- 当前没有独立音频总线与混音器：音乐与环境音直接走 Master，无法单独 ducking，也没有音效总线。
- 只做背景音乐与环境音，没有卡牌、战斗、UI 音效系统。
- 环境音没有独立开关：它跟随配乐的开关与音量（见[环境音](#环境音海浪)）。
- 音量改变即时生效但只影响本机偏好，不与系统音量或设备静音联动。
- 图形界面与真机触摸下的实际听感尚未单独验收；已执行的仅为无头行为校验。

## 验证入口

`tests/test_music_director.gd` 覆盖：cue 判定（含 boss 与结算）、boss 缺轨回退、循环标记、音量/静音/挂起换算、开关与音量偏好往返、越界音量收敛。

`tests/test_ambience_director.gd` 覆盖：环境音配置与曲目表、导入后的循环标记、实际播放、音量与静音换算、回廊挂起与恢复。相关设置语义见[显示与 UI 大小设置](display-settings.md)。
