# UI 组件迁入主工程（2026-10-17）

## 当前运行路径

| 内容 | 迁移后路径 |
|---|---|
| 状态、行动点、事件选择控件及脚本 UID | `presentation/hud/` |
| 五张 HUD PNG 及导入配置 | `assets/ui/hud/` |
| 可缩放按钮场景 | `scenes/ui/tarot_button.tscn` |
| 按钮的 PNG/SVG 及导入配置 | `assets/ui/buttons/` |

共迁移原 `addons/` 下 37 个文件；原目录已删除。当前页面直接加载主工程脚本。`asset-sources/` 中被 `.gdignore` 排除的原始包和插件示例保留为来源证据，其中的旧路径不属于当前运行引用。

`pages/voyage_hud.gd`、控件预加载、按钮场景纹理引用、导入配置、`tools/register_supplied_hud.py` 及 manifest 的运行路径已同步。保留已有 HUD AssetId，更新版本、源路径和 SHA-256；原来未登记的按钮场景及十张 PNG/SVG 新登记为 `ui.buttons.tarot`、`texture.ui.tarot.*`。按钮素材的上游来源和许可证在已有工程中未记录，清单如实注明，仅以迁移前项目路径追溯。该按钮场景仍为保留的可复用组件，当前游戏页面未实例化它。

## 本次实际验证

- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import`：退出码 0，新目录图片重新导入完成。
- `Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_clean_ui.gd`：RTX 4060 Laptop GPU / Compatibility，`CLEAN HUD: PASS`，退出码 0。
- 临时资源加载脚本（`$env:TEMP/deep-surge-migrated-ui-smoke.gd`），使用 `--headless --path . --script` 实际运行：依次实例化三个迁移后的 HUD 控件和按钮场景，检查按钮四态 StyleBoxTexture 及罗盘纹理，`MIGRATED UI RESOURCE LOAD: PASS`，退出码 0。
- 迁移前后文件校验：22 个源文件/脚本 UID 均存在于新位置；全部 15 张 PNG/SVG 的内容 hash 及三个脚本 UID 与迁移前相同。控件脚本和场景只调整资源路径，导入配置由 Godot 更新。
- 23 个迁移涉及的 manifest 条目（HUD、纹理、按钮场景、按钮图片及同文件的航行 HUD 登记）均匹配当前文件 hash；没有新增资产 hash 不匹配。
- 当前 `pages/`、`presentation/`、`scenes/`、`tools/` 和图片导入配置中没有 `res://addons/` 运行引用。

## 既有全量清单问题

迁移前执行 `python tools/check_supplied_assets.py` 即失败于 `ui.item-card` 的 hash 不匹配。完整只读扫描发现当时有 10 个不匹配条目。本次更新直接修改的航行 HUD 文件所对应的 4 个登记后，剩余 6 个既有不匹配为：`ui.item-card`、`ui.craft.grid`、`ui.hand.layout`、`ui.hand.stack-quantity`、`data.difficulties`、`rules.difficulty`。未以本次迁移覆盖这些条目的源信息；不能将全量资产校验记录为通过。

本次只整理 UI 文件归属和资源引用，未修改玩法规则；未运行完整路线或规则专项回归。工作区已有修改保留，未提交或推送。
