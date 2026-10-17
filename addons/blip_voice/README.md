# Blip Voice

给 Godot 4 用的对话逐字电子语音音效（就是逆转裁判那种「哔哔哔」）。
波形**程序化合成**，包里没有一个音频文件 —— 启用即用，改参数即时生效，也没有素材版权问题。

---

## 文件结构：6 个文件，只有 1 个有代码

```
addons/blip_voice/
├── plugin.cfg        ← 插件声明（4 行）
├── plugin.gd         ← 空壳，只有 6 行，接编辑器生命周期
├── blip_voice.gd     ← 全部实现：参数 + 合成器 + 试听面板 + 安装入口
├── icon.svg          ← 图标
├── README.md         ← 本文件（写给人看）
└── AI_GUIDE.md       ← 写给 AI 助手 / 自动化工具看的接入说明
```

> 要让别的 AI 帮你把这个插件接进项目？把 `AI_GUIDE.md` 整个丢给它就行 ——
> 里面包含完整 API、三种接入方案的判断方法、参数表和踩坑清单。

**为什么不能压成「plugin.cfg + 一个 .gd」？**
Godot 强制要求 `plugin.cfg` 指向的脚本必须 `extends EditorPlugin`，而 `EditorPlugin` 是编辑器专有类 ——
**导出的游戏里根本没有这个类**。如果实现和它写在同一个文件里，游戏发布版启动时会因为加载不到基类而报错。
（这也正是我在代码里刻意不给 `install(ep)` 的参数加类型标注的原因。）
所以最小可行结构就是：一个壳子文件 + 一个实现文件。真正的代码只有 `blip_voice.gd` 一个。

> 另外，把参数从独立 Resource 合并进了节点本身。代价：不能再存 `.tres` 音色预设，
> 好处是每个角色的参数直接跟着节点走，反而更直观。需要 `.tres` 预设的话跟我说，我加回来。

---

## 一、安装

1. 把整个 `addons/blip_voice/` 拷到你的 Godot 项目根目录（和 `project.godot` 同级）。
2. **项目 → 项目设置 → 插件**，勾选 **Blip Voice** 启用。
3. 启用后插件自动做两件事：
   - 注册全局单例 **`Blips`**；
   - 在编辑器**底部**加一个 **Blip Voice** 试听面板，选预设、填一句台词就能当场听。

> `Blips` 没认出来就重启一次编辑器（Autoload 变更偶尔要刷新）。
> 不想用单例：项目设置 → 全局 → 自动加载 里删掉 `Blips` 即可，其它功能照常。

---

## 二、三种用法

### 1. 最省事：全局单例

```gdscript
func _ready() -> void:
    Blips.apply_preset(&"ace_attorney")   # 可选，切换音色
    Blips.speak("异议！这句证词和现场情况完全矛盾！")
```

`speak()` 是协程式逐字发声，自带标点停顿和句尾降调；重复调用会自动打断上一句。

```gdscript
Blips.line_finished.connect(_on_line_done)   # 说完才允许点下一步
```

### 2. 接你自己的打字机（逐字触发）

每显示一个字就调一次 `play_char`：

```gdscript
func type_next_char() -> void:
    _index += 1
    label.visible_characters = _index
    var ch := text[_index - 1]
    Blips.play_char(ch, _index - 1, text.length())
```

`play_char` 会自动跳过空格和标点（标点的停顿交给你的打字机节奏控制）。

### 3. 最偷懒：让 RichTextLabel 自己响

如果你的对白用 `RichTextLabel` 的 `visible_characters` / `visible_ratio` 做打字机，
**一行就接完了，打字机逻辑一个字都不用改**：

```gdscript
func _ready() -> void:
    Blips.watch($DialogLabel)      # 之后它每多露出一个字就自动响一声
```

它用的是 `visible_characters` + `get_parsed_text()`，所以 BBCode（`[color=red]异议！[/color]`）不会算错位。

```gdscript
Blips.unwatch($DialogLabel)    # 停止监听
Blips.unwatch_all()            # 全部停止
```

多角色不同嗓音：给每个角色单独拖一个 `BlipVoice` 节点（它有全局类名，可以直接在场景里新建），
各自设参数、各自 `watch()` 自己的标签。

---

## 三、参数速查

全部是节点上的 `@export`，在检查器里直接调，**改完立刻重新烘焙，不用重启**。

| 分组 | 参数 | 说明 |
|---|---|---|
| 音高 | `base_freq` | 基础频率。900≈逆转裁判那种偏高的电子音，500 更软，300 更低沉 |
| | `pitch_jitter` | 每个字的音高随机范围（半音）。0 = 完全平，8+ 像机器人在嘟囔 |
| | `declination` | 句尾降调（语调下垂），0 就变成念经 |
| | `pitch_mode` | 随机 / 同一个字永远同一个音 / 完全一致 |
| 时值 | `note_duration` | 单字音长，30~90ms。**调长会变成琴键，是最大的坑** |
| | `char_interval` | 字与字的间隔 = 说话速度 |
| | `punctuation_pause` | 标点停顿倍率（句号、问号再额外 ×1.6） |
| | `max_blips_per_second` | 限速，防止多角色同时说话糊成一团，0 = 不限 |
| 音色 | `wave` | 方波（最像）/ 锯齿波（更电子）/ 三角波（更软）/ 正弦波 |
| | `lowpass_cutoff` | 越低越闷。**纯方波不削高频会刺耳，建议 3k~6k** |
| | `gain` | 音量 |
| | `glide` | 音内部的下滑比例，一点点就有「嘟↓」的口吻 |
| | `variants` | 预烘焙几个音色微变的变体，避免连续同音像机关枪 |
| 播放 | `player_pool` | 播放器池大小，连续触发时轮流用，避免互相打断 |
| | `bus` | 输出总线。可以单独给对白建一条总线，统一调音量 / 加混响 |

### 内置预设

| id | 说明 |
|---|---|
| `ace_attorney` | 逆转裁判 · 对白电子音（默认值就是它） |
| `animal_crossing` | 动物森友会 · 软糯动物语（音高抖动大） |
| `famicom` | 红白机 · 复古字音 |
| `robot` | 机械腔 · 机器人 |
| `chip` | 清脆小萌音 |

```gdscript
Blips.apply_preset(&"robot")
```

试听面板里选好之后，底下会直接告诉你该写哪一句。

---

## 四、其它接口

```gdscript
Blips.play_blip(-3.0)                          # 手动敲一声，参数是相对基础音高的半音偏移
Blips.stop()                                   # 立刻闭嘴
Blips.is_speaking()                            # 还在读吗
Blips.rebuild()                                # 你直接改了参数之后，重新烘焙波形
BlipVoice.bake_line(Blips, "这句话")            # 离线烘焙整句成一条 AudioStreamWAV
BlipVoice.is_pause("。") / is_silent(" ") / speaks("字")   # 字符分类工具
```

`bake_line()` 适合做「语音回放」或导出成品音频，实时打字不需要它。

---

## 五、常见问题

**没声音？**
按顺序查：① Master 总线音量；② `gain`（默认 0.32 已经不低）；③ 是不是被 `max_blips_per_second` 拦了；
④ 用底部试听面板确认音色本身能响 —— 能响就是接线问题。

**为什么节点里会多出几个 AudioStreamPlayer？**
那是播放器池。它们在编辑器里显示为内部节点，不会被存进你的场景文件，导出后也只在运行时存在。

**能上 Godot 3.x 吗？**
不行。`AudioStreamWAV`、`get_parsed_text()`、内联 setter 都是 Godot 4 的 API。

**想让它更像某个游戏？**
优先动这两个：`pitch_jitter`（决定「平」还是「咕哝」）和 `char_interval`（决定语速）。
`lowpass_cutoff` 决定刺耳还是柔和。其余微调即可。
