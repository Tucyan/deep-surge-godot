# 海浪环境音源记录（2026-10-20）

持续背景音「海浪」的来源与处理记录。运行字节保存在 `assets/audio/ambience/`，本目录只留来源与说明。

## 来源

全部为 **CC0 1.0**（公共领域奉献，可商用、无需署名）的录音，经 OpenGameArt 打包发布，
原始作者来自 Freesound：

| 打包页 | 作者 | 素材 | 原始 Sound |
|---|---|---|---|
| <https://opengameart.org/node/11174> Beach Ocean Waves | jasinski | 沙滩碎浪 4 条（偏亮） | <https://freesound.org/people/jasinski/sounds/18363/> |
| <https://opengameart.org/node/11175> Water Waves | transitking | 海浪冲刷 4 条（偏沉） | <https://freesound.org/people/transitking/sounds/11505/> |

下载页标注许可为 CC0；打包文件名本身带 `cc0` 前缀。

下载的 8 个 FLAC 原始文件（未改动字节）：

| 文件 | 字节 | SHA-256 |
|---|---|---|
| `wave_01_cc0-18363__jasinski__alkaibeach.flac` | 626248 | `fcfca178eca2eac536e8c2a4ed5cf8096e44c921acd587047b3d9f1d7845435c` |
| `wave_02_cc0-18363__jasinski__alkaibeach.flac` | 404529 | `53b5c28c0edc36f049e77e65f2cf8a86135103328c44c1507c416e6469d18096` |
| `wave_03_cc0-18363__jasinski__alkaibeach.flac` | 367584 | `fc795f95f352b354867d69a587daecb8815334e28e3b56a7798c5f3005349054` |
| `wave_04_cc0-18363__jasinski__alkaibeach.flac` | 591767 | `3c490e736365fdd617ce8405470d8878fc6146d9a8dba448d622addb01cfff3b` |
| `wave_01_cc0-11505__transitking__wavesound.flac` | 265335 | `0bd84b2061a82c234470bd4e16efc6ab24851928d3f93e1757bfea048b2d7a33` |
| `wave_02_cc0-11505__transitking__wavesound.flac` | 583157 | `afa112a66c4cafe06ef76d5e2d4d00a701d4520c58eef63b862afa771991d77a` |
| `wave_03_cc0-11505__transitking__wavesound.flac` | 401955 | `1657a0002367e6e97eb34fc9f4d841f4a910981450c634bdc6c09ae1978049c1` |
| `wave_04_cc0-11505__transitking__wavesound.flac` | 338969 | `6c5b59562bf9b00e77f7bd8d6550912b6326e190ce97e9b8c1a1faa887bb4fac` |

素材本身是单次浪击（1.4～3.5 秒），不是长循环，因此需要拼接成一条底噪。

## 处理

处理脚本：`tools/build_waves_ambience.py`（numpy + ffmpeg，无外部素材、无第三方音效包）。

1. 裁掉每条素材首尾静音（阈值 −55 dBFS）并加 60 ms 淡入淡出，避免拼接爆音。
2. **底噪层**：每条素材做零相位 FFT 低通（4 阶巴特沃斯，截止 700 Hz）后随机错相，
   以「素材长度 − 淡化长度」为步长铺满 48 秒，再把尾部等功率折回开头 —— 结果是严格周期、无接缝。
   八条素材错相叠加，单条的周期性互相掩蔽，听不出同一段又来了。
3. **浪头层**：按 2.4～6.0 秒的随机间隔放置 12 次浪击，随机增益（−17～−6 dB）与声像；
   跨越 48 秒边界的事件折回开头，接缝处不会出现半截浪。
4. 整体归一到 −3 dBFS 峰值（RMS 约 −17.3 dBFS），编码为 Ogg Vorbis q4。

复现命令（需要 numpy、soundfile 与 ffmpeg；游戏本身不依赖这些）：

```powershell
python tools/build_waves_ambience.py --fetch --cache .cache/ocean-waves
```

固定随机种子（20261020），同一 numpy 与 ffmpeg 版本下可复现相同字节；换版本可能得到不同字节，
此时重新登记即可（`register_ambience.py` 会递增版本号）。

## 运行映射

| AssetId | 运行文件 | 字节 | SHA-256 | 时长 | 导入设置 |
|---|---|---|---|---|---|
| `audio.ambience.waves-loop` | `assets/audio/ambience/waves-loop-v1.ogg` | 624727 | `ffd8d2621aa94d2c3f9a1c0949fca17277e777947733112abbe3da18de22686d` | 48.000 秒 | ogg 导入器，`loop=true` |

循环在导入参数与运行时各设一次（`ambience_director.gd` 加载后仍写 `loop=true`）。
底噪本身是采样级无缝的；Vorbis 编码会带来约 1.4 ms 的解码前导，实测循环接缝处的样本差为 0.005。

## 登记与校验

```powershell
python tools/register_ambience.py
```

脚本按当前文件重算 SHA-256；同名条目已存在时递增版本而不是新增重复 AssetId。

行为契约见 [背景音乐与音频](../../docs/audio-and-music.md)，测试入口 `tests/test_ambience_director.gd`。
