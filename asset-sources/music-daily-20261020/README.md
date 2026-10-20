# 日常背景音乐源记录（2026-10-20）

用户通过微信提供两个压缩包，本目录记录来源与运行映射；运行字节保存在 `assets/music/`，源包不再复制一份。

## 来源

| 压缩包 | 内含音频 | 处理 |
|---|---|---|
| `日常背景音乐(1).zip`（27,049,362 字节） | 2 个 MP3 | 解压后仅重命名为稳定运行名，音频字节未转码、未裁剪、未做响度处理 |
| `boss配乐(1).zip`（176 字节） | 无（压缩包内只有空目录 `boss配乐/`） | 未导入；`music.json` 的 `boss` cue 暂为空并回退到 `voyage` |

原始文件名：

- `Quartetto Chitarristico Ars Nova Johann Sebastian Bach - Cantata Ich Habe Genug BWV82 Aria.mp3`
- `Quartetto Chitarristico Ars Nova Johann Sebastian Bach - Fuga BWV578.mp3`

两首均为巴赫作品（BWV82 咏叹调、BWV578 赋格）的吉他四重奏改编版本，演奏者为 Quartetto Chitarristico Ars Nova。用户提供，未附加许可声明；对外分发前需自行确认授权范围。

## 运行映射

| AssetId | 运行文件 | 字节 | SHA-256 | 时长 | 导入设置 |
|---|---|---|---|---|---|
| `audio.music.daily-aria` | `assets/music/daily-arsnova-bwv82-aria-v1.mp3` | 18,321,578 | `3335b22420d03ad2edb06303fb6971064752bcf81f0bf285b10a78ecde8a574a` | 444.653 秒 | mp3 导入器，`loop=true` |
| `audio.music.daily-fuga` | `assets/music/daily-arsnova-bwv578-fuga-v1.mp3` | 8,727,278 | `1d7efbb8234298530e066a9d33ebc0636ce9afca880efdd98126a3d3fe28a1ec` | 204.800 秒 | mp3 导入器，`loop=true` |

时长取自导入后的 `AudioStreamMP3.get_length()`，不是按文件大小估算。循环在导入参数与运行时各设一次（`music_director.gd` 加载后仍写 `loop=true`），MP3 无采样级无缝接缝，接缝处为整段重播。

## 登记与校验

```powershell
python tools/register_music.py
```

脚本按当前文件重算 SHA-256；同名条目已存在时递增版本而不是新增重复 AssetId。cue 表 `data.music.cues`、导演 `ui.music-director` 与设置入口 `ui.settings-panel` 的 hash 走同一命令。

行为契约见 [音乐与音频](../docs/audio-and-music.md)，测试入口 `tests/test_music_director.gd`。
