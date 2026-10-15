# UI 缩放后场景错位修复 · 2026-10-15

原因：显示设置改为独立设置渲染尺寸后，SubViewportContainer 关闭 stretch，场景纹理按原始渲染像素大小绘制。UI 画布和纹理尺寸没有统一映射，导致木筏位置随 UI 倍率变化；降低清晰度也会缩小整张海面画面。

修复：`voyage_world.gd` 改为 TextureRect 展示 SubViewport 纹理，忽略纹理最小尺寸，始终铺满原逻辑场景区域。`flow_app.gd` 通过 set_render_size 只调整渲染像素。镜头目标、海面和木筏模型保持原设置。

测试先复现后修复：`tests/test_display_scene_alignment.gd` 实际 GPU 渲染，在场景指定投影位置绘制洋红色标记，扫描窗口输出像素中心，而非仅比较摄像机内部投影数据。

- 修复前：1280×720 窗口，100% UI/高清误差约 120 像素；低清晰度约 356 像素。125%/高清偶然对齐，低清晰度仍错位约 297 像素。
- 修复后：100%、110%、120%、125%、再回到 100%，分别测试高清和低清晰度，10 组全部 PASS；最大屏幕位置误差小于 1 像素。切换期间 GameSession 快照不变。
- 截图：`alignment-ui-*-quality-*.png`，检查 100% 高清与 125% 低清晰度，海面铺满，木筏保持位置，UI 独立变化。
- 回归：test_display_settings、test_clean_ui、test_raft_state_visual、test_fog、test_hand_gestures 均 PASS；raft_framing_visual 实际 GPU 检查初始/扩展木筏及窗口尺寸变化。
- 新包 `builds/android/deep-surge-v0.2-ui-alignment-fix-debug.apk` 导出退出码 0，v2/v3 签名及完整 ZIP CRC 通过，108286161 bytes，SHA256 `cf20f6d83ce89b57f16aa0a072c6d0df13ccd2601eeb08e1bb49d43604f9b741`。

Windows / Godot 4.7.2 / RTX 4060 / OpenGL Compatibility。没有 Android 真机验收；原宽屏和笔记本全屏留白问题仍待处理。
