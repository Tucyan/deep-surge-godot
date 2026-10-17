# 资源叠牌视觉实验 v1

独立GPU预览：

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://experiments/card_stack_v1/preview.gd
```

输出 `evidence/card-stack-experiment-comparison.png`：上排A为两张背后卡框整齐错位，下排B为两张卡框轻微旋转。只有已有资源叠牌增加后方装饰层；单张淡水不增加。使用当前正式的97%卡高、底部阴影和纯描边数量文字。

预览输入是本脚本内的显示夹具：木头8、废铁4、绳索6、塑料5、布条4、淡水1。它们只传给 HandFan 作为视觉数据，不写入 session.state；前后快照完全相同。不要将其解释为玩家初始库存。

当前正式页面没有引用此目录，叠层方案尚未应用到游戏。正式变化仅为大小、阴影和数量文字。

## 边界增强版（2026-10-17）

当前入口输出 `evidence/card-stack-experiment-boundaries.png`，之前的 `card-stack-experiment-comparison.png` 保留供对比。层间横向偏移由4增至7逻辑像素；后两层使用不同明度，并在每层前加入深色细边/接触阴影。组间额外保留30逻辑像素间距，避免相邻卡堆露出的后层互相覆盖。A/B旋转方案不变。GPU实际运行 `STACK EXPERIMENT: PASS`，已目视核对新截图，session快照不变；修改仅在本实验目录。

## 高光交界版（2026-10-17，当前）

当前预览输出 `evidence/card-stack-experiment-highlights.png`。撤掉实验卡层间的重阴影，后层恢复接近原图的明度；在每层上边、右边叠加细窄暖金色高光，强调交界。正式单卡的底部阴影未改。GPU再次运行 `STACK EXPERIMENT: PASS`，已检查截图；仍只有实验入口加载。

2026-10-17 当前高光改为纯白色（alpha=1），线宽由1加粗为2逻辑像素。预览输出 `evidence/card-stack-experiment-white-highlights.png`；GPU脚本 `STACK EXPERIMENT: PASS`，截图已核对。仅实验叠层变动。

2026-10-17 当前版本恢复阴影交界，移除白色高光。层间阴影alpha由此前0.8降至0.25，shadow_size从4缩小至2；后层仅轻微压暗。新预览 `evidence/card-stack-experiment-soft-shadow.png`，GPU实际运行 `STACK EXPERIMENT: PASS`，截图已核对。仍仅修改实验入口。

2026-10-17 数量文字加粗：正式卡面使用字重800的系统粗体，字号19→20，深色描边3→5逻辑像素；保留浅色填充且无底板。当前叠层实验输出 `evidence/card-stack-experiment-bold-quantity.png`，沿用25%淡阴影，叠层仍未接入正式页面。GPU预览 `STACK EXPERIMENT: PASS`，正式多尺寸与点击验证 `NAUTICAL HUD: PASS`。

2026-10-17 数量文字再放大：当前字号23、描边6逻辑像素，字重800；文字区域略向左扩展，保持无底板。当前实验预览 `evidence/card-stack-experiment-larger-quantity.png`，GPU `STACK EXPERIMENT: PASS` / `NAUTICAL HUD: PASS`，已核对实际渲染。

2026-10-17：正式游戏已另行实现淡阴影整齐错层，向左露出后层，并支持单张主卡悬停与两种模式。本目录继续保留历史向右错层的A/B对比，正式行为以 `presentation/card_stack.gd` 和当前手牌文档为准。
