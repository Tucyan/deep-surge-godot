# 螺旋布局与视角 v16 验证

日期：2026-10-16。内容版本`godot-flow-v02-16`，schema2，xorshift32-godot-v1。用户要求3D木筏螺旋扩建，明确保留现有上限，并追加拖动/缩放、复位、默认关闭的视角锁定。未提交或推送。

## 改动

- 共享`core/raft_layout.gd`提供1～16螺旋坐标和装饰位置：初始`612/543`，完整为`7 8 9 10 / 6 1 2 11 / 5 4 3 12 / 16 15 14 13`。
- 1/2装饰在(1,1)/(2,1)，cell-0..3在(2,2)/(1,2)/(0,2)/(0,1)，编号3/4/5/6。装饰根及其灯光随父模型平移(2.35,0,2.1)m，模型、海面接触、标签和自动构图一起匹配；GLB不改。
- 默认9总格/7功能格、许可16总格/14功能格不变；3D无完好空位时只提示螺旋序列中首个可重建/扩建的合法缺口，逐次确认。保留前三次成功扩建1木头/后续2木头，均AP1。
- 3D提示顺序改变，核心和Agent仍支持所有原来合法的邻接位置，目录按螺旋枚举。装饰位在执行、查询和当前保存校验中排除。v15及更旧保存/轨迹拒绝，不迁移旧坐标；当前保存校验spiral-v1、格位边界与装饰保留位。
- 纯表现`raft_camera_controls.gd`提供左键拖动转动、滚轮缩放；触摸单指转动/双指缩放。6逻辑像素阈值区分点击，俯仰与缩放有界。手动偏移叠在原自动构图之上，普通UI刷新保留，新局复位。
- 主HUD“视角复位”；设置→游戏偏好新增“视角锁定”（默认false、独立配置保存）及“复位”。锁定时禁止手动转动/缩放，仍可复位与自动构图。模态界面不接收场景手势，失焦/无键移动结束拖动。视角操作不dispatch、不改AP/物资/状态/规则随机。
- 当前机制、专题文档、Agent坐标契约及资产登记同步，旧制作记录标明当前布局已覆盖。

## 测试

引擎：`C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`。

先增加`test_spiral_raft.gd`与`test_camera_controls.gd`，确认旧实现因布局/顺序不符、未拒绝v15、缺少视角控制而失败，再实现并通过。

- 26项headless核心测试退出0、无stderr，原始输出见`spiral-camera-v16-core-tests.json`。含螺旋两档上限、装饰位拒绝、3D候选顺序、重建缺口、当前JSON恢复/旧布局拒绝、视角锁定默认值和独立持久化、拖动阈值/复位/缩放边界，以及原查询、Agent、保存、环境、难度、战斗供给、商店经济和四条完整剧情路线。
- `python tools/validate_spiral.py`：13局共1950步，全部经公开合法操作到终局，JSON文件往返完整重放、卡牌守恒通过，无Godot stderr。`test_routes.gd`独立从磁盘读取并重放这13条v16轨迹，PASS。结果仍为标准挑战seed39/1000通关、其余挑战样本战败，三档剧情seed22完成15站；用于回归，不作平衡结论。
- `node --test tests/content.test.mjs tests/node_content.test.mjs`：15/15通过。
- `python -m unittest discover -s tests -p test_agent_stdio.py -v`：3/3通过。
- 非headless GPU测试6项全部退出0、无stderr：`test_display_settings`、`test_raft_camera_fit`、`raft_interaction_ui`、`test_raft_root`、`test_blender_raft`、`spiral_camera_ui`，见`spiral-camera-v16-ui-tests.json`。实际GPU为NVIDIA RTX4060 Laptop/OpenGL Compatibility。
- 新`spiral_camera_ui.gd`最终扩展版再次实际执行PASS：1280×720鼠标拖动/滚轮、单指拖动、双指缩放；拖动不选格，操作前后完整GameSession快照一致；HUD复位、设置锁定默认关/生效、模态拦截滚轮、锁定时设置复位有效；真实3D确认依次扩建7～16并停止；1600×900满筏截图。
- 原木筏直接交互测试覆盖鼠标/触摸设备长按拖放、添燃料、升级、两次点击确认扩建及取消，100%/125%UI倍率通过；相机自动构图平滑及扩建后适配HUD区域测试通过。更新了其遗留固定2木头断言以符合v15已批准的首次1木头费用。
- 已查看`spiral-camera-v16-initial-1280.png`、`spiral-camera-v16-expanded-1600.png`、`spiral-camera-v16-settings-1280.png`，位置、编号、1/2装饰中心、复位入口与设置均可见。
- `git -c core.whitespace=cr-at-eol diff --check`通过；新增布局/视角及已变更GD源的资产hash同步。

## 边界

触摸在Windows原生Godot输入事件中模拟，未做Android真机验证。未验证发行导出。视角锁定阻止手动操作，不停止原扩建/布局变化后的自动构图。临时视角不保存到局内存档；只持久化锁定偏好。
