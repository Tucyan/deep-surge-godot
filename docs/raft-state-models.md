# 木筏状态模型 v1 · 2026-10-13

本节取代固定 GLB 营地装饰作为游戏页的默认木筏映射。原模型保留在 assets/models 与归档中，不修改原 blend/GLB。没有对应规则的帆、箱、桶、盆栽不再常驻于游戏筏格。

| 实际状态 | 场景表现 |
|---|---|
| cells 的 id/x/y | 每格独立节点，坐标标签与木筏详情一致，间距 2.35×2.1 米 |
| intact、无设备 | 完整木板与空位标签，无虚构货物 |
| damaged | 三块断板缺口、红褐边条/修补标记，设备保留但变暗停用 |
| detached | 整格和设备节点移除，接触泡沫沿剩余格子形成缺口 |
| lamp + fuel | 提灯模型、真实燃料数字；仅完好且有燃料时发光 |
| filter | 高位过滤桶、支架、出水管和收集容器 |
| planter | 土槽与植株；只在已安装时出现 |
| medkit | 带红色十字标记的布包 |
| crossbow | 弩身、弩臂、弦与支架 |
| spearRack | 矛架和竖放的矛 |
| equipment.level | 标签级别、前端铜色标记数量 |

产物仍进入规则手牌，不画成已经获得的固定甲板货物。产出进度等详细数值继续由木筏详情提供；当前模型是类型与状态标识，不模拟作物真实生长。多个燃烧灯各有实体照明；海面暖光近似只跟随第一盏有效灯。

资产 `model.raft-state` 源为 presentation/raft_state_models.gd；纯运行时模型工厂，无视觉随机，也不访问规则命令。模型/材质和基础几何使用 VoyageWorld 缓存，单格实例按状态签名重建并释放节点引用，停用设备不销毁。模型与玩法数据分离，后续可按稳定设备 ID 换成正式模型。使用 tools/register_raft_state.py、tools/register_toon_ocean.py 更新源/hash/依赖；scene.voyage v10。镜头根据实际在位格边界缩放，空筏有安全默认范围。

本次验证：Godot 4.7.2、Compatibility、RTX 4060 Laptop GPU。

- test_raft_state_visual：六设备夹具、损坏/脱落/拆除/燃料、规则状态隔离，以及真实 install/fuel/action_card 拆除命令 PASS。
- test_clean_ui / test_mechanics / test_toon_ocean / test_fog / test_hand_fan PASS。
- check_supplied_assets：50 个 hash 绑定、原图/海面 GLB 完整。
- raft_state_visual：空筏、六设备、破损/缺格、1280×720、修复后的原生 GPU 截图，日志无 shader 编译错误。

截图 raft-state-equipment/damaged/1280/repaired 使用六格视觉夹具，不能当作实际航程获取了这些设备；raft-state-empty 是真实新局。未验证发行构建、多平台性能或刚体浮力。

## 装饰筏根 v2 · 2026-10-13

初始可见布局为 3×2：四个真实 cells 加左侧两格筏根（x=-1，y=0/1）。筏根只有篷布、木箱和盘绳，明确标注装饰区；不进入 GameState、不提供安装/生产/修补/扩建槽位，不模拟手牌物资。真实扩建只使用非负坐标，不与筏根冲突。固定筏根不因功能筏格脱落而消失。接触泡沫、浮动采样、雾清除范围与镜头包含两格筏根；功能筏格的损坏/脱落继续按真实状态同步。

model.raft-state v2 / scene.voyage v11，原源模型归档不变。test_raft_root、test_raft_state_visual、test_clean_ui、更新后的 test_toon_ocean、test_fog 通过；50 个资产 hash 检查通过，GPU 截图重新生成。

## Blender 模块版 · 2026-10-13（当前有效）

使用 Blender 5.2.2 后台建模，源为 asset-sources/raft-blender-v1/raft_modules_v001.blend；完整初始外形另导出 raft_initial_v001.glb。运行加载 assets/models/raft-modules 下的 9 个独立 GLB：完好甲板、破损甲板、装饰筏根、六种设备。Godot 只实例化模型，叠加状态标签、湿木材质、燃料照明和停用材质；不再通过 BoxMesh 等基础体构造木筏。篷布、绑绳、木桶、灯和种植盆的几何复用原 raft_v004.blend，木板、木箱、其余设备在 Blender 中建模；未覆盖原文件。

初始位置按用户指定：

```
1 装饰  2 装饰  3 可用
4 可用  5 可用  6 可用
```

真实四格仍使用 cell-0..3，坐标依次为 (2,0)、(0,1)、(1,1)、(2,1)。两装饰格只进表现层 hull，不进入 GameState；木筏详情禁用两个对应按钮，规则 expand 同样拒绝，不能通过命令占用。新局 flags.raft_layout=123456。三列范围扣除装饰后最多七个功能格；四列解锁范围最多十四个功能格，这是本次布局修订的程序设计结果，未宣称原平衡已确认。初始 1..6 标签固定按三列编号，扩展位置用坐标避免四列解锁后编号冲突。

旧四格 (0..1,0..1) 存档载入时迁移坐标，保留 ID、设备、损伤、AP 和随机状态。已扩建旧存档保留旧坐标及左侧装饰筏根，不无损迁移到新布局；开启新局使用新布局。旧坐标没有被用作玩法实验规则依据。

Blender 统一使用米，建模 Z-up，GLB 导出 Y-up。甲板每格间距 2.35×2.1m；原点在模块局部水线附近，GameState 不持有资源。合并材质批次、烘焙倒角、输出法线和 UV；不依赖导出器无法保留的 Blender 噪声材质。模型保持静态，由 Godot 控制整体浮动。原 source 可编辑，runtime GLB 可按稳定 AssetId 单独替换。

model.raft-state v3 / scene.voyage v12；59 个 hash 绑定检查通过。9 个模块合计 40290 三角形（资产总和，不是单帧绘制数），详情见 asset-sources/raft-blender-v1/glb-validation.json；最大单模块约 2 MB，以当前导出报告为准。

实际验证：test_blender_raft（布局、拒绝占用、旧存档迁移）、test_raft_root、test_raft_state_visual（真实安装/添燃料/拆除）、test_mechanics、test_flow、test_clean_ui、test_story、test_story_edges、test_toon_ocean、test_fog、test_hand_fan 全部通过。原生 GPU 1600×900 / 1280×720 检查通过；Blender 预览 blender-raft-initial.png，当前实机图 raft-state-empty/equipment/damaged/1280/repaired.png。六设备截图为视觉测试夹具。未验证发行构建或其他 GPU。

装饰灯 v002：2 号筏根在局部 x=1.82/z=-0.64 增加 Blender 灯与立柱，复用 lamp 模块几何，独立低强度暖光。装饰灯不进入 equipment，不耗燃料，不参与 SAN 航耗抵消；功能设备灯仍按真实燃料控制。源为 raft_modules_v002.blend，完整外形 raft_initial_v002.glb；v001 保留。GLB/59 hash 绑定、布局测试及两分辨率实机截图检查通过。重建 v001 后须执行 tools/add_root_lantern.py 得到 v002。

装饰灯 v003：按反馈取消立柱，灯座直接放在 2 号格木箱顶面（局部 x=1.38/z=0.32，灯座底面 y=0.82），暖光同步移动。源/完整模型分别为 raft_modules_v003.blend / raft_initial_v003.glb；v001/v002 保留。59 个资产 hash 检查通过，实机截图已复核。

帐篷 v004：仅替换 1 号格高于甲板的篷布/遮棚几何，改为低 A 字双坡帐篷；双面有厚度布面、半开入口、下垂边、补丁缝线、细支杆、系绳、床卷。2 号格木箱、桶、箱上装饰灯和四个可用格保留。源/整体预览为 raft_modules_v004.blend / raft_initial_v004.glb；更新工具 tools/refine_root_tent.py。9 个 GLB 法线/UV 与 59 hash 检查通过，Blender 预览及原生 GPU 两分辨率实机截图已检查。

## v005：三种筏格与帐篷暖灯（2026-10-13）

- Blender 源：`asset-sources/raft-blender-v1/raft_modules_v005.blend`；整筏预览：`raft_initial_v005.glb`。生成器 `tools/refine_raft_variety.py` 从 v004 读取，保留历史源。
- 三种甲板分别采用自然参差、交错端头、渐进错位；细微木板色差、粗糙度、刻痕长度与偏移使用固定美术种子 5100。完好/破损各三份 GLB，通过 `(x+2*y)%3` 稳定选型；不使用规则随机，不改变格位、安装、损坏和泡沫接触区域。
- 稳定 AssetId 为 `model.raft.module.deck-intact`、`deck-intact-2`、`deck-intact-3` 及相应 `deck-damaged` 系列。依赖与 SHA 已写入 manifest。高于甲板的帐篷与箱桶几何保留。
- 帐篷入口内复用缩小的灯笼；独立 TentLanternLight 与箱顶灯同色 #efbb79、能量 0.65，局部半径 1.75 米，Cube 阴影遮挡帐布。装饰灯不影响燃料/AP/设备状态。
- 本次验证：13 个 GLB 的 UV/法线/格式检查通过，合计 60262 资产三角面（不是单帧面数）；63 项资产 hash 检查通过；布局与筏格状态测试通过。实际 GPU 截图覆盖初始、设备、受损、修复和 1280 分辨率。

## 木板纹理 v2（2026-10-13）

`shader.raft.wet-wood` 升至 v2：在现有 Blender 木板上添加物体空间的弯曲纵向纤维、低对比宽木纹、稀疏椭圆木结、端头细裂及粗糙度变化。保留原有湿水线。纹理跟随模型运动，视觉 hash 不消耗玩法 RNG；细纤维使用屏幕导数衰减以减轻远景闪烁。默认 grain_strength=0.40、knot_strength=0.30，均为 uniform，可独立调节或关闭。

本次是 Godot 材质层细化，Blender v005 几何和 GLB 不变；无新增贴图采样、面数或绘制实例，但增加了片元着色计算。来源 `assets/shaders/wet_wood.gdshader`，登记工具 `tools/register_wood_grain.py`。实际 Compatibility GPU 渲染无错误，检查了 1600×900 与 1280×720、空格/设备/损坏/修复截图；筏格状态测试与 63 项资产 hash 检查通过。前后对照：`evidence/wood-grain-before.png`、`evidence/raft-state-empty.png`。未进行帧耗时基准测试。
