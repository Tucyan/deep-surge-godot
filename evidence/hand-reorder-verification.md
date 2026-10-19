# 拖动排序松手卡顿修复（2026-10-18）

范围：Godot 当前源码，未修改规则、AP、随机算法或存档版本；未导出、提交或推送。

## 原因与修改

松手原来仅更新 `HandLayout.order`，随后 `reordered -> hand_reordered -> render()` 重建HUD、手牌和木筏交互。现由 `HandFan.move_card_group()` 同步移动 cards/tiles/buttons/stack_bases，按组重排兄弟节点，使绘制与命中一致；保留实际位置，继续原缓动。焦点回调按控件查当前索引，避免仍指向旧槽位。固定攻击/防御不进入持久顺序。

FlowApp 正常保存偏好后直接返回，保存失败仍展示错误。自动理牌开关保持原值。`ui.hand.fan` 与 `ui.modal-layout` 的版本和源码hash已同步登记。

## 图形实测

Godot4.7.2 / Compatibility / NVIDIA RTX4060 Laptop / 驱动591.74，1280×720，challenge strong seed22，额外5木头形成叠牌。预热3次，再各测30次空操作与换位。通过viewport实际派发按住、移动及松手，校验确实开始拖动且指定UID完成换位。偏好同步写临时 `user://reorder-probe.cfg`，结束删除；规则存档关闭。

| 指标 | 修复前中位 / p95 | 修复后中位 / p95 |
| --- | --- | --- |
| 松手同步处理 | 42.460 / 44.128 ms | 0.941 / 1.285 ms |
| 松手到下一次绘制 | 180.539 / 192.776 ms | 43.317 / 45.228 ms |
| 观察窗口最大帧间隔 | 158.381 / 171.853 ms | 22.850 / 24.353 ms |
| 同次空操作到绘制 | 45.360 / 48.226 ms | 42.691 / 45.945 ms |

修复后30/30换位保留HUD与手牌实例；两组60/60样本（各含30空操作）规则快照一致。原始数据：[before](hand-reorder-before.json)、[after](hand-reorder-after.json)，探针 `tests/probe_hand_reorder.gd`。最初一版探针按下坐标不正确，没有实际拖动；修正并增加换位检查后，旧无效数据已被有效数据覆盖。

到绘制包含帧率限制、调度与渲染等待，不是纯GPU时间。结果接近同轮空操作，不代表所有设备或界面零延迟。未在Android真机或发行包验证。

## 回归结果

- 新增 `test_hand_reorder_refresh.gd` 先观察原代码桌面/触摸、航行/战斗的顺序及实例断言失败，再修复通过；headless和图形均输出PASS。覆盖位置连续、叠牌/按钮UID、绘制顺序、焦点/命中/点击、固定行动、同槽和取消、偏好写入、后来完整重建保留顺序，以及AP/库存/进度/RNG不变。
- Headless：`test_hand_gestures`、`test_hand_layout`、`test_hand_fan`、`test_hand_animation_click`、`test_hand_stack_hover`、`test_mobile_hand`、`test_hand_click` 均PASS。日志 `reorder-test_*.log`。
- 图形 `test_partial_refresh.gd` PASS。首次headless因等待frame_post_draw未跑到PASS，只以图形重跑为完成证据。
- `test_raft_drag_edges.gd` 两项旧断言仍FAIL：期望设置删除RaftInteraction和3D节点。暂还原两个生产文件为HEAD后复跑同样失败，见 `reorder-raft-drag-original.log`；当前模态保留实例并禁用交互，本次未修改无关测试或模态行为。

用户要求的后续轻微停顿已单独测量登记在[体验卡顿清单](../docs/experience-stall-backlog.md)，未混入本次修复。
