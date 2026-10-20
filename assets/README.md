# 素材登记

2026-10-20 新增日常背景音乐 `audio.music.daily-aria`、`audio.music.daily-fuga` v1，以及 cue 表 `data.music.cues`、导演 `ui.music-director`。两首 MP3 为用户微信提供的巴赫吉他四重奏改编（BWV82 咏叹调 444.653 秒、BWV578 赋格 204.800 秒），字节未转码，仅重命名为稳定运行名；导入参数 `loop=true`。用户提供的 `boss配乐(1).zip` 内只有空目录，Boss cue 暂为空并回退航行曲目，登记时留空而非伪造占位音频。`ui.modal-layout`、`ui.settings-panel`、`ui.display-preferences` 同步版本与 hash（音乐开关与音量滑条）。来源与时长见[音乐源记录](../asset-sources/music-daily-20261020/README.md)，契约见[背景音乐](../docs/audio-and-music.md)，登记命令 `python tools/register_music.py`。

图鉴所有类别的未发现条目统一使用用户提供的透明问号宝箱图 `ui.encyclopedia.unknown` v1（1254×1254），网格缩略图与右侧详情共用，按原比例显示；原始 PNG 字节不变。运行文件为 `assets/ui/encyclopedia-unknown-v1.png`，来源、SHA-256、依赖与映射登记在 manifest。右侧详情底色为象牙白 `#F6EBDA`，标题与正文使用深色。

2026-10-19 首页设置入口改为项目原创 SVG 齿轮图标 `icon.settings.gear`，版本1，无外部依赖；源尺寸64×64，运行映射为 `pages/flow_home.gd/HomeSettings/HomeSettingsGear`，来源与SHA-256登记在manifest。

手牌纸张底板使用 `ui.hud.nautical-frame` v3：原有颗粒网格、圆点半径、颜色与透明度保留，由共享的 64 段圆形 ArrayMesh 和每个底板私有的 2D MultiMesh 批量绘制。实例缓冲仅在整数尺寸变化时重建，随底板释放；没有新增外部纹理、视口或规则随机。来源、hash 和生成方式见 `manifest.json`；图形回归与性能数据见[纸张绘制优化验证](../evidence/paper-grain-performance-20261019.md)。

2026-10-18 应用图标采用用户选中候选04的白帆船/蓝海浪。稳定ID为 `app.icon`、`app.icon.windows`、`app.icon.android.foreground`、`app.icon.android.background`、`app.icon.android.monochrome`；均为v1。内置ImageGen独立源、候选原图和提示保存在[图标源目录](../asset-sources/app-icon-sail-v1/README.md)，`tools/register_app_icon.py` 生成平台PNG/ICO尺寸、系统自适应安全区和主题alpha蒙版并登记hash/依赖，无视觉随机。映射到project.godot、Windows ICO及Android普通/自适应/单色图标；不参与GameState。实际安装包图标与签名检查见[打包记录](../docs/android-export.md)。

2026-10-18 全屏局外商店与两层科技：新增 `ui.meta-shop`、`rules.tech-tree`、`data.tech-tree`，复用已登记卡图；遗产与优惠券新增项目原创SVG `icon.meta.inheritance` / `icon.meta.coupon`，无下载依赖。同步图鉴共享预览卡片和全屏路由hash。详见[机制](../docs/meta-shop-and-tech.md)与[验证](../evidence/meta-shop-tech-v22-verification.md)。

2026-10-17 全屏图鉴：新增 `ui.encyclopedia`，复用已有卡图、怪物图、藏品图和 `ui.card.back`；无新增外部图片。`ui.modal-layout` 同步全屏路由 hash，详见[验证记录](../evidence/encyclopedia-verification.md)。

2026-10-17 新增 `ui.story-gallery`、`data.story-gallery-archive`，卡片封面复用开局分镜，未新增图片。同步序章只读回顾参数、App 根节点兼容启动层和回廊路由的 hash/依赖，详见 [剧情回廊](../docs/story-gallery.md)。

2026-10-17 独立剧情 LOG 改用原生 ScrollContainer 连续滚动，移除分页，打开时定位最新记录；无新增图片，ui.story.layout 脚本 SHA256 已同步。

2026-10-17 独立剧情页：`ui.story.layout` v2 移除背景及对白/选项/工具条的全部图片依赖，改用 Godot 原生按钮、纯色矩形和系统字体。历史 `ui.story.dialogue/choice/toolbar` 图片保留但不再被此页面使用。详见 [验证记录](../evidence/story-plain-verification.md)。

2026-10-17 木筏视角切换：新增项目原创 SVG `icon.camera.top`、`icon.camera.oblique`，圆圈内平面／倾斜田字表示点击后的目标视角，接入复位按钮上方的`ToggleRaftView`。源文件即`assets/icons/camera-top.svg`、`camera-oblique.svg`，版本1，无外部依赖，SHA-256与运行映射登记在manifest。相关UI脚本登记同步hash；验证见[视角模式](../evidence/camera-modes-verification.md)。

2026-10-17 新增 `opening.image.01`～`05`、`opening.music`、`opening.scenes`、`audio.blip-voice`、`ui.opening-intro`、`ui.game-bootstrap`。用户原包五张 PNG/OGG 与 Blip Voice 插件保留原字节；仅新增显示区域与运行路径。源与 hash 见 [序章源记录](../asset-sources/opening-intro-v1/README.md)，运行说明见 [世界观序章](../docs/opening-intro.md)。

2026-10-17 工具按钮优化：`ui.controls.utility-icons` 登记几何 X / 复位箭头及统一圆角/圆形底框；刷新 Widgets、航行 HUD 和设置的直接相关脚本 hash。旧 `ui.camera.reset-icon` 标记保留但不在运行中使用。无新外部依赖；imagegen 候选留在 `.gdignore` 来源目录等待用户选择，不作为运行资产。验证见[关闭与复位](../evidence/utility-buttons-verification.md)。

2026-10-17 普通文字按钮：新增 `ui.controls.text-buttons`，由 Widgets、设置和确认框共用四态九宫格/星盘绘图层。现有 `texture.ui.tarot.*` 十张 PNG/SVG 已与本次用户原包逐字节比较一致，补全原包路径与条目来源；运行图像没有改动。同步七个直接相关 UI 脚本条目的 hash/依赖/版本；不刷新其他脚本 hash。原包和清单见 [text-buttons-v1](../asset-sources/text-buttons-v1/README.md)，登记命令 `python tools/register_text_buttons.py`，验证见 [文字按钮](../evidence/text-buttons-verification.md)。

2026-10-17 v20：捕捞网模型 v004 的包围盒对齐格子中心并缩至格子宽深的 92%，避免网兜伸入相邻格；材质与 UV 保持。稳定 AssetId 不变，源、GLB、资产登记和重建脚本见 [木筏设备模型源记录](../asset-sources/raft-wood-unified-v1/README.md)。

同日复核：运行时旧导入缓存仍加载舷外模型，现已重新导入。AssetCatalog 模型与 GLB 范围一致，Godot GPU 顶视/斜视单格夹具通过，见 [捕捞网运行验证](../evidence/fishing-net-v20-verification.md)。

2026-10-17 航海 HUD 更新：顶部五图标、独立长条/圆形按钮、程序化米白手牌底板，以及新行动点素材已接入；卡牌顶栏固定逻辑高度，仅横向伸展。当前外观、来源与缩放约定见[航海 HUD](../docs/nautical-hud.md)，覆盖下文旧外观记录。

2026-10-17 v19：捕捞网状态提示恢复航初自动生产，主动打捞提示保底1张加完好网等级收益；无网时按钮可用。既有脚本登记同步版本/hash，无新增模型或图片。

2026-10-16 v18：打捞按钮、提示与捕捞网状态文案改为1AP主动捕捞；既有脚本资产登记同步版本/hash，无新增模型、图片或外部依赖。

2026-10-15 生图手绘木纹覆盖：共用暖棕/深褐/灰木三张1254贴图（`texture.shared.stylized-wood.*-albedo`）应用于箱子v2及木盆v4两植株状态，取代这两个模型此前的程序木纹。几何、生产规则及箱子待接入状态保持；木材采用粗糙度0.90，不叠旧微法线。Godot导入派生图片一并登记hash/尺寸/依赖，原始生图和完整提示词保留。当前来源与复建见 [手绘木纹记录](../asset-sources/stylized-wood-v1/README.md)。

2026-10-15 独立木箱资产：新增 `model.prop.wooden-crate`，状态 `staged-not-integrated`，不替换筏根旧箱、不加入储物/合成/安装玩法。33块错落拼板、斜撑、独立箱盖、铁件与绳提手；7000三角面/9网格批次，5张512木纹PBR图片内嵌GLB。源 `asset-sources/wooden-crate-v1/wooden_crate_v001.blend`，来源与复建见 [木箱源记录](../asset-sources/wooden-crate-v1/README.md)。

2026-10-15 一级滤水器状态：`model.raft.module.filter` 为本轮产水有水桶，新增 `model.raft.module.filter-waiting` 开口空桶。源 `asset-sources/filter-states-v1/filter_states_v001.blend`，工具 `refine_filter_states.py` / `register_filter_states.py`；两状态共用相同框架与空心接水桶，水位随本轮生产安排切换，不改规则或增加储水库存。此项覆盖下文filter旧源映射，详见 [外观状态](../docs/filter-production-visuals.md) 与 [源记录](../asset-sources/filter-states-v1/README.md)。

2026-10-15 土盆 v3：`model.raft.module.planter` 为成长完高植株，新增 `model.raft.module.planter-seedling` 六株圆子叶小苗；共用10块错落围板和土层，六张512×512木纹/土壤PBR图片已内嵌GLB并逐项登记hash/尺寸/种子。源为 `asset-sources/planter-v3/planter_v003.blend`；工具 `generate_planter_textures.py` / `refine_planter_v3.py` / `register_planter_model.py`。此项覆盖下文v1/v2土盆的历史源映射，详见 [当前外观规则](../docs/planter-growth-visuals.md) 和 [源记录](../asset-sources/planter-v3/README.md)。

2026-10-15 红蓝虚影外观补充：`ui.raft.ghost-fill` 登记 raft_surface.gd 生成的共享填充面（2.20×1.96m，alpha 0.16）和轮廓细轴加粗×1.4；ui.raft.surface 同步版本/hash。仅红色和蓝色启用，黄色选中不变；原 Blender/GLB 文件未变。

2026-10-15 木筏交互：`model.raft.slot-ghost` 使用新 Blender 源与 GLB（20 网格/240 三角面/法线 UV），运行时蓝红贴水、金色选中；`ui.raft.actions`、`ui.raft.surface`、`ui.raft.interaction` 登记报价、射线拾取/预览、小面板/确认。scene.voyage 更新 HUD 区域拟合与0.65秒镜头过渡；toon-config 新增阴影不透明度0.4。手牌和场景/模型工厂 hash 与依赖同步；无外部下载素材。详见 asset-sources/raft-interaction-v1/README.md。

2026-10-15 UI 修订：新增 `ui.controls.close`（widgets.gd 的右上 X）、`ui.settings-panel`（百分比滑条及平台选项）、`ui.display-preferences`（独立显示配置）与 `ui.modal-layout`（flow_app.gd 面板组合）。合成全屏固定八项，`ui.craft.grid` 更新；属性四项始终一行，`ui.hud.status` 新增可配置最小行宽。新局、结算、独立剧情 LOG 关闭入口统一 X，并更新对应脚本资产版本/hash；没有新增图片或视觉随机。实例随页面释放，依赖与运行映射见 manifest。

2026-10-14新增ui.settlement v1：原生Godot两页结算，源pages/settlement_page.gd，依赖pages/flow_base.gd、presentation/widgets.gd；manifest记录脚本SHA256及24px/s、0.35秒/6倍长按和末尾2秒配置。无新外部图片；布局、铜金边框和灰蓝底色属于程序化UI资产，实例随页面释放。运行映射为flow_app终局/章节停点或首页最近报告回看。

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
| relic.{藏品ID} | 20 | 获取提示、仓库、图鉴与新节点 | relics JSON / relics-v1 manifest |
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

`ui.hand.fan`（presentation/hand_fan.gd）用于航行和战斗手牌：全部实例同排显示，不分页、不滚动，按可用宽度重叠；悬停上浮保留原图层顺序，不要求战斗选中；以可见卡框宽度计算重叠，透明留白和阴影不参与，低于5%时不横移，达到5%才推动遮挡目标牌的右侧牌。停留 0.35 秒显示真实卡牌描述和阶段使用说明。命令通过 UID 发给页面，hover 不修改规则状态。不可弃置牌和战斗 AP 不足仍禁用操作；空白处点击不执行。

`shader.ui.hand-glass` 独立屏幕 mipmap 模糊 shader，带可配置 tint / blur_lod；`ui.hand.border` 独立程序绘制铜金双线、绳纹刻痕与铆钉角饰。装饰公式确定，不使用玩法 RNG；材质归底板实例持有，shader 和卡图由资源缓存共享。用户卡牌图片未重绘。通过 tools/register_hand_ui.py 更新源/hash/依赖。

验证：test_hand_fan、test_clean_ui、test_flow、test_supplied_assets 全部通过；49 个资产 hash 检查通过。test_hand_fan 使用 24 张超限夹具验证两种窗口尺寸、首中尾悬停、说明边界、真实鼠标事件点击 UID 和状态隔离。GPU Compatibility / RTX 4060 实拍 normal / many / hover / 1280 见 evidence/hand-*.png；20 张画面为 UI 夹具，不代表规则允许无限保留手牌。未进行多平台 GPU 性能测试。

每块毛玻璃底板使用局部 BackBufferCopy（24px 模糊边距），保证战斗弹窗采样自己的背景；弹窗遮罩/内容分别位于 z=200/201，底层抬起的手牌不会穿透遮罩。战斗 13 张手牌夹具实机图为 evidence/hand-battle-1280.png。

## 当前木筏状态模型 v1（2026-10-13）

游戏页改为 `model.raft-state`（presentation/raft_state_models.gd）按 cells/设备实例生成，无固定帆/货箱/植物装饰。六种设备分别建模；损坏保留停用设备并断板，脱落移除整格；灯的发光/暖光严格跟随完好状态与燃料。原 GLB 保留作历史源。坐标、状态与木筏详情一一对应。源/hash/依赖通过 tools/register_raft_state.py + tools/register_toon_ocean.py 登记；scene.voyage v10。映射、资源所有权和验证见 docs/raft-state-models.md。

木筏 v2：初始 3×2 中两格是左侧装饰筏根，四格为逻辑筏格；装饰不进入 GameState，水线/泡沫/雾/镜头包含筏根。model.raft-state v2，scene.voyage v11。详见 docs/raft-state-models.md。

## Blender 木筏模块（当前默认）

2026-10-17 装饰格 2 木桶落地修复 v6：`model.raft.module.root-decor` 的 16 块桶板与两道金属箍整体下移 0.34m，桶底从模块局部 y=0.50m 移到 0.16m 甲板面。原 v005 Blender 源保留，运行 GLB 通过 `tools/repair_root_barrel_float.py` 作确定性导出后修复；重新导出原模型后需运行该脚本。坐标选择有源 hash 和顶点数校验。资产登记保留此修复来源；源链、复建命令与 GPU 证据见 [木桶修复记录](../asset-sources/raft-barrel-v6/README.md)。

model.raft.module.deck-intact / deck-damaged / root-decor / lamp / filter / planter / medkit / crossbow / spearRack 分别映射同名 GLB，源为 asset-sources/raft-blender-v1/raft_modules_v001.blend。倒角、UV、法线及 PBR 基色在 Blender 中完成，湿木、发光开关和状态标签归运行时。每个 GLB 的 hash、来源、单位、依赖登记于 manifest，实例共享源网格，状态私有材质按 source+状态缓存。重新建模使用 tools/build_blender_raft.py（本机 Blender），再执行 register_blender_raft.py / register_raft_state.py / register_toon_ocean.py；check_blender_raft.py 检查导出完整性。原文件保持不变，不重新生成或覆盖原木筏源。

2026-10-15 土盆独立修复 v2：`model.raft.module.planter` 当前源为 `asset-sources/planter-v2/planter_v002.blend`，覆盖上段土盆的历史源映射。生成器 `tools/rebuild_planter.py` 修复部件变换错位，原始 55 个部件统一缩放并补底；1508 三角面、4 材质批次。运行路径与设备 ID 不变。`register_planter_model.py` 更新该条 hash/来源，整筏登记器也保留此映射。复建与验证说明见 [土盆源记录](../asset-sources/planter-v2/README.md)。


## HUD Visual Match v2（2026-10-13）

当前使用用户提供的 `deep_surge_hud_godot4_v2_visual_match.zip`。三个 HUD 控件/页面适配记录更新至 v2，新增五个 `texture.hud.*` AssetId，PNG 尺寸/hash/来源/依赖及事件图切片区域登记在 manifest；原包与原始工程保存在 `asset-sources/hud-visual-v2/`。运行控件保持状态与美术解耦，事件为按需原生按钮。布局、缩放与本次验证见 `docs/supplied-hud.md` 的 v2 节。

## 首页素材 v2（2026-10-14）

13张用户PNG、2×MP4派生的静音OGV和首帧poster已接入，独立shade多边形位于动态背景与菜单之间。稳定AssetId、源/hash/尺寸/依赖及shade参数由tools/register_title_ui.py登记。原包和2×/4×原视频归档于asset-sources/title-ui-v2，不使用个人绝对路径运行。布局和入口映射见docs/title-ui.md。

## 木筏新设备模型 v1（2026-10-15）

新增 `model.raft.module.shieldRack`、`generator`、`fishingNet`，源为 `asset-sources/equipment-models-v1/` 下的同名 v001 Blender 文件；箱子入口 `model.raft.module.crate` 通过轻量场景复用现有 `model.prop.wooden-crate`，适配甲板高度。三模型共用三色手绘木纹，源像素不变。生成、登记、重导入和 GPU 验证流程见 [源记录](../asset-sources/equipment-models-v1/README.md)；状态为 staged-not-integrated，未以视觉夹具声明设备玩法完成。总登记器保留独立源映射。预览与验收见 [模型验证](../evidence/equipment-v1-verification.md)。

2026-10-15 用户提供五张新波纹木纹，依序用于盾架、发电机、捕捞网、箱子和成熟/幼苗木盆。对应模型材料与 UV 已更新，位置和网格未改。五张 PNG 与原附件像素一致，作为源纹理登记。版本化 Blender 源、导出备份和 Godot 运行贴图登记见 [木纹 v2 记录](../asset-sources/stylized-wood-user-v2/README.md)。

2026-10-15 设备战斗 UI：`ui.battle.equipment` 对应固定攻击/格挡与本地预览确认、盾/敌意图摘要、发电机燃料和增益领取/指派，以及箱子有效手牌上限。设备模型继续使用上列稳定 AssetId；仅在资源加载失败时显示明确标注的临时占位。UI 与模型分开登记，详见 manifest。

2026-10-16：ui.hud.voyage-adapter v11、ui.voyage-hud v6，新增环境名称/原生悬停说明、侦察与定向按钮；移除顶部装饰底板。texture.voyage.topbar-v1仅保留归档，不再运行使用。新增data.environment-buffs v1，规则原稿来源、运行映射、依赖及SHA256见manifest；没有新增外部美术。

难度v13：`data.difficulties`登记三档试测参数，`rules.difficulty`登记统一规则；`ui.starting-resources`按难度选择自选/随机起手数量，说明只显示相邻难度增量。没有新增外部美术或视觉随机。

### v14战斗补给试测

新增稳定登记`ui.battle.salvage`，复用原海面打捞按钮；战斗费用由dispatch处理，未引入新美术资产。捕捞网继续使用`model.raft.module.fishingNet`，战斗发牌规则不改变模型映射。

### v15扩建费用

`ui.raft.expansion-cost`登记动态扩建报价，场景虚影与木筏详情共用核心费用。沿用现有筏格模型，无新增美术；前3次成功扩建1木头，之后2木头，AP均1。

### v16螺旋与视角

登记`layout.raft.spiral`与`ui.raft.camera-controls`。1/2装饰模型整体平移到螺旋中心，初始3/4/5/6及海面接触映射同步；GLB及Blender源不改。视角脚本提供转动/缩放/复位，锁定默认关，运行时与规则状态分离；变动的GD源hash已更新。

### 中键平移与R复位

`ui.raft.camera-controls`新增中键世界XZ水平平移，R/按钮共用0.45秒平滑复位；复用现有相机和UI，无新模型。相关GD源hash及运行映射更新，局内内容版本仍v16。

### 视角按键自定义

`ui.raft.camera-controls`运行映射更新为默认右键旋转/左键水平平移/R平滑复位，设置可改鼠标键与复位键、恢复默认；相关显示偏好、设置、场景和HUD源hash更新，无新模型或局内规则变动。

### 自由视角水平限位

`ui.raft.camera-controls`增加相对默认自动构图位置的XZ半径3米平移限制，更新脚本hash和运行映射；无新美术或局内规则变动。


### 2026-10-17 首页 v3 与自由比例

`video.title.ocean` / `texture.title.ocean-poster` 的运行映射更新为用户提供的“月下灯塔与星海航行”视频及首帧。原始文件为2940×1260、约5.09秒，运行视频为2240×960静音Theora，保持21:9。`texture.title.logo-v3` 使用本次透明PNG，第二张整页图登记为 `reference.title.home-v3`，不参与运行渲染。

`ui.title.frame-v3` 使用4条连续边线+16张等比装饰；`assets/title_ui/frame_v3/source_manifest.json` 保留源尺寸清单。四分点位于目标宽度25%/75%，无分段边线接缝。`tools/register_title_v3.py` 记录稳定ID、来源、版本、依赖、运行映射与SHA-256，不运行旧的v2登记器覆盖v3映射。表现层无规则随机。

`ui.title.logo-backdrop`：原生绘制的黑色70%不透明圆形，无新增图片；作为 `TitleLogo` 后置子节点同步位置、缩放与可见性。


### 2026-10-17 战斗四大面板

用户附件 `deep_surge_ui_panels (1).zip` 的四张 PNG 原样归档于 `asset-sources/battle-ui-panels-v1/`，运行副本为 `battle_ui/panels_v1/`。稳定 ID 为 `texture.battle.panel.monster`、`intent`、`preview`、`log`（后面三项共用 `texture.battle.panel.` 前缀）与适配器 `ui.battle.panels`。`tools/register_battle_panels.py` 登记源、版本、SHA256、原图尺寸、依赖与运行映射。原图像素保持不变，无新规则随机；原生深色圆底与控件随四面板等比适配。只应用四个大板块。验证见 [战斗四面板](../evidence/battle-panels-verification.md)。
2026-10-17：新增项目自绘 SVG 图标 ui.camera.reset-icon，路径 assets/icons/camera-reset.svg，版本1。运行映射为 voyage_hud.gd 的 ResetRaftView 圆形按钮，来源、SHA256 和依赖登记在 manifest.json；无外部素材。


### 2026-10-17 UI 组件迁入主工程

HUD 控件统一位于 `presentation/hud/`，五张 HUD 图片位于 `assets/ui/hud/`；可缩放按钮场景为 `scenes/ui/tarot_button.tscn`，配套 PNG/SVG 位于 `assets/ui/buttons/`。原运行 `addons/` 目录已删除。现有 HUD AssetId 保留并更新路径、版本与 hash，按钮场景及十张图片补登记为 `ui.buttons.tarot` 和 `texture.ui.tarot.*`。按钮素材只可追溯至迁移前项目文件，上游许可证未记录；原始 HUD 包继续保存在 `asset-sources/`。所有图片像素和脚本 UID 保留。Godot 导入、迁移组件实例化及 GPU `CLEAN HUD` 检查通过；全量资产清单仍有六个既有 hash 不匹配，详情见 [迁移验证记录](../evidence/ui-main-project-migration-verification.md)。

2026-10-17：正式新增 `ui.hand.stack-backplate`（`presentation/card_stack.gd`），复用 `ui.card.front` 生成向左露出的独立装饰后层，无新位图。`ui.hand.fan`、`ui.hand.layout`、`ui.item-card`、`ui.hand.stack-quantity`、`ui.settings-panel` 的版本、依赖、当前源hash同步；本地设置新增hover_mode。重新登记仍使用 `tools/register_nautical_hud.py`。

2026-10-17：配方图标新增 `card.shieldRack`、`card.generator`、`card.fishingNet`、`card.crate`，透明 PNG 位于 `assets/icons/recipes/`。由 `tools/render_recipe_icons.gd` 使用对应已有 `model.raft.module.*` 离线渲染，无模型修改；清单登记来源、版本、依赖与 SHA-256。其余配方复用现有 `card.*` 图片。

2026-10-17：`ui.settlement` v5 取消探索分数 `/ 100` 和最多4项说明，改为不封顶；无新增图片或依赖，脚本SHA-256已更新。评分版本 `settlement-score-v2`，见[验证记录](../evidence/settlement-uncapped-verification.md)。

2026-10-17：`ui.settlement` v6 将五类结算详情统一改为完整内容纵向滚动，移除分页按钮与页码；依赖不变，源脚本SHA-256同步更新。见[滚动详情验证](../evidence/settlement-scroll-verification.md)。


### 2026-10-17 首页背景替换（带边框视频）

当前首页使用用户提供的 `深潮_月下灯塔与远航帆船_去水印_2x超分2K_带边框.mp4`，运行资源为 `assets/title_ui/lighthouse_loop.ogv`（2560×1440、16:9、约5.09秒、Theora q7、静音循环）及同源首帧。完整画面等比居中，未覆盖区域纯黑，不裁剪画面。视频已含边框及Logo，移除独立 `TitleFrame`、透明Logo与圆形挡板实例，避免重复叠加；六个菜单按钮与设置入口保留。旧边框和Logo文件仅保留作历史资产。稳定AssetId沿用，来源、版本、依赖、映射和SHA-256由 `tools/register_title_v3.py` 更新。

2026-10-18 发布前登记核对：同步18个现有脚本/数据资产绑定的实际SHA-256与版本（含剧情/事件页、教程初始选牌、手牌保护、航行HUD、设置、难度与入口）。保留稳定AssetId及既有来源、依赖与运行映射；没有替换外部美术。文件级完整性由 tools/check_supplied_assets.py 再次核验。


### 航行轮次过渡

`ui.voyage.transition` 为项目自绘的原生画布动画（`presentation/voyage_transition.gd`），复用 `ui.loading.transition` 的淡入淡出与输入拦截。深海蓝底默认透明度0.82，帆船轻浮、三层波纹流动；颜色由导出参数配置，不使用随机或新增图片。视口自适应，无位图尺寸；来源、版本、依赖、运行映射与 SHA-256 登记在 `manifest.json`。验证入口为 `tests/test_voyage_transition.gd`，图形证据为 `evidence/voyage-transition.png`。

自动与手动航次结算统一复用 `ui.voyage.transition`；设置 → 游戏偏好新增“自动结束航程”（默认开启），本地保存，不新增图片。`ui.settings-panel`、显示偏好及筏格交互和入口脚本的现有资产条目同步当前版本和 SHA-256。设置与动画图形验证见 `evidence/auto-end-settings.png`、`evidence/auto-end-settings-game.png`、`evidence/voyage-transition.png`。


### 获取提示与遗物仓库

新增 `ui.acquisition.overlay`、`ui.acquisition.presenter`、`ui.collectible.placeholder`、`ui.collectibles.warehouse` 与 `icon.treasure`。界面使用项目原生画布/控件。以下为v27之前的占位方案记录：遗物共用 `texture.collectible.placeholder` 透明PNG（1254×1254 RGBA），由 imagegen 生成，参照 `card.wood` 的低多边形画风；单件古铜/青绿护符，简化块面与细节。原图归档于 `asset-sources/relic-placeholder-v1/`，运行副本位于 `assets/collectibles/`，像素原样复制，保留真实alpha；所有遗物格、右侧详情和获取动画通过共享缓存使用同一图片，无规则或表现随机。宝箱图标为项目 SVG（64×64）。来源、版本、依赖、运行映射与 SHA-256 在 `manifest.json` 登记。既有航行HUD、筏格拾取与根格标签相关资产沿用稳定ID并同步脚本hash。原模型与纹理未改；卡牌画面复用 `ui.item-card` 和现有卡牌图片。

GPU验证：`test_acquisition_ui.gd` 的获取/说明/飞行动画、`test_acquisition_layout.gd` 的960×540、1280×720、1600×900布局；证据为 `evidence/acquisition-*.png`。v27已用用户提供的20张图片整体替换专属美术；该护符仅保留为未知图片ID的回退。

获取动画终点修正：确认前通过待收取投影隐藏新牌、叠牌数量和容量增量；确认后按最终手牌矩形与真实尺寸直接飞入，到达时显现，不经过旧动画临时坐标。共享图片与规则奖励不变。`ui.acquisition.overlay`、`ui.acquisition.presenter` 及入口关联hash已同步，验证为 `test_acquisition_arrival.gd`。

发布前完整性核对同步了 18 个既有界面脚本的过期 SHA-256 登记值，仅更新 manifest 记录；270 个文件绑定校验通过，见[发布验证](../evidence/release-20261019-verification.md)。


2026-10-20：`藏品.zip` 的20张1254×1254透明原图完整归档于 [relics-v1](../asset-sources/relics-v1/README.md)，运行图等比缩至512×512，稳定AssetId为 `relic.<id>`，登记双hash与尺寸。获取提示、仓库、图鉴、新寻物节点复用缓存，未知ID才使用旧占位图。旧藏品设计已整体归档，当前20件全部采用新定义；详见[当前设计](../docs/relic-expedition.md)。

2026-10-20 怪物尸体与贝币换用真实卡图：`card.corpse` 与 `card.coin` 由 v1 纯色占位升级为 v2 用户提供的低多边形骨甲海怪尸骸、低模风格奶油色宝螺组合。原图为纯白摄影棚底，由 `tools/cutout_white_background.py` 做边界连通泛洪去底、边缘 alpha 过渡与去白边，按内容包围盒居中裁为 1024×1024 RGBA（运行图在 `assets/images/cards-20261020/`），不引入外部下载依赖。手牌、合成页、图鉴、获取提示与商店经 `assets.texture("card.<id>")` 统一生效；`show_label` 置 false，载入失败仍回退原纯色与标签。原图、算法阈值与双 hash 见 [corpse-cowrie-20261020](../asset-sources/corpse-cowrie-20261020/README.md)。
