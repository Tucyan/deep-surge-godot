# 视角按键绑定验证

日期：2026-10-16。本轮仅修改本地表现设置与输入处理，没有修改局内规则、保存格式或内容版本。当前工作区内容版本为godot-flow-v02-17，保持其他正在进行的改动；未提交或推送。

## 行为

- 默认鼠标右键按住旋转、左键按住水平平移。滚轮缩放、触摸操作、视角锁定和0.45秒平滑复位保持。
- 设置→游戏偏好新增“视角鼠标按键”：旋转/平移分别可选左/右/中键，选择被另一动作占用的按键时交换绑定，避免歧义。
- “视角复位快捷键”按钮进入按键录入，可绑定字母、数字、F1～F12及Home/End/Insert/PageUp/PageDown；Esc取消，修饰键和不支持的按键不写入。新绑定后旧键不再生效；模态窗口内只在主动录入时捕获按键，不穿透复位。
- “恢复默认”恢复右键旋转、左键平移、R复位，不改变锁定等其他设置。HUD及设置中的提示反映当前绑定。
- camera_orbit_button/camera_pan_button/camera_reset_key即时应用并独立持久化到display-settings.cfg。旧配置缺字段使用新默认；非法类型/重复鼠标键/非法复位键回退默认。
- 左键单击仍选择筏格，超过拖动阈值后平移而不选择/建造；鼠标松开停止，手牌设备拖放保持。绑定和手势不dispatch，不改物资、AP、局内状态或规则随机。

## 验证

引擎：C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe。

先增加test_camera_bindings.gd，在旧实现观察到默认键不符及缺少绑定接口的预期失败，再实现并通过。

最终10项验证全部退出0且无stderr，见camera-bindings-verification.json：

- headless test_camera_bindings：默认右键旋转/左键平移、冲突交换、中键可选、排除滚轮拖动绑定、按键保存/恢复、错误配置回退。
- headless test_camera_pan、test_camera_controls：平移水平性、锁定/复位、转动/缩放及偏好持久化回归。
- 非headless camera_bindings_ui：实际右键旋转、左键平移；真实左键单击能选格、拖动不选格；设置选择互换即时生效；点击录入K、Esc取消、R不再复位而K有效；恢复默认；100%/125%UI倍率控件在视口内；前后完整GameSession快照一致。最终设置说明文字调整后再次运行PASS。
- 非headless camera_pan_ui：1280×720及1600×900，默认左键平移、R/按钮平滑过渡中间帧与终点、锁定、模态拦截及规则状态不变。
- 非headless spiral_camera_ui：默认右键旋转、滚轮/触摸、锁定/复位、螺旋3D建造和原容量上限回归。
- 非headless test_display_settings、test_raft_camera_fit、raft_interaction_ui：显示/设置布局、相机自动构图、原设备鼠标/触摸拖放及扩建确认回归。

实际GPU为NVIDIA RTX4060 Laptop/OpenGL Compatibility。已查看camera-bindings-settings-1280.png（展示自定义左键旋转/右键平移/K复位）；测试最后恢复默认。相关资产源hash已同步，本轮文件git diff --check通过。

仅表现层更改，本次未重复运行规则路线。触摸使用Windows原生Godot模拟输入，未做Android真机或发行导出验证。
