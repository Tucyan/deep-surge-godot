# Blip Voice —— 接入说明（本文写给 AI 助手 / 自动化工具）

> 如果你是正在帮用户改 Godot 项目的 AI，请**先读完本文再动手**。
> 这个插件的工作方式有几个非直觉的约束，踩了会让游戏发布版直接启动失败。

---

## 0. 一句话概括

`res://addons/blip_voice/` 是一个 Godot 4 插件，用**程序化合成**的方式，为逐字打字机对白产生
「每个字一声电子音」的效果（逆转裁判 / 动物森友会那种）。没有任何音频素材文件。

运行时只需要一个东西：全局单例 **`Blips`**（它是 `blip_voice.gd` 这个脚本的 autoload 实例）。

---

## 1. 硬性事实（不要凭常识假设）

| 项 | 值 |
|---|---|
| 引擎 | Godot **4.x**（4.0 及以上）。**不支持 3.x**，别尝试降级移植 |
| 语言 | GDScript，全部实现集中在**一个**文件里 |
| 插件路径 | `res://addons/blip_voice/` |
| 全局类名 | `BlipVoice`（对应 `blip_voice.gd` 的主类，extends Node） |
| 运行时单例 | `Blips`（autoload，脚本就是 `blip_voice.gd`） |
| 外部依赖 | 无。没有音频文件、没有第三方库、没有 MCP/网络调用 |
| 输出 | 每个字一个 `AudioStreamWAV`，通过内部 `AudioStreamPlayer` 池播放 |

**代码组织（只有一个文件有代码）：**

| 文件 | 内容 | 会在游戏里运行吗 |
|---|---|---|
| `plugin.cfg` | 插件声明，`script="plugin.gd"` | 否 |
| `plugin.gd` | 6 行空壳，`extends EditorPlugin`，只调 `Impl.install/uninstall` | **否** |
| `blip_voice.gd` | 参数、合成器（内部类 `Synth`）、编辑器面板（内部类 `Dock`）、`install/uninstall` | **是** |
| `icon.svg` | 图标 | 否 |
| `README.md` | 给人看的说明 | 否 |
| `AI_GUIDE.md` | 本文 | 否 |

---

## 2. ⚠️ 三条绝对不能碰的红线

违反任意一条，插件在**编辑器里可能正常，但游戏导出后会启动失败**。

1. **`plugin.cfg` 的 `script` 必须指向 `plugin.gd`。**
   Godot 强制要求它 `extends EditorPlugin`，而 `EditorPlugin` 是编辑器专有类，导出模板里没有注册。
   因此**不要把 `blip_voice.gd` 改成 `extends EditorPlugin`**，也不要试图把两个文件合并成一个。

2. **`blip_voice.gd` 里不能出现 `EditorPlugin` 这个标识符**，包括类型标注。
   这就是 `install(ep)` / `uninstall(ep)` 的参数**故意不写类型**的原因。
   如果看到「`ep` 没有类型标注，补上 `: EditorPlugin` 更规范」—— **不要补**。

3. **autoload 的名字必须是 `Blips`，不能改成 `BlipVoice`。**
   `BlipVoice` 已经是全局类名，autoload 与之同名会让 Godot 报冲突，
   并且运行时会遮蔽类名，导致 `BlipVoice.speaks()` 这类静态调用失效。

---

## 3. 安装（通常需要人在编辑器里点一次）

插件启用后会自动完成两件事，无需手写代码：

1. 注册 autoload `Blips` → `res://addons/blip_voice/blip_voice.gd`
2. 在编辑器底部挂一个 **Blip Voice** 试听面板

**人工路径**：项目设置 → 插件 → 勾选 Blip Voice。

**如果需要直接改 `project.godot`**，加这一段：

```ini
[autoload]

Blips="*res://addons/blip_voice/blip_voice.gd"
```

改完后 autoload 生效可能需要重启编辑器。另外确认 `plugin.cfg` 存在且 `[plugin]` 段的 `script="plugin.gd"`，
否则插件列表里不会出现它。

---

## 4. 完整 API 参考

### 4.1 信号

```gdscript
signal line_finished()      # speak() 自然读完一整句时发出；被 stop() 打断时不会发出
```

### 4.2 实例方法（通过 `Blips.xxx` 或任意 `BlipVoice` 节点调用）

```gdscript
func speak(text: String) -> void
```
协程式整句朗读。自带标点停顿、句尾降调。**可以 await**：`await Blips.speak(line)`。
重复调用会打断上一句。

```gdscript
func play_char(ch: String, index: int = 0, total: int = 0) -> void
```
给**打字机**用的逐字入口。`index` 是该字在全文中的下标、`total` 是全文长度 ——
这两个参数只影响「句尾降调」的计算，都传 0 也能响，只是没有语调下垂。

```gdscript
func play_blip(semitone: float = 0.0) -> void
```
手动敲一声。参数是**相对基础音高的半音偏移**（可为负）。
一般不用它；用 `play_char` 才有音高抖动和句尾降调。

```gdscript
func stop() -> void                                      # 立刻停止发声并结束 speak() 协程
func is_speaking() -> bool                               # 是否正在 speak()
func watch(label: RichTextLabel) -> void                 # 盯住一个标签，自动逐字发声
func unwatch(label: RichTextLabel) -> void
func unwatch_all() -> void
func semitones_for(ch: String, index: int, total: int) -> float   # 查某个字的音高偏移
func rebuild() -> void                                   # 参数被直接改写后重新烘焙波形
func apply_preset(id: StringName) -> void                # 切到某个预设音色
```

### 4.3 静态方法（用 `BlipVoice.` 调用）

```gdscript
BlipVoice.speaks(ch) -> bool          # 这个字该不该出声（空格/标点返回 false）
BlipVoice.is_silent(ch) -> bool       # 空白字符
BlipVoice.is_pause(ch) -> bool        # 停顿类标点
BlipVoice.is_hard_pause(ch) -> bool   # 长停顿标点（。！？）
BlipVoice.preset_ids() -> Array[StringName]
BlipVoice.preset_label(id) -> String
BlipVoice.preset_values(id) -> Dictionary
BlipVoice.bake_line(voice, text) -> AudioStreamWAV   # 离线把整句烘成一条音频
BlipVoice.install(ep) / uninstall(ep)                # ⚠️ 编辑器专用，游戏代码里绝对不要调
```

### 4.4 可调参数（节点上的 `@export`，也通过 `Blips.参数名` 读写）

改任意一个都会**自动重新烘焙波形**，不需要手动 `rebuild()`。

| 参数 | 类型 | 默认 | 范围 | 说明 |
|---|---|---|---|---|
| `base_freq` | float | 900.0 | 80–1800 | 基础频率（Hz）。900≈逆转裁判，500 更软，300 低沉 |
| `pitch_jitter` | float | 0.4 | 0–12 | 每个字的音高随机范围（半音）。**决定「平」还是「咕哝」** |
| `declination` | float | 3.0 | 0–12 | 句尾降调幅度（半音）。0 = 没有语调下垂 |
| `pitch_mode` | int | 1 | 0/1/2 | 0=随机 1=按字符哈希固定 2=完全一致 |
| `note_duration` | float | 0.038 | 0.01–0.2 | 单字音长（秒）。**超过 0.1 会变成琴键声** |
| `char_interval` | float | 0.052 | 0.02–0.4 | 字间隔（秒）= 语速 |
| `punctuation_pause` | float | 2.5 | 1–6 | 标点停顿倍率，硬标点再 ×1.6 |
| `max_blips_per_second` | float | 0.0 | 0–30 | 限速，0 = 不限。多角色同时说话时用 |
| `wave` | int | 0 | 0–3 | 0=方波 1=锯齿 2=三角 3=正弦 |
| `lowpass_cutoff` | float | 5000.0 | 300–16000 | 低通截止（Hz）。**太低会闷、太高会刺耳** |
| `gain` | float | 0.32 | 0–1 | 线性音量 |
| `glide` | float | 0.02 | 0–0.4 | 音内部下滑比例 |
| `variants` | int | 12 | 1–24 | 预烘焙几个音色微变的变体 |
| `sample_rate` | int | 44100 | — | 采样率 |
| `player_pool` | int | 6 | 1–16 | 播放器池大小 |
| `bus` | StringName | `&"Master"` | — | 输出音频总线。**若项目自定义过总线名，这里要跟着改** |

### 4.5 枚举与常量

```gdscript
BlipVoice.Wave        # SQUARE=0, SAW=1, TRIANGLE=2, SINE=3
BlipVoice.PitchMode   # RANDOM=0, HASH=1, FIXED=2
BlipVoice.AUTOLOAD_NAME   # "Blips"
BlipVoice.AUTOLOAD_PATH   # "res://addons/blip_voice/blip_voice.gd"
```

### 4.6 内置预设

`ace_attorney`（默认值，逆转裁判风）、`animal_crossing`（音高抖动大）、
`famicom`（复古）、`robot`（机械腔）、`chip`（清脆）。

```gdscript
Blips.apply_preset(&"robot")
```

---

## 5. 接入对话系统：先判断属于哪种，再动手

**不要直接套模板。** 先读用户的对话系统脚本，看它怎么推进文字显示，然后选对应方案。

### 方案 A —— 用 `RichTextLabel.visible_characters` / `visible_ratio` 打字（最常见）

用户代码里有类似 `label.visible_characters += 1` 或 `label.visible_ratio = t` 的写法。

→ **只加一行，不要改打字机逻辑**：

```gdscript
func _ready() -> void:
    Blips.watch($DialogLabel)
```

`watch()` 内部用 `visible_characters` + `get_parsed_text()` 取字符，
所以 `[color=red]异议！[/color]` 这类 BBCode 不会错位，也不用管标签。

换新台词、或 `visible_characters` 不是从 0 开始时，若发现漏字/多字，补一次：
`Blips.unwatch($DialogLabel)` 然后重新 `watch()`。

### 方案 B —— 自己用 Timer / Tween 逐字追加文本

用户代码里有类似 `text.substr(0, i)` 或每帧追加一个字符的写法。

→ 在**每显示出一个字的那个位置**插入一行：

```gdscript
var ch := full_text[i - 1]
Blips.play_char(ch, i - 1, full_text.length())
```

注意 `play_char` 会自己跳过空格和标点，**不要在外面再判一次标点**。

### 方案 C —— 只想要「整句自动读」，不关心打字机

```gdscript
Blips.speak(line)
await Blips.line_finished      # 需要等它读完就 await
```

### 多角色不同嗓音

拖多个 `BlipVoice` 节点进场景（它有全局类名，可以在「添加节点」里搜到），各自设参数，
再 `voice.play_char(...)` 或 `voice.watch(该角色的标签)`。**不需要动 `Blips` 单例。**

### 想做「语音回放」或导出成品音频

```gdscript
var clip: AudioStreamWAV = BlipVoice.bake_line(Blips, "这句话")
$AudioStreamPlayer.stream = clip
$AudioStreamPlayer.play()
```

---

## 6. 改代码时的维护契约

如果你要扩展这个插件，请遵守：

**加一个新预设** —— 必须**同时**改三处，否则试听面板会错位或崩溃：
1. `preset_ids()` 的数组里加 id
2. `preset_label(id)` 的 `match` 里加中文名
3. `preset_values(id)` 的 `match` 里加参数字典（只需写**与默认值不同**的键）

**加一个新参数** —— 在 `blip_voice.gd` 的参数区加 `@export` 变量，
并给它加上 `set(value): <字段> = value; _invalidate()` 形式的 setter，
否则改动不会触发重新烘焙。**参数区之外不要放 `@export`。**

**改内部类时** —— 《`Synth`》里的 `W_SQUARE/W_SAW/W_TRIANGLE/W_SINE` 常量
必须与外部 `enum Wave` 的顺序保持一致（两处都是 0/1/2/3）。
内部类**不要引用外部类的类型或函数**（用无类型参数传 `voice` 进去），
这是为了避免 GDScript 自引用/循环引用带来的解析风险。

**加新功能后请同步更新本文的 API 章节。**

---

## 7. 验收清单（改完必须逐条过）

1. 打开编辑器，控制台**没有**脚本解析错误（parse error）。
2. 项目设置 → 全局 → 自动加载里能看到 `Blips`，且指向 `res://addons/blip_voice/blip_voice.gd`。
3. 编辑器底部有 **Blip Voice** 面板，选一个预设、点「试听」，**能听到声音**。
4. 运行游戏，对白逐字显示时**每个字一声**，标点处有停顿。
5. **导出一份可执行文件再跑一次** —— 这是最容易翻车的环节，重点确认没有
   「Could not find base class」之类的加载错误。

---

## 8. 常见故障 → 原因

| 现象 | 最可能的原因 |
|---|---|
| 编辑器里报 `Could not find base class "EditorPlugin"` | 有人把 `EditorPlugin` 写进了 `blip_voice.gd`，或改了 `plugin.cfg` 的 `script` |
| `Identifier "Blips" not found` | autoload 没注册，或被改名了；检查 project.godot 的 `[autoload]` |
| `Identifier "BlipVoice" not found` | 同上，且注意 autoload **不能**叫 `BlipVoice` |
| 完全没有声音 | ① Master 总线音量 ② `gain` ③ `bus` 指向了不存在的总线 ④ 先确认底部试听面板能否出声 |
| 声音糊成一片 | `max_blips_per_second` 没设；或 `char_interval` 太小 |
| 听起来像琴键而不是说话 | `note_duration` 太大（应 ≤ 0.09） |
| 刺耳 | `lowpass_cutoff` 太高，纯方波不削高频会很尖，建议 3k~6k |
| 连续同音像机关枪 | `variants` 太小，或 `pitch_mode` 用了 `FIXED` |
| 打字机漏字/多字 | `watch()` 之后标签的 `visible_characters` 不是从 0 开始 |
| 导出后没声音、编辑器正常 | 导出预设里排除了 `addons/` 目录 |

---

## 9. 哪些东西不要动

- ❌ 不要删除 `plugin.cfg` 里的 `[plugin]` 段或 `script` 键
- ❌ 不要在游戏代码里调用 `BlipVoice.install()` / `uninstall()`
- ❌ 不要给 `install(ep)` / `uninstall(ep)` 的参数补类型标注（见第 2 节）
- ❌ 不要把参数改回独立的 `Resource` 再拆文件 —— 用户明确要求过「整合到一个文件」
- ❌ 不要把 autoload 名改成 `BlipVoice`
