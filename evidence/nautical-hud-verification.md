# 航海 HUD 与行动点素材验证（2026-10-17）

在当前工作区执行，Godot 4.7.2、Compatibility、RTX 4060 Laptop GPU。此次只改表现，不改核心规则或内容版本。

## 已执行

- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import --quit`：退出码 0，新图导入完成。
- `Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/nautical_hud_visual.gd`：GPU 实际渲染；四种分辨率 1280×720、1600×900、1920×1080、1920×820，100%/125% UI；宽屏使用自由比例。验证边界、航次/数值不重叠、操作框避开手牌、纹理保持有效、卡牌在底板上方、真实属性绑定及绘制不修改 session/RNG。原生鼠标验证设置、合成、打捞扣 AP、AP 耗尽禁用。
- 固定窗口高 720，宽度 1280/1600/1920：100% UI 顶栏均为 44.800018px，125% 均为 56px；纵向比例为 1.25，窗口宽度变化不改变厚度。代码固定高为 56 逻辑像素。
- `Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/test_battle_panel_art.gd`：`BATTLE PANEL ART: PASS`；六组分辨率/UI 组合，四个面板、边界和手牌避让。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_clean_ui.gd`：`CLEAN HUD: PASS`。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_ui_layout_controls.gd`：`UI LAYOUT CONTROLS: PASS`。首次运行在旧“开始航程”名称处数组越界，已停止该进程；测试改为当前实际“选择难度 → 选择起手资源”流程后通过，没有修改新局产品逻辑。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_salvage_ui.gd`：`SALVAGE UI: PASS`。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_hand_fan.gd`：`HAND FAN: PASS`。
- `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_routes.gd`：13 条挑战/剧情路线覆盖三档难度与存档重放，`ROUTES: PASS`。
- `node --test tests/content.test.mjs tests/node_content.test.mjs`：15/15 通过。

上述既有 UI/战斗/路线测试在新行动点图接入前执行；最终行动点接入由 `nautical_hud_visual.gd` 再次验证。夜间标题与 2/5 圆珠截图为表现层夹具，验证其不修改 session。未做 APK 导出或手机实机验证。

## 资产检查限制

`python tools/check_supplied_assets.py` 仍因 `ui.item-card` hash 不匹配失败。完整只读扫描得到六个旧不匹配：`ui.item-card`、`ui.craft.grid`、`ui.hand.layout`、`ui.hand.stack-quantity`、`data.difficulties`、`rules.difficulty`；与既有 `ui-main-project-migration-verification.md` 记录相同。本次不覆盖这些旧登记，不宣称全量资产校验通过。本次新增及直接修改文件的登记由 `register_nautical_hud.py` 更新并单独核对。

## 截图

最终行动点版本再次运行 `nautical_hud_visual.gd`，`NAUTICAL HUD: PASS`；逐项核对本次涉及的 17 个绑定，`NAUTICAL ASSET INTEGRITY: PASS`。`git -c core.whitespace=cr-at-eol diff --check` 退出码 0（按 Windows 行尾检查）。

- `nautical-hud-1600x900-100.png`：当前真实导航界面。
- `nautical-hud-1280x720-125.png`：小屏放大 UI。
- 其余六张 `nautical-hud-*.png`：完整适配矩阵。
- `nautical-ap-night-preview.png`：夜间标题及 2/5 圆珠只读夹具。

未提交、推送或修改用户全局工具配置。

## 同日追加：行动点左对齐、70%底板和固定进度条

- 行动点组件水平偏移由 8 改为 0，与卡牌顶栏最左边缘对齐。
- 白色填充 alpha=0.7，边框/角饰及卡牌不跟随透明化。
- 四项进度条固定 72 逻辑像素。根据四等分单元实际可用宽度与最大数值文本宽度决定是否整组隐藏；紧凑模式仍显示真实当前值/上限。
- `nautical_hud_visual.gd` 增加布局回归：600 宽状态区域隐藏全部轨道，800/1100 宽区域四条轨道均为72；数值均在范围内；行动点水平对齐及底板alpha检查通过。首次运行按预期失败，修改后 `NAUTICAL HUD: PASS`；多尺寸GPU截图与真实点击验证再次通过。
- 当前 `nautical-hud-1600x900-100.png` 展示固定长度轨道，`nautical-hud-1280x720-125.png` 展示无轨道的紧凑数值模式。

## 同日追加：卡面精简

去掉左上类别角标和动作副标题，卡名上移卡高5%。实际 GPU `nautical_hud_visual.gd` 再次通过，截图已核对；`test_hand_fan.gd` 为 `HAND FAN: PASS`。本次直接修改 `item_card.gd`，其对应 `ui.item-card` 和 `ui.hand.stack-quantity` 两项哈希及版本同步更新；此前六项旧不匹配中这两项现已随实际修改重新登记，剩余四项未覆盖。
