# 两工作树安全整合验证

日期：2026-10-20。分支`codex/integrate-v03-relics`，内容`godot-flow-v03-02`，schema2，`xorshift32-godot-v1`。本页记录本次实际执行，来源工作树的通过结论只作历史。输入快照与历史证据见[integration-sources](integration-sources/README.md)。真机触摸与发行导出未执行。

## 保全与整合范围

两个原工作树的分支HEAD、索引和全部快照文件保持不变。已对A4706、B4501个文件逐一核对SHA256；完整字节备份及清单位于根工作区`tmp/godot-safe-merge-20261020`。Git快照分别为`codex/snapshot-origins-20261020-safe-merge`（4bffabe3）和`codex/snapshot-v03-20261020-safe-merge`（950cd849）。临时缓存虽不进入Git交付，仍保留在字节备份。没有推送、远程变更、安装、旧档迁移或玩家保存访问。

整合保留0.3三层规则/天气/保存校验，以及20件新遗物、10个寻物节点、独立图像、手机布局与局部刷新。寻物节点按整局配额登记，窗口由全局航次换成层内航次；安全公开投影保留字符串art，同时隐藏随机分支与战斗请求。剧情入口继续默认隐藏，序章及只读回廊保留。25张冲突截图及两套旧路线分别保存在来源目录。

## 本次验证

- [套件汇总](safe-integration-suite-summary.json)：43个独立Godot入口的最后一次执行均PASS。原始输出已复制到[日志目录](integration-20261020/logs/)，包含Session/Save、三层/天气/难度、节点/商店、遗物、恢复、局部刷新、手机布局、奖励/帮助和回廊。
- 专项`test_v03_relic_integration`覆盖真实Boss转层保留新遗物UID、领奖前后恢复、临时牌与次数不重复，以及出发后获得/丢弃遗物影响真实航耗但不修改基础锁。跨层集成夹具为受控规则测试，不冒称自然玩法通关。
- 新UI检查先复现局部刷新错误开启教程撤退、战前离开未提示生命代价；修复后Projection/EventExit为2/2 PASS。
- 扩展规则首轮26/27：旧天气夹具假定永久战斗节点不足，并只耗尽层级计数。新增整局节点使该假设失效。改用正式计数键并保留受控模板/篡改拒绝检查，专项2/2 PASS，未放宽生产规则。
- UI首轮13/14：奖励UI需9批真实时间动画，600帧退出预算不足，没有到达PASS报告。使用其完整2400帧预算、实际GPU运行后PASS，未发生命令超时。
- 桌面GPU实际执行`test_relic_art`、`node_event_layout`、`test_acquisition_ui`，3/3 PASS。已查看本轮节点和手机仓库截图：专属透明物件完整显示、三列仓库与滚动/详情可见。截图为[节点](relic-expedition-node.png)、[手机仓库](relic-expedition-mobile.png)、[桌面仓库](relic-expedition-warehouse.png)、[图鉴](relic-expedition-encyclopedia.png)。这是桌面Compatibility渲染下的mobile布局，不能替代Android真机。
- `node --test tests/content.test.mjs`：10/10 PASS。外部实验JS来源改为带SHA256的独立历史夹具，工作树可单独运行；未把实验工程接入运行内容。
- `python tools/check_supplied_assets.py`：PASS，292个绑定、20张原始PNG及GLB完整性。修正20个顶层和12个嵌套来源hash；检查器新增source_hashes断言并先复现失败后通过。
- `python tools/check_docs.py`：PASS，45入口/专题、11份当前契约、0错误；文档测试8/8、公开策略测试10/10。
- 规格审阅与代码质量审阅分别执行。所指出的旧六件/商店唯一获取/当前v27文案和嵌套hash问题均已修正。

## 当前必需真实路线

7条路线经真实公开Agent动作重新生成，每段有界推进并保存checkpoint，终局另起进程独立重放，比较步数、结果和轨迹hash后才发布。`test_routes.gd`再次执行7条当前路线：`executed=7, stale=13, failed=0`；13条历史路线不代替当前覆盖。剧情路线用于保留系统回归，未开放剧情UI。

| 路线（seed22） | 结果 | 完成航次 | 公开动作数 |
|---|---|---:|---:|
| standard-challenge | dead | 18 | 235 |
| standard-story | survived | 11 | 160 |
| hard-challenge | dead | 18 | 236 |
| hard-story | survived | 11 | 180 |
| nightmare-challenge | dead | 7 | 89 |
| nightmare-story | dead | 10 | 190 |
| standard-failure | dead | 5 | 51 |

当前内容指纹：`acdbc15094eebe6984469ccf2beadf924f0d7e7483da2277967d37af187a6250`。具体独立重放步骤/结果/hash在各`v03-route-*.metrics.json`和日志中。

新遗物和节点投放改变既有策略的资源与风险选择；当前seed22标准/困难挑战均在18航次死亡、噩梦7航次死亡。结果可重放，不等同于平衡已通过或整合版自然25航次生还。本轮没有为通关修改玩法数值或注入Agent状态；建议后续独立开展平衡试玩。

## 边界与恢复

测试APPDATA/LOCALAPPDATA使用隔离目录；主场景专项关闭persistence。原保存未被访问或更改。没有新旧存档迁移；整合版只接收同版本和当前指纹。原工作树和快照保留，整合结果位于独立工作树，便于审阅或回退。未在本轮重复完整性能探针，不将来源v26的毫秒改善写为本轮整合性能结论。
