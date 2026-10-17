# 卡高/阴影/数量与叠层实验（2026-10-17）

## 正式应用

- 航行/战斗卡牌区上沿对齐顶栏下沿，不把顶栏计入高度。HandFan 卡高=区域高×0.97，普通卡上下居中各留1.5%，保持比例；悬停/选中抬起及真实命中逻辑继续使用同一缩放。
- ItemCard 原生柔和阴影：alpha 0.28、shadow_size 7、偏移(1,5)，与卡牌共同缩放。
- 数量仅为浅色文字 `×N`、深色outline_size=3，不创建数量底板或外框。原卡数量、叠牌规则及费用不变。

## 实际验证

- GPU `tests/nautical_hud_visual.gd`：先运行新增断言，旧代码按预期失败；修改后 `NAUTICAL HUD: PASS`。四种分辨率、100%/125% UI，验证卡牌/底板高度比0.97、阴影存在、数量无StyleBox底板且有描边、布局与真实点击、耗尽禁用和RNG不变。卡牌顶栏固定厚度回归通过。
- headless `tests/test_hand_fan.gd`：`HAND FAN: PASS`，连续手牌、少/多卡、悬停、动画、命中与状态不变。
- headless `tests/test_hand_gestures.gd`：`HAND GESTURES: PASS`，拖动/取消等原交互回归。
- GPU `tests/test_battle_panel_art.gd`：`BATTLE PANEL ART: PASS`，六组分辨率/UI组合。
- GPU `experiments/card_stack_v1/preview.gd`：`STACK EXPERIMENT: PASS`，两个后方装饰层、97%高度，session快照不变。

均使用 Godot 4.7.2、Compatibility（GPU项为RTX4060 Laptop）；未导出APK、未做手机实机验证。没有改变规则或存档版本。

## 预览

正式截图 `nautical-hud-1600x900-100.png` 和 `nautical-hud-1280x720-125.png` 不含额外卡层。

独立实验 `card-stack-experiment-comparison.png`：A整齐错层，B轻微扇开。其资源数量为纯显示夹具，正式入口没有加载实验脚本；背后卡框不参与命中或命令。

## 叠层边界增强

用户反馈层间边界不明显后，仅调整实验脚本：横向错层7像素、后层分级压暗、每层独立深色接触阴影，以及30像素组间距。新输出 `card-stack-experiment-boundaries.png`，原截图保留。再次运行 Godot 4.7.2 GPU 预览，退出码0、`STACK EXPERIMENT: PASS`，并已检查渲染图。正式页面、正式卡牌大小/阴影/无底板数量样式不变。

## 高光交界修订

用户反馈层间阴影过重：移除实验seam的shadow_size=4/alpha0.8，改为无层间阴影；后层明度恢复0.92～1.0，每层上/右边界绘制1逻辑像素的暖金色高光。保留7像素错层和组间距。实际GPU脚本退出码0、`STACK EXPERIMENT: PASS`，已核对 `card-stack-experiment-highlights.png`；正式表现脚本未修改。

2026-10-17 当前高光改为纯白色（alpha=1），线宽由1加粗为2逻辑像素。预览输出 `evidence/card-stack-experiment-white-highlights.png`；GPU脚本 `STACK EXPERIMENT: PASS`，截图已核对。仅实验叠层变动。

2026-10-17 当前版本恢复阴影交界，移除白色高光。层间阴影alpha由此前0.8降至0.25，shadow_size从4缩小至2；后层仅轻微压暗。新预览 `evidence/card-stack-experiment-soft-shadow.png`，GPU实际运行 `STACK EXPERIMENT: PASS`，截图已核对。仍仅修改实验入口。

2026-10-17 数量文字加粗：正式卡面使用字重800的系统粗体，字号19→20，深色描边3→5逻辑像素；保留浅色填充且无底板。当前叠层实验输出 `evidence/card-stack-experiment-bold-quantity.png`，沿用25%淡阴影，叠层仍未接入正式页面。GPU预览 `STACK EXPERIMENT: PASS`，正式多尺寸与点击验证 `NAUTICAL HUD: PASS`。

2026-10-17 数量文字再放大：当前字号23、描边6逻辑像素，字重800；文字区域略向左扩展，保持无底板。当前实验预览 `evidence/card-stack-experiment-larger-quantity.png`，GPU `STACK EXPERIMENT: PASS` / `NAUTICAL HUD: PASS`，已核对实际渲染。
