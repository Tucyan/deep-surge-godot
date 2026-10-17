# 正式叠牌与两种悬停验证（2026-10-17）

## 当前行为

正式资源叠牌使用最多两张向左露出的装饰后层，淡阴影alpha0.25、范围2、无额外高光。主卡在右上方；悬停只抬主卡，后层独立留在桌面。数量在主卡左侧，沿用23号/800字重、6像素深色描边和浅色填充，无底板。

设置 → 游戏偏好 → 手牌悬停方式：默认“排开遮挡”，另一选项“图层上浮”。前者沿用>=5%有效重叠才让位的政策并计入后层左伸部分，后者只提主卡绘制层，邻牌横向不动。偏好写入原hand-layout.cfg；旧配置或非法值回退spread。游戏存档/schema/随机流、资源合并阈值和容量未改。

后层命中归属同一叠牌代表UID，不创建规则卡牌；绘制与点击采用相同层级/组顺序。拖动排序同步主卡和后层目标槽位；悬停/后层位置保留在只用于UI重建的表现快照，不进入规则存档。

## 实际执行

Godot 4.7.2；GPU项使用Compatibility/RTX4060 Laptop。以下脚本均在本工程根目录运行，退出码0：

| 命令（Godot参数） | 结果 |
|---|---|
| `--headless --path . --script res://tests/test_hand_stack_hover.gd` | HAND STACK HOVER: PASS |
| `--path . --script res://tests/hand_stack_visual.gd` | HAND STACK GPU: PASS |
| `--headless --path . --script res://tests/test_hand_layout.gd` | HAND LAYOUT: PASS |
| `--headless --path . --script res://tests/test_hand_fan.gd` | HAND FAN: PASS |
| `--headless --path . --script res://tests/test_hand_gestures.gd` | HAND GESTURES: PASS |
| `--headless --path . --script res://tests/test_hand_click.gd` | HAND CLICK CONTINUITY: PASS |
| `--headless --path . --script res://tests/test_ui_layout_controls.gd` | UI LAYOUT CONTROLS: PASS |
| `--headless --path . --script res://tests/test_clean_ui.gd` | CLEAN HUD: PASS |
| `--path . --script res://tests/test_battle_panel_art.gd` | BATTLE PANEL ART: PASS |
| `--path . --script res://tests/nautical_hud_visual.gd` | NAUTICAL HUD: PASS |

专项覆盖：悬停只有主卡移动、后层位置不变、左右绘制/命中、两种模式行为、原生鼠标点击代表UID、拖动目标同步、UI重建动画接续、偏好保存重读和非法值回退、设置选项实际绑定；前后session快照相同。

先写回归并观察旧代码因缺少偏好/后层而失败。独立静态审查又发现拖动后层换槽漏同步、让位漏算后层左伸两项P2；新增用例复现，修复后通过并经只读复查确认。GPU外框检查复现了小屏设置面板越界，收紧短屏行距/内边距后完整面板边界通过。

GPU专项覆盖1600×900/100%和1280×720/125%，含两模式休止/悬停及设置。已查看两种悬停模式及窄屏设置的实际截图；密集手牌的24/10为明确的超限显示夹具，不是正常起手资源或新收益。战斗四面板GPU另覆盖六组分辨率/UI组合；通用HUD矩阵覆盖四种分辨率及100%/125%。本次未运行完整规则路线或APK/手机实机验证。

## 图像

- `hand-stack-rest-1600-spread.png`：正式整齐错层，向左露出。
- `hand-stack-hover-1600-spread.png` / `hand-stack-hover-1600-raise.png`：只有主卡浮动，两种模式。
- `hand-stack-hover-1280-spread.png` / `hand-stack-hover-1280-raise.png`：窄屏密集手牌。
- `hand-stack-settings-1600.png` / `hand-stack-settings-1280.png`：新增设置和完整面板边界。

## 资产及边界

`ui.hand.stack-backplate`及此次修改的五类既有绑定（fan/layout/item-card/quantity/settings）均核对当前SHA-256和依赖，STACK ASSET INTEGRITY: PASS（6项）。全量只读扫描仍有三个既有不匹配：ui.craft.grid、data.difficulties、rules.difficulty；未覆盖其源信息或宣称全量资产检查通过。此前hand.layout既有登记随本次实际修改更新。

没有新增图片资产、改变全局工具配置或提交/推送。
