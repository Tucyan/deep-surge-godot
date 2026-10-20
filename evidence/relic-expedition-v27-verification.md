# 藏品与寻物节点 v27 验收

日期：2026-10-20。Godot 4.7.2，当前分支 codex/origins-v1。所有运行测试隔离APPDATA/LOCALAPPDATA，主场景测试关闭persistence，没有读写玩家实际存档。当前内容为20件全新ID、10个新航行节点，旧案归档；没有旧版本迁移。

## 已执行

- `test_relic_expedition.gd`：PASS，422检查。全部20种节点奖励通过实际option/battle_action发放，覆盖领奖前后保存、重复领取拒绝、UID、图鉴登记、单局访问限制和查看纯度。直接构造节点上下文是集成夹具，不冒称20种都已由自然航行抽到。
- 组合效果、集成、航行/安装、战斗、遗物奖励、正式商店、获取投影、节点商店集成、节点重设计、保存、ActionQuery、AgentSession、回廊恢复共14个规则入口全部PASS（包含新增寻物测试）。奖励回归含两条合成内容的真实Agent dispatch/replay路线。
- `node --test tests/content.test.mjs`：10/10 PASS。
- 20件图片完整性检查：原图/运行图40个SHA256、尺寸、RGBA/透明角像素全部PASS。运行资源已由Godot导入。
- `test_relic_art.gd`：NVIDIA RTX4060 / OpenGL 3.3兼容渲染PASS，桌面1280×720、手机布局1600×720、全部10节点主题图完整等比显示、图鉴故事及图片缓存通过。第二次使用规范化隔离路径无shader缓存错误。首次隔离目录初始化提示user目录不可用；建立测试目录后解决。

## 最终回归状态

`test_routes.gd`：PASS，executed=7、stale=13、failed=0。7条必需路线全部实际执行并核对物资守恒、终局及同版本恢复；13条历史路线只计数，不替代当前覆盖。

当前内容指纹：`6f55af574531f7159055f15f3719ca2c9e2ba10305b19cdd7e3bf1e73e4f4e29`。

| 路线（seed22） | 当前结果 | 完成节点 | 公开动作数 |
|---|---|---:|---:|
| standard-challenge | survived | 12 | 165 |
| standard-story | survived | 11 | 159 |
| hard-challenge | survived | 12 | 189 |
| hard-story | dead | 10 | 159 |
| nightmare-challenge | dead | 11 | 194 |
| nightmare-story | dead | 10 | 164 |
| standard-failure | mad | 7 | 61 |

与替换前基线相比，7条路线的结果和完成节点数一致，公开动作数随新候选变化。这只是固定种子回归，不是胜率或平衡结论。生成及重放输出见 [生成日志](relic-v27-route-generation.log)、[重放日志](relic-v27-routes.log)。

`test_collectible_ui.gd`、`test_acquisition_ui.gd`、`test_acquisition_layout.gd` 均在RTX4060兼容渲染下PASS：实际商店购买、说明、飞入、仓库选择、全实例滚动，以及960×540、1280×720、1600×900的获取提示/仓库布局。旧界面测试仍引用分页和共用占位图，已同步当前滚动仓库与独立图片；选择触发重建后需重新查询控件，修正测试悬空引用后通过。

`python tools/check_docs.py`：PASS（46入口/专题、10份当前契约、0错误）；`test_check_docs.py`：8/8 PASS。检查时按仓库现有CRLF约定识别行尾，相关文件的diff whitespace检查通过。

## 图形证据

- [桌面全套仓库](relic-expedition-warehouse.png)
- [手机仓库](relic-expedition-mobile.png)
- [新节点](relic-expedition-node.png)
- [图鉴故事](relic-expedition-encyclopedia.png)

图片已人工查看：20件图像独立、透明背景保留，节点物件未裁切，图鉴故事及说明清晰。手机为桌面渲染下的mobile布局验收；没有Android真机触摸或发行导出验收，不据此声称已完成这两项。

## 审阅

独立只读评审未发现新增规则/保存/路由缺陷。指出新战斗奖励描述不能忽略现有血月/战斗狂额外奖励，已修正文案为无基础贝币/尸体/材料奖励，环境和出身奖励照常。

完整设计见[藏品与寻物节点](../docs/relic-expedition.md)，旧定义与契约见[旧案归档](../docs/archive/relics-before-v27/README.md)。
