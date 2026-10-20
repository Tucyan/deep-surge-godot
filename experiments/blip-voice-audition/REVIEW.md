# Blip Voice 音效方案 · 待审核

<!-- 状态：提案，未应用到游戏。审核通过后再落地。 -->
<!-- 生成日期：2026-10-20　分支：codex/integrate-v03-relics　工作树：C:/Users/ALmerb/.codex/worktrees/deep-surge-integrated-20261020 -->

## 0. 本次边界

| 项 | 状态 |
| --- | --- |
| 新增文件 | 仅 `experiments/blip-voice-audition/`（烘焙脚本、试听页、本文件、22 个 WAV） |
| 游戏代码改动 | **0 行**。`flow_app.gd`、`pages/`、`presentation/`、`project.godot`、`assets/manifest.json` 全部未动（工作树里原有的未提交改动原样保留，未合并、未回退） |
| 插件本体 | 未修改。`addons/blip_voice/` 与你给的 zip 逐文件一致，只多出 Godot 自动生成的 `.uid` / `.import` |
| 插件启用 | **仍未启用**：`project.godot` 里没有 `[autoload]`、也没有 `[editor_plugins]` |

关于最后一条，有个读代码时发现的事实值得先说明：`presentation/opening_intro.gd` 第 7 行
`const Voice = preload("res://addons/blip_voice/blip_voice.gd")`，第 87 行 `Voice.new()` 自己
`add_child` 了一个节点，全程没有用 `Blips` 单例。也就是说**序章的旁白音一直是这么接的，插件从来没被启用过**。
好处是接入新声音不必动 `project.godot`（避免 autoload 变更、避免导出后单例缺失），可以完全沿用序章的写法。

另外，工作树里还有**不是我做的、尚未提交的音频层**，本方案特意对齐它而不是另起一套：

| 已有 | 位置 | 本方案的用法 |
| --- | --- | --- |
| 背景音乐导演 | `presentation/music_director.gd`（未跟踪） | 音效层照它的结构写：配置驱动、双播放器、`trim_db`、绝不写 session |
| 曲目配置 | `assets/music/music.json` | 音效配置同样落一个 JSON，不硬编码在脚本里 |
| 实例化方式 | `flow_app.gd:44` `preload(...).new()` | 音效也在这里实例化，不加 autoload |
| 音乐开关与音量 | `presentation/settings_panel.gd:353-395`、`display_settings.gd:23-24` | 缺的是**音效**那一行，照样式补 |

## 1. 先听

打开同目录的 `audition.html`（点一下就播放，可逐条对比）：

- **16 条音效**：界面反馈 / 事件节点 / 环境与战斗 / 结果结算 / 流程，五组
- **6 条对白音色**：同一句真实文案、不同参数；第一条就是序章现在用的旁白，作为音量与语速基准

两条产线的电平是**分开设计**的，听的时候别用响度判断音色好坏：

| 产线 | 播放路径 | 烘到的电平 | 为什么 |
| --- | --- | --- | --- |
| 音效 | `AudioStreamPlayer`，0 dB | 峰值 −3 ~ −6 dBFS | 短促音必须够响才听得见 |
| 对白音色 | 插件内部的增益链 | 峰值 ≈ −12 dBFS | 和 `opening_intro.gd` 现有旁白同电平，方便横向比音色 |

全部 44.1 kHz / 16 bit / 单声道，最长 0.68 s（音效）、3.14 s（音色）。

## 2. 音效清单与接入点

“接入点”是从当前代码里读出来的真实位置。**以函数名为准**：工作树里 `pages/flow_story.gd` 正在被另一个进程编辑
（21:19–21:21 有改动，整体 +110 行），行号会漂移。下面括号里的行号是 21:22 复核时的值，仅作参考。

| id | 场景 | 时长 | 接入点 |
| --- | --- | --- | --- |
| `ui_tap` | 通用点击 | 86 ms | 全局 widget 层，待定（目前没有统一按钮点击音） |
| `ui_tap_soft` | 高频重复操作（翻页/滚动） | 90 ms | 同上 |
| `ui_confirm` | 选项二次点击提交 | 170 ms | `pages/flow_story.gd` `commit()`（471 行） |
| `ui_cancel` | 退出预选 | 160 ms | `pages/flow_story.gd` `cancel_preselect()`（489 行） |
| `ui_blocked` | 条件不足的选项 | 145 ms | `pages/flow_story.gd` `press()` 里的 `if entry.button.disabled: return`（467 行） |
| `choice_preselect` | 首次点击进入预选 | 115 ms | `pages/flow_story.gd` `set_preselect()`（480 行） |
| `ap_spend` | 扣行动点 | 200 ms | 待定（命令结算层，需与 AP 刷新点对齐） |
| `card_draw` | 抽牌 / 入袋 | 165 ms | 待定（`presentation/card_stack.gd` / `hand_fan.gd` 侧） |
| `relic_found` | 拾得遗物 | 490 ms | `presentation/acquisition_overlay.gd` `collect()`（108 行） |
| `danger_warning` | 环境/天气危险提示 | 380 ms | 待定（`voyage_hud.gd` 环境状态区） |
| `monster_appear` | 遭遇怪物 | 560 ms | `pages/flow_battle.gd` `build()`（6 行）战斗页构建时 |
| `battle_hit` | 战斗命中 | 145 ms | `pages/flow_battle.gd` `play_card()`（173 行） |
| `result_good` | 结果 · 成功 | 360 ms | `pages/flow_story.gd` `paint_prose()`（520 行），result 阶段重绘时 |
| `result_bad` | 结果 · 失败 | 390 ms | 同上，按结果字段分流 |
| `voyage_start` | 起航 / 进入航行 | 560 ms | `presentation/voyage_transition.gd` `_ready()`（7 行） |
| `victory` | 战斗胜利 | 680 ms | 待定（战斗日志出现“胜利”时的结算点，`battle_hud_view.gd` 582 行附近） |

## 3. 对白音色清单

| id | 用途 | 关键参数 | 备注 |
| --- | --- | --- | --- |
| `narrator` | 旁白（**现状**，作对照） | 动物森友会底子、按字固定音高、增益 0.22、字间隔 1/12 s | 即 `opening_intro.gd:90-93`，建议原样保留 |
| `relic` | 遗物低语 | 正弦波 430 Hz、抖动 6、低通 1600 | 贴耳感，不抢文本 |
| `entity` | 深海存在 / 怪物 | 锯齿波 190 Hz、抖动 9、句尾降调 8 | 慢、沉，非人说话者 |
| `trader` | 商人 | 三角波 640 Hz、语速偏快、低通 4200 | 像在兜售东西 |
| `system` | 系统提示 / 规则播报 | 方波 720 Hz、抖动 0、音高完全一致 | 机械感，不会像“谁在说话” |
| `captain` | 船长 / 主角 | 方波 540 Hz、抖动 1.6 | 比旁白低一档，同屏能分开 |

## 4. 一个必须先裁决的设计问题

节点事件的正文**是一次性显示完的**（`pages/flow_story.gd` 的 `paint_lines()` 直接设 Label 文本），
没有 `visible_characters` 打字机，也不复用 `pages/story_page.gd` 的那套逐字逻辑。

所以在事件页上，逐字 blip **没有天然的挂载点**。三条路：

| 方案 | 做法 | 代价 |
| --- | --- | --- |
| **A. 只做说话人标识音（推荐）** | 每段文案出现时敲 1~3 声，标识“是谁在说”，不逐字 | 最省，不改布局与跳过逻辑；“音效 + 少量 blip”已能建立角色区分 |
| B. 补一个隐形的逐字驱动 | 用 Timer 按 `char_interval` 逐字调 `play_char`，文字仍一次性显示 | 音画不同步（字已全出、声音还在念），观感偏怪 |
| C. 给事件正文加打字机 | 复用 `story_page.gd` 的做法 | 改动大：三栏布局、滚动、跳过、预选重绘都要跟着改，且与“手机不撑大事件容器”的现行契约冲突 |

我倾向 **A**：把音色当“说话人标识”而不是“朗读”，和当前事件页的静态正文匹配；`C` 留给后续单独评估。

## 5. 运行时怎么放：两个方案，请选一个

### 方案 A：预烘 WAV + 资产登记（推荐）

- 16 条音效落 `assets/audio/sfx/`，在 `assets/manifest.json` 里按现有格式登记
  （`path` / `source` / `version` / `sha256` / `dependencies` / `role` / `runtime_mapping`，参照 `opening.music` 那条）
- 新增 `presentation/sfx_director.gd`，**结构照 `music_director.gd` 抄**：读一个 `assets/audio/sfx.json` 配置、
  一组播放器轮转、`trim_db` 统一配平、暴露 `play(id)`；同样不写 session、不碰随机流
- 在 `flow_app.gd:44` 旁边实例化，不加 autoload
- 优点：时序精确（不靠 Timer 拼）；可复听；改音色只需重跑 `bake.gd` 再重生成配置
- 代价：新增 16 个二进制资产与 16 条 manifest 条目，需登记来源（本项目程序化生成，来源写 `project-authored/blip-voice-20261020`）

### 方案 B：运行时不落盘，直接用插件播

- 每条 cue 对应一个 `BlipVoice` 节点，按时间轴连续 `play_blip(半音)`，不产出 WAV
- 优点：零二进制资产、完全程序化、改参数即时生效
- 代价：多音 cue 要写调度代码；`Timer` 抖动在 20~50 ms 的间隔上可听；同屏并发节点变多；导出必须包含 `addons/`

**建议 A。** 理由是项目已经有资产登记契约，而音效属于“定稿后很少改”的内容；探索期再改动只需重烘。

## 6. 接入补丁草案（仅示意，未落地）

```gdscript
# 新增 presentation/sfx_director.gd —— 骨架与 music_director.gd 同构
extends Node
const CONFIG_PATH := "res://assets/audio/sfx.json"
var trim_db := -3.0
var volume := 0.7            # 对应 display_settings 的 sfx_volume
var enabled := true
var _players: Array[AudioStreamPlayer] = []
func play(id: String) -> void: ...
```

配置文件 `assets/audio/sfx.json` 只放 id → 路径 → 基准音量，重烘时由 `bake.gd` 顺带生成，
和 `assets/music/music.json` 一个体例。

需要插的行（全部是单行调用，不改任何既有逻辑）：

| 文件 | 位置（函数名优先） | 插入 |
| --- | --- | --- |
| `flow_app.gd` | 44 行 `music = preload(...)` 之后 | `var sfx = preload("res://presentation/sfx_director.gd").new()` |
| `pages/flow_story.gd` | `press()` 的 `disabled` 提前返回前 | `sfx.play("ui_blocked")` |
| `pages/flow_story.gd` | `set_preselect()` 内、`paint_options()` 之前 | `sfx.play("choice_preselect")` |
| `pages/flow_story.gd` | `commit()` 开头 | `sfx.play("ui_confirm")` |
| `pages/flow_story.gd` | `cancel_preselect()` | `sfx.play("ui_cancel")` |
| `presentation/acquisition_overlay.gd` | `collect()`（108 行） | `sfx.play("relic_found")` |
| `pages/flow_battle.gd` | `build()`（6 行）/ `play_card()`（173 行） | `sfx.play("monster_appear")` / `("battle_hit")` |
| `presentation/voyage_transition.gd` | `_ready()`（7 行） | `sfx.play("voyage_start")` |
| `presentation/display_settings.gd` | 23–24 行 `music_volume` / `music_enabled` 之后 | 加 `sfx_volume := 0.7`、`sfx_enabled := true`，并把 22 行的注释 “music only” 一并改掉 |
| `presentation/settings_panel.gd` | 音乐那两行（353–395 行区间）之后 | 照样式加「音效开关」「音效音量」两行 |

注意：这些点**全是表现层**，不写 GameState、不耗随机流、不进存档，符合“预览/取消/读档不重掷”的现行契约。

## 7. 风险与待确认

1. **音频总线**：项目仍没有 `default_bus_layout.tres`，音乐导演靠 `volume_db` + `trim_db` 调音量，不建总线。
   音效跟不跟着这个做法？建议跟着（不引入总线资源，少一处导出风险）；如果以后要统一压缩/混响，再建 `SFX` 总线。
2. **设置面板只有音乐**：`display_settings.gd:23` 的注释明确写着 “music only”，
   现在有背景音乐开关与音量（`settings_panel.gd:353-395`），**没有音效项**。加音效就必须同批加「音效开关 + 音效音量」，
   否则玩家只能靠系统音量。这会动到设置存档字段（`user://display-settings.cfg`），需要确认是否接受新增字段。
3. **移动端并发**：单帧最多几条 cue 同时响需要定上限（建议 4），否则结算时会糊。
4. **导出**：方案 A 只需确认 `assets/audio/` 未被导出预设排除；方案 B 还要确认 `addons/blip_voice/` 被打包
   （`export_presets.cfg` 里没有排除规则，但要实测）。
5. **音量基准**：音乐经 `trim_db -6`，音效烘到 −3 ~ −6 dBFS，序章对白 blip ≈ −12 dBFS。
   三者叠在一起会不会打架，需要一次整体平衡（这个必须实机听，看波形没用）。
6. **剧情模式暂停中**：本方案只覆盖节点事件、战斗、流程与序章（序章已接入，不动它）。
   `pages/story_page.gd` 的打字机是现成的接入面，但按 AGENTS 约定暂不扩展。

## 8. 若批准，验收怎么做

1. 逐条试听 → 确认音色方向（这一步就现在）
2. 落地方案 A：新增 `presentation/sfx.gd` + 7 处单行调用 + manifest 登记
3. 跑一次固定种子路线（`tools/verify_v03.py` / `tools/play_expansion.py`）确认规则与随机流未变
4. 移动端 21:9 与桌面各录一次事件流程，确认不糊、不卡、不遮 UI
5. 导出一份可执行文件实测（`addons/` 与 `assets/audio/` 都在包内、无加载错误）
6. 文档：新增 `docs/audio.md` 专题，并在 `documentation-map.json` 登记；`docs/node-event-presentation.md` 补一行“表现层音效”说明

## 9. 复核记录

```
# 烘焙（Godot 4.7.2，无头）
Godot_v4.7.2-stable_win64.exe --headless --path . \
  --script res://experiments/blip-voice-audition/bake.gd
→ BAKE_DONE cues=16 profiles=6

# 试听页
python experiments/blip-voice-audition/build_page.py
→ audition.html（22 条，总长 14.8 s）

# 产物电平复核（Python wave，逐条）
音效峰值 −2.5 ~ −10.4 dBFS，对白音色 −12.0 ~ −14.0 dBFS，无静音、无削波
```

未执行（按你的要求，等审核）：任何游戏代码改动、资产登记、真机播放、导出验证。

另有一条环境情况需要你知道：本次会话期间（21:19–21:21），工作树里有**另一个进程**在写
`flow_app.gd`、`pages/flow_story.gd`、`presentation/settings_panel.gd`、`presentation/display_settings.gd`，
并新建了 `presentation/music_director.gd` 与 `assets/music/`。这些都不是本次会话的改动（本会话只写了
`experiments/blip-voice-audition/`），也没有被回退或合并。上面引用的 `flow_story.gd` 行号已因此整体后移约 110 行，
并已按 21:22 的实际内容重新核对；若那个进程继续编辑，落地前请再对一次函数名。
