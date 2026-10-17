# Deep Surge · Godot V0.2 流程重做

文档入口：[文档索引](docs/README.md) · [当前机制](docs/current-game-mechanics.md) · [正式商店](docs/formal-shop.md) · [验证记录](evidence/economy-v11-verification.md)。以下按日期排列的条目仅作变更历史，不能覆盖当前代码。

2026-10-18 剧情系统重做：剧情模式保留为独立入口，必须先选择剧情模式，才可新建或读档剧情进度；当前章固定 11 个节点，每个航行节点进入前播放一段剧情。剧情模式的航行、资源、战斗和结算沿用本机挑战规则，剧情层只维护叙事状态；挑战模式不显示剧情新建/读档。导入包中的规则冲突以本机实现为准，原文和本地改写均保留来源记录。契约与验证见[剧情层与剧情存档](docs/narrative-and-save.md)。

2026-10-18 事件页三栏与两步选项：节点事件由单一右侧框改为「立绘 / 说明 / 选项」三栏，右侧框只放选项并均匀分布，不再显示标题与说明；事件底板按 z 序压在世界层之上、常驻 HUD 之下，视角复位/切换与打捞按钮在事件阶段仍然绘制但被底板盖住，离开事件后恢复。事件与剧情选项改为先点选、右侧变「确认」再点提交，文本栏显示该选项标题与说明，预选时选项栏右上出现「取消选择」、左侧固定「请做出选择」；取消按钮占位常驻，出现或消失不推动其他选项。继续/跳过文字/结束节点/迎战/进店仍是一步动作。规则、AP、随机与存档不变。详见[事件呈现](docs/node-event-presentation.md)与[验证](evidence/node-event-ui-verification.md)。

2026-10-18 导航两步出发：右侧操作框候选改为“先选点、再出发”。点候选名称只在顶部显示该目的地标题与详细说明，被选中的那一行按钮变为「出发」，再点才启航；候选按钮不再带「出发 · 」前缀。操作框改为固定尺寸（顶边96、底边距视口316），不再随内容自动伸缩。详见[航行操作](docs/navigation-and-crafting.md)与[验证](evidence/nav-panel-verification.md)。

2026-10-16 经济试测 v11：涌泉减为木头1＋随机资源1，免费补给事件限访1次，仅挑战前两站保底食水；削减战斗收益。商店资源共享翻倍价格（1/2/4/8/16/32），设备价+1，尸体出售2币、基础材料不可售；木头支持灯燃烧2轮。内容版本`godot-flow-v02-11`拒绝旧档。见[验证记录](evidence/economy-v11-verification.md)。

2026-10-16 已应用 V0.2 节点与正式局内商店：漂浮物、营地、风暴、修复/节奏/目标筏格事件按新候选规则投放；祭坛退出候选池，增加 E11 分支战斗和“零星漂浮物”回退。商店每次生成3种资源＋3种设备，按单店限购并支持确认后的买卖；藏品货架保留为未开放。内容版本为 `godot-flow-v02-10`，旧内容版本拒绝载入。见[当前规则](docs/current-game-mechanics.md)、[正式商店](docs/formal-shop.md)与[验证记录](evidence/node-shop-v10-verification.md)。

2026-10-15 涌泉方案采用：后续每轮固定木头1＋从铁/塑料/绳索/布条中等概率有放回随机3张，共4张；首轮仍无涌泉。配方、容量、燃料和AP不变。内容版本更新为 `godot-flow-v02-8`，拒绝旧档，同版本保存恢复已验证。详见[正式涌泉规则](docs/spring-supply.md)及[采用验证](evidence/spring-supply-adoption.md)。[允许随机三张再出木头的补测](evidence/spring-wood-repeat-allowed.md)已完成，暂不覆盖本条。

2026-10-15 生命数值试测：基础生命上限30→12，强壮初始16；包扎/营地/夜间恢复3/6/3，敌伤1～2、饥渴各1、污染每张1、撤退2，等级与永久生命成长同步缩小。12为基础上限，配套参数为开发试测。用户已明确Demo完成前无需兼容旧存档，本版 `godot-flow-v02-7` 明确拒绝旧版本并保留同版本保存恢复。规则见[生命试测](docs/health-balance.md)，当次测试及公开指令游玩见[验证记录](evidence/health-balance-verification.md)。

2026-10-15 Agent游玩接口v1：新增统一核心操作查询，自动结束与木筏报价共用真实命令校验；提供独立无窗口JSONL会话、合法操作与受限参数选择、玩家观察、统计事件及可验证重放轨迹。快速运行 `python tools/agent_client.py --play --seed 22`。不读取/覆盖玩家存档，不调整数值。见[接口与架构说明](docs/agent-interface.md)、[小幅重构计划](docs/superpowers/plans/2026-10-15-agent-interface.md)及[本次验证](evidence/agent-interface-verification.md)。

2026-10-15 生产时机修订：滤水器、土盆、捕捞网与发电机改为每轮开始、导航开放前推进生产。上一轮先完成老化与超限整理，新产物可在本轮行动使用，到本轮末才检查容量；安装当轮不立即生产，终局/章节停点无额外产出。周期、产量、增压与燃料数量保留。旧版弃牌档跳过紧接的一次轮初生产，避免重复推进；读档与打开界面不生产。验证见[轮初生产](evidence/round-start-production.md)。

2026-10-15 战斗与设备更新：攻击/格挡改为不占手牌的固定行动，接入分层护盾、木头/废铁/绳索/塑料/布条组合和预览确认。新增盾架、发电机、捕捞网、储物箱；发电机提供动力强化、屏障强化、设备增压，超出长期容量的临时增益于下一航行轮结算消失。普通/困难战斗额外掉落2/3张基础资源，原尸体与贝币保留。旧内容数值保持，新功能使用可配置开发默认值。规则与控件检查见[本轮验证记录](evidence/battle-equipment-verification.md)，机制与模型交接见[开发说明](docs/battle-equipment.md)。GPU截图验收因一次命令超时，按用户约定交由用户执行，尚未宣称通过。

2026-10-15 海面打捞与配方优化：新增常驻海面打捞（1 AP 从基础资源池打捞一张手牌并计入统计）；修复无木头时卡手问题：修补包配方调整为铁1+绳索1，破损木筏支持使用木头1或绳索2修补。右侧阶段操作面板在导航、准备、收尾阶段增加“海面打捞 · AP1”按钮，0 AP时禁用；收尾阶段剩余AP保留主动打捞与决策空间，不再强行提前自动结算。测试覆盖 `tests/test_salvage_and_recipes.gd` 与 `tests/test_salvage_ui.gd`。

2026-10-15 木筏直接交互：设备牌长按拖到空格松开安装，点击格子显示选中与安装/升级/修复小面板；满筏时只提示一个贴近海面的红蓝新建虚影，二次确认显示木头2/AP1再扣费。设备阴影减淡；扩建后镜头按实际 UI 空间平滑居中/拉远。见[交互说明](docs/raft-direct-interaction.md)及[当次验证](evidence/raft-interaction-verification.md)。未打包 Android。

2026-10-15 新增首页右上“设置”：UI 大小使用 100%～125% 滑条、步进 1%、松开应用，手机默认 125%；电脑可选分辨率和全屏，手机可选清晰度。设置独立保存，四项属性始终单行；合成全屏、每页 8 项。返回首页只保留于设置及游戏左上菜单，其余退出统一右上 X。宽屏与笔记本全屏留白仅记录。见[显示设置](docs/display-settings.md)及[当次验证](evidence/ui-controls-verification.md)。本次不打包 Android，手机尚未真机验收。

2026-10-14 已接入两页结算：航海日志自动滚动，可跳过；长按屏幕或空格0.35秒加速6倍。第二页提供实际统计、千分评分和涌潮点，支持返回日志。主游戏原日志入口已移除，首页“回溯潮涌”可回看最近报告。章节完成只展示，整局结束按完成节点发点；旧档缺历史统计时明确显示不完整。见[实际契约](docs/settlement.md)、[评分设计](../V0.2/结算与评分设计.md)与[当次验证](evidence/settlement-verification.md)。

2026-10-14 新增独立 Galgame 剧情页面：运行 `./launch-story.ps1` 或打开 `scenes/story_demo.tscn` 按 F6。包含打字对白、说明、右上 SKIP、选项与分页 LOG；暂不接入主程序。数据与调用契约分别见[剧情数据结构](docs/story-data.md)、[剧情接口](docs/story-interface.md)；`./launch-story.ps1 -Verify` 可运行专门测试。

2026-10-12 雾调整：深度雾保持14米开始/38米完全浓雾，并保留镜头比例缩放；色彩从蓝色移向低饱和灰青，三层低空雾偏灰绿、缓慢漂移，近筏遮罩保护木筏及扩展范围。没有改海面波形或海面色板。验证见[雾验证](evidence/fog-verification.md)。

2026-10-12 当前海面（风格化冷夜v1）：程序化Gerstner波＋三渲二分档暗蓝着色、浪脊断续硬边泡沫、月光闪点、灯笼暖光、筏格接触环、深度雾与航行视口冷夜调色；参数见`assets/data/toon-ocean.json`。原GLB海面保留为回退。详见[风格化夜海验证](evidence/toon-ocean-verification.md)。下一段GLB海面说明为回退及历史记录。

2026-10-12 GLB海面（现为回退）：按用户要求恢复第一版原GLB九块/180000三角形、完整16姿态、原尺寸与浪高、蓝色渐变和泡沫图集。只保留船边水面柔化、共享水线、局部泡沫和湿木修复。降面/缩放/风格化试验已归档。详见[模型海面验证](evidence/model-ocean-verification.md)。下文轻量海面为回退及历史记录。

2026-10-12 轻量海面：航行使用一个不透明3D平面、双层滚动周期水纹、木筏外缘局部泡沫与湿木水线。海面2个三角形，初始四格接触泡沫16个三角形；无水面形变、屏幕/深度采样或额外泡沫视口。用户Blender源与派生GLB完整保留，不再在游戏启动时加载。规则、随机和存档版本保持不变。详见[纹理海面验证](evidence/texture-ocean-verification.md)。

用户提供的16张卡图、4张卡牌UI继续应用。手牌/战斗采用独立正面＋卡图＋类别徽章，未发现图鉴显示卡背。绑定与替换见[素材登记](assets/README.md)，早期模型海面接入记录见[历史素材验证](evidence/supplied-assets-verification.md)。

2026-10-12 界面修订：航行采用真实Godot 3D海面/木筏，HUD按参考图分为左上工具、右上属性、右侧阶段操作和底部单排手牌。选择模式后只呈现独立新局准备页。主界面与各面板已移除ScrollContainer；内容使用分组、分页和单项详情。当前说明及验证见 `docs/frontend-guidelines.md`、`evidence/hud-verification.md`，本节覆盖下文旧页面排版。

2026-10-12。Godot 4.7.2 / GDScript / Compatibility，无外部下载依赖。当前提供**挑战最小循环与第一层 11 节点剧情模式**，游戏页为主舞台，子页按阶段和当前事件显示。原 Three.js 与玩法实验保留。

## 启动

双击 `启动游戏.cmd`；或执行 `./launch.ps1`。编辑器导入 `project.godot`，主场景 `scenes/main.tscn`；`./launch.ps1 -Editor` 可打开工程。脚本已使用 UTF-8 BOM，兼容 Windows PowerShell。旧窗口加载的是旧脚本，重做后需关闭旧窗口重新启动。

首页“挑战模式”展开出身与种子选择，然后“开始航程”；挑战模式不提供剧情新建和读档。默认种子22/强壮之人；这是已跑通的验证种子，仍使用正式随机候选，没有固定调试路线。

首页“剧情模式”先进入剧情档选择，可新建或读取与玩法局配对的剧情存档，再进入同一套新局准备。第一章固定 11 个节点，每个节点都有剧情；剧情结束后按本机挑战规则继续航行。导入的原始段落保存在 `narrative/content/source/`，本地规则冲突记录在 `local-adaptation.json`。

## 页面与流程

| 页面 | 板块与入口 |
| --- | --- |
| 首页 | 两模式、继续、图鉴、局外商店、退出；挑战新局选择出身/种子 |
| 游戏页 | 属性/AP、木筏、当前阶段/目标与合法操作、真实手牌、当前候选 |
| 结算 | 可长按加速的航海日志；统计、四项评分、涌潮点和回看；章节停点不发整局点数 |
| 剧情 | 当前节点文字、推进/跳过、当前选项、结果文字；选项不能跳过 |
| 商店 | 当前货架、贝币/尸体支付、离店；只由当前剧情交互开放 |
| 合成 | 配方、持有材料、制作AP、制作按钮；仅准备/收尾 |
| 木筏详情 | 真实格与设备、安装、燃料、治疗、修理、合并升级与邻接扩建；非基地阶段只读 |
| 战斗 | 当前敌HP/意图、独立战斗AP、实际战斗手牌、回合结束、合法撤退 |
| 图鉴 | 已发现卡/怪物/藏品与结局；未知内容隐藏详情 |
| 局外商店 | 积分、成长、科技/前置；活动局不能购买 |
| 夜间 | 结束白天后按需打开服务、公共事件、一次休息/调查及结果；第5晚无主要行动 |
| 任务与线索 | 仅剧情中已有信息才提供入口；每次一条，分页，无未来剧情树 |

```text
首页 → 新局初始化 → 导航（点候选看标题/详情 → 该行「出发」） → 准备
→ 进入节点 → 文字 → 必选项/商店/战斗 → 结果文字 → 收尾
→ 结束航行 → 老化/临时增益到期 → 超限整理 → 食水与饥渴扣血 → 下一轮开始生产/涌泉/导航或终局
```

收起面板只改变 UI，不改变游戏 phase；主界面提供“处理当前事件”恢复。未完成事件时没有下一节点入口。商店离店/战斗胜退先恢复结果剧情，剧情end才算完成节点，基地AP不刷新。准备/收尾可使用剩余AP；AP0不自动结束。精神与灯在移动时处理，食水和饥渴扣血在结束航行时各结算一次，剧情夜间不重复扣除。

首轮自选1～5张基础资源（每类最多2张），或零选择「随心所欲」随机7张，无涌泉；后续导航前领取固定木头1＋五种基础资源等权随机1张（允许再出木头），共2张。10～15航次、按类别权重生成最多3种候选，仅前两站保底食水；最后站固定Boss。战斗使用固定攻击/格挡及箭/矛/污染规则。

挑战流程继续使用本机候选节点和终局规则。剧情模式固定 11 次导航，每次导航前先播放对应章节剧情，再进入与挑战模式一致的准备、节点、战斗、收尾和结算流程；最后一个节点走本机正常完成路径。剧情档与玩法存档成对保存，损坏或不匹配的剧情档会安全拒绝，不替换当前有效状态。

## 当前边界

**本次剧情属于test-story-v1试测内容。** 补给、恢复量、调查、最终价格和独航出口为新增测试设定；不冒充世界观完整剧本或已确认平衡。尚无第二层、夜间战斗、专属舱室3D模型和新人物图片；3D航行使用原木筏与轻量纹理海面，剧情仍使用独立AssetId纯色文字占位。

卡/节点数据先完整导入，不等于所有效果已完成。尚未开放：节点特殊 upgrade/enchant、随机失牌/献祭、顺流/迷雾等环境、藏品机制/购买、遗迹额外藏品或日记奖励、留存附魔/真结局、下局祝福。祭坛已从普通候选池退役；商店藏品货架仅显示未开放。相关操作显示具体禁用原因，不扣钱售卖未生效商品。

## 数据、素材和保存

```text
flow_app.gd                 应用组合；持久3D层＋按需界面层
core/game_session.gd       唯一事务入口，独立screen/panel与规则phase
core/run_rules.gd          导航、节点通用效果、合成/设备、结算/成长
core/battle_rules.gd       战斗、临时牌清理及返回剧情
core/campaign_rules.gd     测试剧情、固定事件、夜间/任务/线索、章节停点
core/inventory.gd          实例消耗/容量
core/random_streams.gd     分用途uint32 xorshift流
content/data/*.json        九组原实验定义＋独立story_nodes/story_config
pages/voyage_hud.gd        固定区HUD与底部手牌分组
pages/new_game_setup.gd    独立新局准备
pages/paged_reference.gd   短列表/分页＋单项详情
pages/flow_*.gd            首页/剧情/战斗只读投影
presentation/voyage_world.gd 3D海面、木筏、镜头、灯光、视觉浮动
adapters/save_store.gd     文件读写、临时文件替换
assets/manifest.json      稳定AssetId→图片/占位颜色/标签
presentation/*.gd         缓存与纯色+文字占位
```

素材替换：将图片放 `assets/images/`，修改清单中 `card.water` 等条目的path为 `res://assets/images/...png`，更新source/version、登记授权/尺寸/hash后重启。正式图片成功载入默认隐藏占位字；`show_label:true`可保留叠字。缺图回退，无页面路径硬编码。资产源说明见 `assets/README.md`。

自动保存位于 Godot `user://godot-flow-v02.json`，每次成功指令保存状态、Profile、完整随机流及内容指纹。当前格式为 schema2/contentVersion=`godot-flow-v02-11`、randomVersion=`xorshift32-godot-v1`；v10及更旧内容版本按当前入口拒绝，不提供静默迁移或伪装成功载入。缺历史统计的旧终局不补发正式评分或点数。

`tools/import_lab.mjs` 是一次性迁移工具，再运行会覆盖内容和素材清单，游戏启动不调用。9组等价测试保留零差异依据。

## 本次验证

```powershell
node --test tests/content.test.mjs
godot --headless --path . --script tests/test_flow.gd
godot --headless --path . --script tests/test_mechanics.gd
godot --headless --path . --script tests/test_routes.gd
godot --headless --path . --script tests/test_save.gd
godot --headless --path . --script tests/test_catalog.gd
godot --headless --path . --script tests/test_difficulty.gd
godot --headless --path . --script tests/test_tutorial.gd
godot --path . --script tests/difficulty_ui.gd
godot --path . --script tests/tutorial_ui.gd
godot --path . --script tests/tutorial_start.gd
godot --headless --path . --script tests/test_clean_ui.gd
godot --headless --path . --script tests/test_narrative.gd
godot --headless --path . --script tests/test_narrative_flow.gd
godot --headless --path . --script tests/test_narrative_repairs.gd
godot --headless --path . --script tests/test_tutorial_rules_repairs.gd
godot --headless --path . --script tests/test_tutorial_setup.gd
godot --headless --path . --script tests/test_tutorial_event_layout.gd
python tools/check_supplied_assets.py
godot --headless --path . --script tests/test_supplied_assets.gd
godot --headless --path . --script tests/test_texture_ocean.gd
godot --headless --path . --script tests/test_model_ocean.gd
godot --headless --path . --script tests/test_toon_ocean.gd
godot --path . --script tests/toon_ocean_visual.gd
godot --path . --script tests/model_ocean_visual.gd
godot --path . --script tests/texture_ocean_visual.gd
godot --path . --script tests/supplied_visual_smoke.gd
godot --path . --script tests/flow_ui_smoke.gd -- --capture
godot --path . --script tests/story_ui_smoke.gd -- --capture
```

`test_session.gd`/`ui_smoke.gd`仅为新测试的兼容别名。所有新测试隔离用户存档；机械页面的测试夹具标明test-fixture，完整鼠标航程用真实种子22和正常候选，无测试状态注入。最新海面画面为`evidence/toon-ocean-*.png`（`model-ocean-*.png`为GLB回退记录），卡牌素材回归脚本使用`supplied-current-*`；旧`texture-ocean-*`、`supplied-texture-*`、`hud-*`和`supplied-*`记录保留为历史。未验证发行导出构建和跨平台字体。

素材原图/原zip/原blend归档在`asset-sources/`，由`.gdignore`隔离自动导入。不直接引用微信下载目录。当前模型外观参数在`assets/data/model-ocean.json`，源采样在`supplied-ocean.json/surface.bin`；通过`tools/register_model_ocean.py`更新hash登记。`tools/generate_texture_ocean.py`保留纹理回退及泡沫纹理生成，不覆盖新版scene.voyage映射。图片/颜色/形变数据/泡沫/逻辑状态独立，源模型文件未修改。

独立本地Git仓库，根仓库忽略此工程；本次未提交、未推送。

当前海面细节 v1：独立 256×256 纹理增加水流细纹、泡沫孔洞和微法线反光，参数位于 assets/data/toon-ocean.json 的 detail 段。最新对照为 evidence/ocean-detail-before.png / ocean-detail-after.png，验证记录 evidence/ocean-detail-verification.md。

手牌交互已更新为无分页重叠排列，鼠标附近展开，停留 0.35 秒显示描述与操作说明。毛玻璃 shader、铜色纹理边框和卡牌图片独立维护。验证：`tests/test_hand_fan.gd`；实机截图：`evidence/hand-hover.png`。

2026-10-14：设置新增默认开启的「自动理牌」与「同类资源合并显示（叠牌）」，相同永久资源达到 4 张才合并显示数量，3 张及以下逐张展示；长按 0.2 秒拖动排序，手动排序后自动理牌关闭。短按松开执行原操作，弃置叠牌每次只消耗一张。开关本地保存，手动顺序在当前应用中保持。详见 `docs/hand-layout.md` 和 `evidence/hand-layout-verification.md`。

贝币也显示为手牌：余额大于零时一张货币卡显示持有数量，全部贝币合占一张容量，不受资源叠牌设置影响。可查看/拖动，商店支付后同步数量；轮末点击「弃置全部 · 贝币」弃置整份余额。余额仍由 `state.coins` 保存，兼容现有存档。验证入口：`tests/test_coin_card.gd`；说明见 `docs/hand-layout.md`。

当前木筏按真实筏格与设备生成，取消常驻帆/货箱等固定装饰。空位、设备类型/等级、破损、脱落和灯燃料均同步呈现。映射与验证：docs/raft-state-models.md；截图：evidence/raft-state-*.png。

当前木筏为 Blender 模块版：上排 1、2 装饰，3 可用；下排 4、5、6 可用。几何源 asset-sources/raft-blender-v1/raft_modules_v001.blend，运行 GLB 独立位于 assets/models/raft-modules；通过 AssetCatalog 稳定 ID 加载。完整初始模型：asset-sources/raft-blender-v1/raft_initial_v001.glb。旧四格存档迁移位置，已扩建旧存档保留旧布局。详细映射、边界和验证见 docs/raft-state-models.md。\n
