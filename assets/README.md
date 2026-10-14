# 素材登记

当前使用scene.voyage v8：默认风格化冷夜海面，远雾使用低饱和灰青/灰绿，与深蓝海水区分。三层雾原高度保留，近筏透明区随真实筏格范围同步，镜头拉远时过渡宽度跟随缩放。

| AssetId | 源 / 映射 / 依赖 |
| --- | --- |
| data.ocean.toon-config v2 | assets/data/toon-ocean.json；原波形/色板/泡沫/月光/灯笼/调色保持，雾色/过渡/漂移参数更新，hash清单登记 |
| shader.ocean.toon v1 | assets/shaders/toon_ocean.gdshader；Gerstner位移与presentation/toon_ocean.gd同公式；程序噪声/Voronoi，无外部图片、屏幕或深度采样；依赖data.ocean.toon-config |
| shader.voyage.night-grade v1 | assets/shaders/night_grade.gdshader；航行SubViewportContainer画布调色（降饱和、冷色、暗角），不作用于HUD |
| shader.voyage.night-mist v1 | assets/shaders/night_mist.gdshader；原三层程序噪声雾，新增clear_bounds/clear_fade近筏遮罩；依赖data.ocean.toon-config，随格变化与镜头缩放同步；无额外纹理/视口 |

近景平面/远景平面网格为toon_ocean.gd运行时生成的实例私有资源，随节点释放；视觉噪声为着色器内固定哈希，不使用规则随机。登记更新命令`python -X utf8 tools/register_toon_ocean.py`。原GLB海面相关资产保留为回退，下文为其记录。

当前使用scene.voyage v6：按用户要求恢复第一版原GLB/16姿态/尺寸/法线/UV/蓝色渐变和泡沫图集；只保留共同水线、船边柔化、局部泡沫和湿木修复。data.ocean.model-config/shader.ocean.model为v3，后者fragment与第一版一致，仅vertex加入局部接触处理。geometry.ocean.lod标记archived。v5试验代码、shader、配置保存在asset-sources/wave-style-experiment；下表与后文v5/v3等说明均为历史记录。

| v5试验历史 AssetId | 源 / 映射 / 依赖 |
| --- | --- |
| scene.voyage v5 | voyage_world + model_ocean + supplied_ocean + texture_ocean；模型、源姿态/高度/泡沫、模型配置/着色与接触材质 |
| geometry.ocean.lod v1 | model_ocean.gd；源101²顶点按stride2抽为51²，16姿态/15形变、UV/法线/切线，九块共享同一ArrayMesh；源GLB及二进制不改 |
| data.ocean.model-config v2 | assets/data/model-ocean.json；水平/高度/降面/水线柔化与暗色风格参数，hash清单登记 |
| shader.ocean.model v2 | model_ocean.gdshader；分层法线着色＋源泡沫姿态＋程序噪声分块，无屏幕/深度采样 |
| shader.ocean.stylized-far v2 | stylized_far_ocean.gdshader；与近景同底色的远景平面，无视频截图纹理 |
| shader.ocean.contact / shader.raft.wet-wood v2 | 原接触泡沫/湿木shader增加共同水线高度与倾斜；外缘布局变化才重建 |

视频源仅作为风格资料保存为`asset-sources/user-pack-20261012/waves-reference.mp4`，不是运行纹理。明暗与泡沫颜色从JSON调参，源采样、白沫形态、着色、逻辑状态分离。水线附近对源波形做平滑过渡，维持筏底浸水，属于表现近似；没有水动力或镜面倒影。登记更新命令`python -X utf8 tools/register_model_ocean.py`。

## 用户素材包（2026-10-12，模型海面为历史记录）

`card(5).zip`、`卡牌ui.zip`与`jvneiyangchengshuimian.blend`原包/源文件保存在`asset-sources/user-pack-20261012/`。该目录有`.gdignore`，避免Godot自动转换工作源或将诊断图导入运行资源；运行只加载`assets/`。源码未执行自动脚本，原blend SHA256为`2fdab0abc259fdb53d2605226152398d2599f031641a5cebacd89ab2ddd20045`，已与用户文件比较一致。

| AssetId | 应用与来源 |
| --- | --- |
| card.{wood,iron,plastic,rope,cloth,food,water,punch,lamp,filter,planter,medkit} | 直接绑定对应透明PNG；原字节、尺寸、alpha不改，清单登记hash/来源 |
| card.calm / card.lamp | 共用灯图，代表灯火余温/设备；不改变效果 |
| card.spear / card.spearRack | 共用长矛图；card.arrow / card.crossbow共用弓弩图 |
| card.repair / card.dismantle / tool.handtool | 共用工具箱图，不新增工具卡或制造门槛 |
| ui.unavailable | 原禁止工具图，用作不能执行的设备/制造按钮图标 |
| ui.card.front / ui.card.back | 原双卡PNG声明式图集区域：[90,28,654,1004] / [750,28,610,1000]；同一个源文件，不修改像素 |
| ui.card.type.combat / survival / material | 原三张徽章；用于攻击、补给、材料/设备/行动分类 |
| model.ocean | `models/supplied-ocean.glb`，10201顶点/20000三角面、基准＋15形变；4208720字节，hash `a16a45492c8d47c3184bf9d576d7f5d5122b2e41acb47033e633a7385af8a793` |
| data.ocean.config / surface | 配置与16帧XYZ采样，`assets/data/`；只供表现层，不进入GameState |
| texture.ocean.foam | 源Ocean foam属性生成404×404数据图集，4×4帧；非颜色数据，无美术裁切 |
| shader.ocean.supplied | 原蓝色渐变/泡沫阈值适配Godot；ShaderToRGB不是GLB原生功能，光照响应为近似 |
| scene.voyage v2 | `voyage_world.gd + supplied_ocean.gd`；九个55米周期拼接网格、共用Mesh与材质，实例权重同步；移除后实例资源释放 |
| ui.voyage-hud v3 | `item_card.gd / voyage_hud.gd / flow_battle.gd / widgets.gd`；正面、卡图、类别、动态费用/动作文字独立；未发现图鉴显示背面 |

原16张卡图和4张UI图均已应用，分别登记为21与5个AssetId。尸体、贝币、污染及未提供的人物/节点/剧情图继续占位。绑定明细/尺寸/hash见`image-bindings.json`、`ui-bindings.json`；外部素材来源为用户提供，不作额外授权声明。

水面源Ocean分辨率16→运行10，按源`frame/20`参数手动采样帧24～249，共16姿态；运行时10秒形变循环并在源泡沫数据间插值。源驱动器未自动执行，Blender几何节点的喷雾实例未转换，ShaderToRGB使用Godot适配着色；不是在游戏里运行Blender海洋模拟。木筏高度/倾斜来自同一波形数据的运动学近似，不称刚体浮力或精确水动力。

原始与转换后的可编辑源均保留：`ocean-original.blend`、`ocean_godot_v001.blend`。Godot实际导入/形变/UV/缓存和基准坐标已验证；多时刻画面见`evidence/supplied-ocean-contact-sheet.jpg`。完整记录见`evidence/supplied-assets-verification.md`。下文v1描述保留为历史及缺素材时的回退来源。

## 测试剧情占位 v1（2026-10-12）

新增11个稳定`story.{ST.L1.*}` AssetId，对应`content/data/story_nodes.json`的art字段。清单登记中文标签、深海纯色、空path、版本1、源`test-story-solid-label-v1`及依赖。仍由AssetCatalog缓存64×64 RGBA纯色，Widgets叠独立文字；没有外部图片、裁切或随机。后续逐事件替换图片仅修改这些清单条目，不改规则或页面。

HUD v2为教学超限手牌预留分页行；`ui.voyage-hud`资产仍对应同一代码源。新增剧情/夜间/任务面板复用主题和占位工厂，没有另建图像资源。

## 3D与HUD v1（2026-10-12）

| AssetId | 源与运行映射 | 版本/依赖 |
| --- | --- | --- |
| model.raft | assets/models/raft.glb；复制自raft-model/raft.glb；AssetCatalog.model→CampDecoration | v1，SHA256 822d7c0da07c14e4f5b3515b1aab098c8de0bc3cf0ad0ced884a54a0787e7613；9网格/102446三角面源模型，嵌入纹理；原Deck在运行时隐藏 |
| scene.voyage | presentation/voyage_world.gd | v1，独立SubViewport/相机/光/雾；cells生成在位格/设备标志，模型装饰不计槽位；视觉time与规则RNG隔离 |
| shader.ocean | assets/shaders/ocean.gdshader | v1，110m平面、200×200细分；visual_time/deep_color/crest_color uniforms，无源码替换或截图纹理 |
| ui.voyage-hud | pages/voyage_hud.gd、presentation/widgets.gd | v1，深海/铜金主题、固定区布局、属性条、单排卡与分页；无新增外部图片 |

逻辑筏格板、设备占位、礁石与目标标志都属于程序化资产源，不作为未登记装饰忽略。缓存按geometry尺寸/材质颜色及稳定AssetId复用；Ocean ShaderMaterial为该世界实例私有，节点移除清理实例引用。仅复用已有GLB，未修改Blender源/Unity配置，未下载资产或调用网络建模。

下文2D占位清单仍有效。新增正式卡图时仅改图片清单，HUD避免重复文字，不把图像对象加入规则状态。

版本 `procedural-solid-label-v1`，2026-10-12。占位由 `presentation/asset_catalog.gd` 使用 Image.create(64,64,RGBA8) + fill 创建，无随机；`presentation/widgets.gd` 叠加独立文字。二者均为程序化资产源，不能只登记外部图片。

| AssetId | 数量 | 映射 | 依赖 |
| --- | --- | --- | --- |
| card.{原始卡牌ID} | 22 | 图鉴、合成、设备、战斗、商店 | cards/recipes/equipment JSON |
| node.{原始节点ID} | 12 | 游戏目录、剧情、商店 | nodes JSON |
| enemy.{原始怪物ID} | 5 | 图鉴与战斗 | enemies JSON |
| relic.{原始藏品ID} | 13 | 图鉴与商店 | relics JSON |
| scene.ocean | 1 | 首页与游戏页背景占位 | 无规则依赖 |

所有 path 当前为空，source/version/color/label 已在 manifest 登记。纹理由 AssetCatalog 缓存所有；页面删除时释放控件引用，共享纹理随应用缓存释放。规则会话不持有纹理，重复导航不重新生成同 ID 纹理。当前没有视觉或规则随机。

字体使用本机 Microsoft YaHei，回退 Noto Sans CJK SC/sans-serif；不复制或分发系统字体。已验证本机中文显示，其他平台字体和发行许可证仍需单独选择。主题 StyleBox 颜色/边框/圆角由 widgets.gd 维护，版本随本资产源更新。

正式图片替换按项目 README，保持 AssetId。新增外部图片需登记来源、授权、尺寸、SHA256、裁切及依赖；当前无裁切、Shader、模型或外部美术。
## 当前纹理海面 v3（2026-10-12）

本节优先于下文历史模型海面和程序海面说明。原ZIP、Blender源、派生GLB/高度数据保留且继续做完整性测试；当前运行场景只加载以下纹理海面组件。

| AssetId | 源 / 映射 | 依赖与替换 |
| --- | --- | --- |
| scene.voyage v3 | `presentation/voyage_world.gd` + `texture_ocean.gd`；独立3D视口与只读筏格投影 | model.raft、下列纹理/config/shader；不依赖model.ocean |
| texture.ocean.ripples v1 | `tools/generate_texture_ocean.py` → `textures/ocean-ripples-v1.png`，512×512 RGBA | 周期法线RGB与高度A；同一纹理两次UV采样，PNG可独立替换 |
| texture.ocean.contact-foam v1 | 同一脚本 → `textures/ocean-contact-foam-v1.png`，256×256 RGBA | 周期噪声；仅用于外缘合并网格 |
| data.ocean.texture-config v2 | `data/texture-ocean.json` | 色彩、流速、图案尺度、法线强度、格间距、泡沫宽度/透明度、浮动幅度 |
| shader.ocean.texture v1 | `shaders/texture_ocean.gdshader` | 一个两三角形平面，无透明/屏幕/深度采样、无形变 |
| shader.ocean.contact v1 | `shaders/contact_foam.gdshader` | 泡沫/接触暗部；每条外缘两三角形，只有一个材质与一个draw surface |
| shader.raft.wet-wood v1 | `shaders/wet_wood.gdshader` | 真实筏格木板/梁，按世界水线渐变；材质按木色缓存 |

视觉种子20261012，NumPy PCG64与FFT生成周期信号，不依赖规则RNG。尺寸/hash/裁切与源版本登记在manifest。无外部图片下载、无源图片修改。参考思路：[双层UV滚动](https://github.com/immaculate-lift-studio/Godot-Ocean-Shader)、[局部泡沫遮罩](https://github.com/taillight-games/godot-4-pixelated-water-shader)；本项目独立编写shader和程序纹理，未复制示例源码或示例素材。

海面/泡沫节点实例共享各自纹理与材质；只有占用布局变化重建接触网格，原mesh释放引用。泡沫在水面高度0.006米，随真实在位筏格更新，破损格仍有接触、脱落格移除；内部共享边不绘制，洞口边保留。无额外摄像机、粒子、CPU逐点波形采样；首页暂停更新。木筏运动学浮动不称物理浮力，泡沫不称真实流体碰撞，灯光阴影不称镜面倒影。

重新生成：`python -X utf8 tools/generate_texture_ocean.py`。此工具重新登记生成内容的hash；手工改配置后需同步manifest的hash，避免重新生成覆盖自己的调参。GPU与规则验证见`evidence/texture-ocean-verification.md`。

配置v2按用户反馈放大视觉浪纹：pattern_scale从0.28减至0.12（图案约2.33倍），normal_strength从0.65增至1.8；两层流速增至[0.020,0.014]/[-0.016,0.023]，浪纹亮色改为#315c69。仍是纹理法线表现，不新增顶点位移、采样或网格；木筏和接触泡沫参数保持原值。

## 当前 Toon 海面细节 v1（2026-10-13）

本节为当前运行映射，优先于历史纹理平面说明。默认仍为 Toon/Gerstner 海面；新增 `texture.ocean.detail` → `assets/textures/ocean-detail-v1.png`，256×256 RGBA，139879 字节。R 为断续流纹，G 为泡沫孔洞/水色噪声，BA 为微法线坡度；alpha 是数据，关闭 alpha border 修复，开启 mipmap，shader 使用 repeat/linear_mipmap。替换图必须遵守通道含义。

源为 `tools/generate_ocean_detail.py`，NumPy PCG64 视觉种子 20261013；周期 FFT 数学信号，不使用玩法 RNG 或外部图片。hash、尺寸、来源、通道和依赖登记在 manifest。`data.ocean.toon-config` v3 / `shader.ocean.toon` v2 / `scene.voyage` v9。先生成纹理，再运行 `tools/register_toon_ocean.py` 登记配置及 shader。

`toon-ocean.json` 的 raft_motion 段设置木筏姿态坡度与高度的时间平滑；坡度采用连续软饱和，避免硬截断造成角加速度突变。detail 段控制开关/尺度/流纹/孔洞/细丝/微法线强度/淡出距离。两次采样直接加入原海面材质，不增加网格或透明层；纹理由 AssetCatalog / ResourceLoader 缓存，近远海材质共享纹理引用，材质由海面实例持有。水面大色阶使用原法线，细法线仅影响月光与灯光反射；接触泡沫在孔洞处理后合成。细节距离随镜头缩放，mipmap 减少远处采样锯齿。验证见 `evidence/ocean-detail-verification.md`。

## 手牌底板与展开交互（2026-10-13）

`ui.hand.fan`（presentation/hand_fan.gd）用于航行和战斗手牌：全部实例同排显示，不分页、不滚动，按可用宽度重叠；鼠标经过时局部展开并抬起，停留 0.35 秒显示真实卡牌描述和阶段使用说明。命令通过 UID 发给页面，hover 不修改规则状态。不可弃置牌和战斗 AP 不足仍禁用操作；空白处点击不执行。

`shader.ui.hand-glass` 独立屏幕 mipmap 模糊 shader，带可配置 tint / blur_lod；`ui.hand.border` 独立程序绘制铜金双线、绳纹刻痕与铆钉角饰。装饰公式确定，不使用玩法 RNG；材质归底板实例持有，shader 和卡图由资源缓存共享。用户卡牌图片未重绘。通过 tools/register_hand_ui.py 更新源/hash/依赖。

验证：test_hand_fan、test_clean_ui、test_flow、test_supplied_assets 全部通过；49 个资产 hash 检查通过。test_hand_fan 使用 24 张超限夹具验证两种窗口尺寸、首中尾悬停、说明边界、真实鼠标事件点击 UID 和状态隔离。GPU Compatibility / RTX 4060 实拍 normal / many / hover / 1280 见 evidence/hand-*.png；20 张画面为 UI 夹具，不代表规则允许无限保留手牌。未进行多平台 GPU 性能测试。

每块毛玻璃底板使用局部 BackBufferCopy（24px 模糊边距），保证战斗弹窗采样自己的背景；弹窗遮罩/内容分别位于 z=200/201，底层抬起的手牌不会穿透遮罩。战斗 13 张手牌夹具实机图为 evidence/hand-battle-1280.png。

## 当前木筏状态模型 v1（2026-10-13）

游戏页改为 `model.raft-state`（presentation/raft_state_models.gd）按 cells/设备实例生成，无固定帆/货箱/植物装饰。六种设备分别建模；损坏保留停用设备并断板，脱落移除整格；灯的发光/暖光严格跟随完好状态与燃料。原 GLB 保留作历史源。坐标、状态与木筏详情一一对应。源/hash/依赖通过 tools/register_raft_state.py + tools/register_toon_ocean.py 登记；scene.voyage v10。映射、资源所有权和验证见 docs/raft-state-models.md。

木筏 v2：初始 3×2 中两格是左侧装饰筏根，四格为逻辑筏格；装饰不进入 GameState，水线/泡沫/雾/镜头包含筏根。model.raft-state v2，scene.voyage v11。详见 docs/raft-state-models.md。

## Blender 木筏模块（当前默认）

model.raft.module.deck-intact / deck-damaged / root-decor / lamp / filter / planter / medkit / crossbow / spearRack 分别映射同名 GLB，源为 asset-sources/raft-blender-v1/raft_modules_v001.blend。倒角、UV、法线及 PBR 基色在 Blender 中完成，湿木、发光开关和状态标签归运行时。每个 GLB 的 hash、来源、单位、依赖登记于 manifest，实例共享源网格，状态私有材质按 source+状态缓存。重新建模使用 tools/build_blender_raft.py（本机 Blender），再执行 register_blender_raft.py / register_raft_state.py / register_toon_ocean.py；check_blender_raft.py 检查导出完整性。原文件保持不变，不重新生成或覆盖原木筏源。


## HUD Visual Match v2（2026-10-13）

当前使用用户提供的 `deep_surge_hud_godot4_v2_visual_match.zip`。三个 HUD 控件/页面适配记录更新至 v2，新增五个 `texture.hud.*` AssetId，PNG 尺寸/hash/来源/依赖及事件图切片区域登记在 manifest；原包与原始工程保存在 `asset-sources/hud-visual-v2/`。运行控件保持状态与美术解耦，事件为按需原生按钮。布局、缩放与本次验证见 `docs/supplied-hud.md` 的 v2 节。

## 首页素材 v2（2026-10-14）

13张用户PNG、2×MP4派生的静音OGV和首帧poster已接入，独立shade多边形位于动态背景与菜单之间。稳定AssetId、源/hash/尺寸/依赖及shade参数由tools/register_title_ui.py登记。原包和2×/4×原视频归档于asset-sources/title-ui-v2，不使用个人绝对路径运行。布局和入口映射见docs/title-ui.md。
