# 筏格操作原因与一键升级 · 2026-10-15

运行 Godot 4.7.2，Windows OpenGL / RTX 4060。没有 Android 打包或真机测试。

## 行为与事务

已安装设备的升级操作始终可见，缺同类牌、同级设备、AP不足、破损、满级及教学限制直接显示禁用原因。1级设备可选择一键升级，费用为原配方材料＋原制作 AP＋升级1 AP，当前配方总计2 AP；保留原1→2/2→3合并规则。

使用 `upgrade {cell, craft: true, revision?}`，原 GameSession dispatch 内完成制作及合并；不是 UI 依次提交两个命令，因此没有中间自动推进或扣一半费用。原 craft 执行配方/科技校验，升级命令执行阶段、筏格状态、等级、教学与 revision 校验；失败整体回滚。制作产物即时合并，成功没有额外牌残留，燃料/生产进度保留，统计包含制作和升级、总AP只计一次。

## 当次验证

- `test_craft_upgrade.gd`：先 FAIL 后 PASS。缺来源仍显示升级理由、材料报价无副作用、准确扣费、无残留牌、燃料/进度、统计、恰好2 AP、过期revision；缺料/AP、破损、高等级、科技和阶段阻挡完整回滚。
- `raft_upgrade_panel_ui.gd -- --capture`：PASS。100%鼠标与125%触摸事件实际点击一键升级，覆盖缺牌/缺料、AP不足、可升级、2级需同级设备、3级满级提示。费用和禁用原因直接可见，面板位于顶部HUD下方；布局约束修改前 FAIL，修改后 PASS。
- `raft_interaction_ui.gd -- --capture`：PASS。原设备拖装、合并入口、修补、扩建确认回归。
- `test_raft_interactions.gd`、`test_auto_progress.gd`、`test_mechanics.gd`、`test_settlement.gd`：PASS。

截图 `raft-upgrade-panel-missing-100/125.png`、`raft-upgrade-panel-ready-100/125.png`、`raft-upgrade-panel-max-100/125.png`；已检查125%缺材料及可升级截图，说明可读，没有覆盖顶部状态栏。

## 提示框位置修订

根据用户圈选位置及后续“紧贴选中格右侧”要求，改为投影该格真实Deck/设备网格包围盒，在右边缘外留12个逻辑像素，随筏格位置和UI缩放跟随；不使用筏格中心或屏幕最右侧作横向锚点。纵向保持在HUD/手牌之间。

`raft_upgrade_panel_ui.gd -- --capture` 修改前右侧贴边断言 FAIL，修改后 PASS；100%/125%全部在位格检查不与当前选中格相交，且保持近侧间距。复查125%一键升级截图，选中筏格可见。`raft_interaction_ui.gd -- --capture` 回归 PASS。


## 右侧1/5重叠与状态文字修订

按新反馈，面板左边缘改为选中格投影宽度80%处，允许遮住右侧1/5，取代原12像素间距。`raft_upgrade_panel_ui.gd`在修改前FAIL，修改后headless及GPU均PASS：100%/125%所有在位格剩余4/5保持可见，升级原因与鼠标/触摸一键升级回归。

StateLabel文字和描边关闭深度测试，渲染优先级10/9。`test_raft_state_visual.gd`修改前FAIL、修改后PASS，覆盖六类设备及破损/拆除/燃料变化。`raft_annotations_visual.gd` GPU PASS：2级土盆“成长完”、2级滤水器“本轮产水”文字配置正确；复查 `raft-annotations-125.png`，第二行未被筏面遮挡，提示框位于右侧1/5处。规则/RNG不变，没有Android打包或真机测试。
