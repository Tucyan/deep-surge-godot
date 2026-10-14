# Deep Surge · Godot V0.2 流程重做

2026-10-14 新增独立 Galgame 剧情页面：运行 `./launch-story.ps1` 或打开 `scenes/story_demo.tscn` 按 F6。包含打字对白、说明、右上 SKIP、选项与分页 LOG；暂不接入主程序。数据与调用契约分别见[剧情数据结构](docs/story-data.md)、[剧情接口](docs/story-interface.md)；`./launch-story.ps1 -Verify` 可运行专门测试。

2026-10-12 雾调整：深度雾保持14米开始/38米完全浓雾，并保留镜头比例缩放；色彩从蓝色移向低饱和灰青，三层低空雾偏灰绿、缓慢漂移，近筏遮罩保护木筏及扩展范围。没有改海面波形或海面色板。验证见[雾验证](evidence/fog-verification.md)。

2026-10-12 当前海面（风格化冷夜v1）：程序化Gerstner波＋三渲二分档暗蓝着色、浪脊断续硬边泡沫、月光闪点、灯笼暖光、筏格接触环、深度雾与航行视口冷夜调色；参数见`assets/data/toon-ocean.json`。原GLB海面保留为回退。详见[风格化夜海验证](evidence/toon-ocean-verification.md)。下一段GLB海面说明为回退及历史记录。

2026-10-12 GLB海面（现为回退）：按用户要求恢复第一版原GLB九块/180000三角形、完整16姿态、原尺寸与浪高、蓝色渐变和泡沫图集。只保留船边水面柔化、共享水线、局部泡沫和湿木修复。降面/缩放/风格化试验已归档。详见[模型海面验证](evidence/model-ocean-verification.md)。下文轻量海面为回退及历史记录。

2026-10-12 轻量海面：航行使用一个不透明3D平面、双层滚动周期水纹、木筏外缘局部泡沫与湿木水线。海面2个三角形，初始四格接触泡沫16个三角形；无水面形变、屏幕/深度采样或额外泡沫视口。用户Blender源与派生GLB完整保留，不再在游戏启动时加载。规则、随机和存档版本保持不变。详见[纹理海面验证](evidence/texture-ocean-verification.md)。

用户提供的16张卡图、4张卡牌UI继续应用。手牌/战斗采用独立正面＋卡图＋类别徽章，未发现图鉴显示卡背。绑定与替换见[素材登记](assets/README.md)，早期模型海面接入记录见[历史素材验证](evidence/supplied-assets-verification.md)。

2026-10-12 界面修订：航行采用真实Godot 3D海面/木筏，HUD按参考图分为左上工具、右上属性、右侧阶段操作和底部单排手牌。选择模式后只呈现独立新局准备页。主界面与各面板已移除ScrollContainer；内容使用分组、分页和单项详情。当前说明及验证见 `docs/frontend-guidelines.md`、`evidence/hud-verification.md`，本节覆盖下文旧页面排版。

2026-10-12。Godot 4.7.2 / GDScript / Compatibility，无外部下载依赖。当前提供**挑战最小循环与第一层15站测试剧情**，游戏页为主舞台，子页按阶段和当前事件显示。原 Three.js 与玩法实验保留。

## 启动

双击 `启动游戏.cmd`；或执行 `./launch.ps1`。编辑器导入 `project.godot`，主场景 `scenes/main.tscn`；`./launch.ps1 -Editor` 可打开工程。脚本已使用 UTF-8 BOM，兼容 Windows PowerShell。旧窗口加载的是旧脚本，重做后需关闭旧窗口重新启动。

首页“挑战模式”展开出身与种子选择，然后“开始航程”。默认种子22/强壮之人；这是已跑通的验证种子，仍使用正式随机候选，没有固定调试路线。存档存在时“继续游戏”恢复规则状态及当前事件。

首页“剧情模式”同样进入独立新局准备。测试剧本包含实际生存/设备/战斗教学、同行或独航、夜间休息/调查、任务和三种危机处理结果。先在第2站按提示制造、安装并升级滤水器，进入剧情不会代替这些操作。完整测试方案见[第一层测试剧情方案](../V0.2/第一层测试剧情方案.md)，测试证据见[evidence/story-verification.md](evidence/story-verification.md)。

## 页面与流程

| 页面 | 板块与入口 |
| --- | --- |
| 首页 | 两模式、继续、图鉴、局外商店、退出；挑战新局选择出身/种子 |
| 游戏页 | 属性/AP、木筏、当前阶段/目标与合法操作、真实手牌、当前候选、日志 |
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
首页 → 新局初始化 → 导航 → 出发（一次航耗） → 准备
→ 进入节点 → 文字 → 必选项/商店/战斗 → 结果文字 → 收尾
→ 结束航行 → 老化/生产 → 超限整理 → 下一轮导航或终局
```

收起面板只改变 UI，不改变游戏 phase；主界面提供“处理当前事件”恢复。未完成事件时没有下一节点入口。商店离店/战斗胜退先恢复结果剧情，剧情end才算完成节点，基地AP不刷新。准备/收尾可使用剩余AP；AP0不自动结束。航耗只在移动扣，不在轮末重复扣。

首轮六张等权基础资源，无涌泉；后续导航前一次三张资源。10～15航次、池抽样及最多3种候选、非战斗机会保留；最后站固定Boss。战斗使用原出拳/箭/矛/污染规则的基础实现；原始卡牌、节点含变体的JSON未改。

上述10～15站与Boss为挑战流程。剧情固定15次移动：1～4及15固定，5～14使用20份普通池；第5晚开启舱门任务，8/11/14晚先公共异变再主行动，6～14晚各一次休息/调查。夜间不重复航耗、不刷新基地AP；服务物资需实际支付且仅一次。第15站处理方案读取独立线索、物资与设备，付费后出结果、尾声、轮末和超限整理，才停在`chapterComplete`。保留本局，第二层未开放；主动放弃本局才按已完成节点发一次积分。

## 当前边界

**本次剧情属于test-story-v1试测内容。** 补给、恢复量、调查、最终价格和独航出口为新增测试设定；不冒充世界观完整剧本或已确认平衡。尚无第二层、夜间战斗、专属舱室3D模型和新人物图片；3D航行使用原木筏与轻量纹理海面，剧情仍使用独立AssetId纯色文字占位。

卡/节点先完整导入，不等于所有效果已完成。尚未开放：节点特殊upgrade/enchant/exchange/blood/relicChance/altar/guide、随机失牌/献祭、顺流/迷雾等环境、藏品机制/购买、遗迹额外藏品或日记奖励、留存附魔/真结局、下局祝福。相关操作显示具体禁用原因，保留原免费退出；不扣钱售卖未生效商品。核心只实现当前验证的子集，不宣称完整 V0.2 或冻结基线全部通过。

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

自动保存位于 Godot `user://godot-flow-v02.json`，每次成功指令保存状态、Profile、完整随机流及内容指纹。格式为schema1/contentVersion=`godot-flow-v02-3`、randomVersion=`xorshift32-godot-v1`，是可玩子集的独立格式，**不是完整V0.2 schema3契约**。上一版`godot-flow-v02-2`挑战档按九组原内容指纹校验后迁移，不重建物资/随机。剧情保存对白游标、固定访问、路线、夜间预算/阶段、委托领取、线索与危机支付；恢复后继续当前步骤。旧页面上下文/旧浏览器档不迁移。校验失败保留原文件并提示，明确新局才解除坏档覆盖保护。

`tools/import_lab.mjs` 是一次性迁移工具，再运行会覆盖内容和素材清单，游戏启动不调用。9组等价测试保留零差异依据。

## 本次验证

```powershell
node --test tests/content.test.mjs
godot --headless --path . --script tests/test_flow.gd
godot --headless --path . --script tests/test_mechanics.gd
godot --headless --path . --script tests/test_routes.gd
godot --headless --path . --script tests/test_save.gd
godot --headless --path . --script tests/test_catalog.gd
godot --headless --path . --script tests/test_clean_ui.gd
godot --headless --path . --script tests/test_story.gd
godot --headless --path . --script tests/test_story_edges.gd
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

当前木筏按真实筏格与设备生成，取消常驻帆/货箱等固定装饰。空位、设备类型/等级、破损、脱落和灯燃料均同步呈现。映射与验证：docs/raft-state-models.md；截图：evidence/raft-state-*.png。

当前木筏为 Blender 模块版：上排 1、2 装饰，3 可用；下排 4、5、6 可用。几何源 asset-sources/raft-blender-v1/raft_modules_v001.blend，运行 GLB 独立位于 assets/models/raft-modules；通过 AssetCatalog 稳定 ID 加载。完整初始模型：asset-sources/raft-blender-v1/raft_initial_v001.glb。旧四格存档迁移位置，已扩建旧存档保留旧布局。详细映射、边界和验证见 docs/raft-state-models.md。
