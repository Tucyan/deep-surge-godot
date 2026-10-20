# 深潮事件文本与插画来源

本目录保存 2026-10-21 用户提供的 `深潮事件文本.zip` 解压副本与联系表。压缩包 SHA-256：`0F306C4A3009966323129732A0029DA3D5A5325FAA5723467444B62BE9E4EB64`。

## 运行映射

当前挑战模式实际投放的普通事件、漂流变体、风暴货舱变体和三层 Boss 使用 `assets/manifest.json` 中的 `node.event.*` AssetId。节点规则、费用、概率、阶段和奖励以 `content/data/nodes.json` 为准。

| 运行 AssetId | 节点 | ZIP 来源 | 备注 |
|---|---|---|---|
| `node.event.salvage` | 浮标上的便笺 | 木筏货物 | 当前选项规则保留 |
| `node.event.sealed` | 封蜡死箱、深处沉箱 | 07_危险箱子 | 深处沉箱按用户决定复用 |
| `node.event.cargo` | 绳端的货箱 | 漂浮残骸 | 当前捕捞网规则保留 |
| `node.event.camp` | 灯火休整地 | 06_月下孤舟与微光灯火 | 守灯人营地 |
| `node.event.trader` | 海怪商人 | 01_船只_标准版 | 商店机制以游戏配置为准 |
| `node.event.jelly-echo` | 船底的回声 | 孤海漂泊的木筏居所 | 结果仍按游戏中的SAN/资源选项执行 |
| `node.event.rest-cove` | 避潮湾 | 海边灯塔 | 独立节点 ID，显示名仍为“灯火休整地”，选项和结果不同 |
| `node.event.ship-hold` | 海面下的货舱 | 沉船货舱中的幽蓝光束 | 分段阶段规则以游戏配置为准 |
| `node.event.lighthouse` | 漂流灯塔 | 海边灯塔 | 与避潮湾共享同一张图 |
| `node.event.predator` | 捕食者水域 | 迷雾巨兽之海 | 战斗规则以游戏配置为准 |
| `node.event.jelly` | 水母幽光 | 暮色巨型水母与孤舟 | 战斗规则以游戏配置为准 |
| `node.event.hard-shell-reef` | 硬壳暗礁 | 风暴废墟中的巨蟹巢穴 | 与哨声与甲壳共享同一张图 |
| `node.event.ruin` | 沉没遗迹 | 月下沉没遗迹之城 | 遭遇规则以游戏配置为准 |
| `node.event.lunchbox` | 尚温的饭盒 | 金属饭盒 | 当前补给结果以游戏配置为准 |
| `node.event.shared-meal` | 漂流者的午餐 | 木板上的烤鱼晚餐 | 当前材料成本与结果以游戏配置为准 |
| `node.event.workshop` | 筏匠的残台 | 暮色海上木工工坊 | 只记素材映射；池状态以游戏配置为准 |
| `node.event.crab-camp` | 哨声与甲壳 | 风暴废墟中的巨蟹巢穴 | 与硬壳暗礁共用图片文件，语义映射独立 |
| `node.event.boss-shallows` | 浅海守门者 | 05_怪物海景 | Boss 奖池以游戏配置为准 |
| `node.event.boss-open-sea` | 外海吞潮者 | image 4 | Boss 奖池以游戏配置为准 |
| `node.event.boss-abyss` | 深渊潮心 | image 2 | Boss 奖池以游戏配置为准 |

压缩包中的幽灵船、教学/剧情段落和未进入当前挑战候选池的图片保留在 `source/`，不新增到暂停中的剧情模式或活动池。`搁浅的绞盘` 与 `浪中的吊架` 继续按现行定义保留为 retired/不投放；海面下的货舱仍是有效的风暴变体。

各登记图片的运行文件路径、原图尺寸、SHA-256 和来源均记录在 `assets/manifest.json`；运行图保留原始分辨率。压缩包中未映射为当前节点的图片仍保留在来源副本，不作为当前活动内容。

