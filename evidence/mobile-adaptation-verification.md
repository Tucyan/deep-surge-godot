# 手机基础适配验证 · 2026-10-18

环境：Windows / Godot 4.7.2，移动分支模拟；GPU渲染使用RTX 4060 Laptop / OpenGL Compatibility。没有Android真机或APK打包验证。

主要屏幕条件为21:9：1260×540、1680×720、2520×1080，自由比例、125% UI；补充960×540的16:9回归。三种设置页签均生成截图，检查面板没有越出屏幕、内容可滚动至底部、页签触控高度至少44逻辑像素。

- `tests/test_mobile_hand.gd`：PASS。0.05秒边界、轻点不消耗、向上拖出一次使用、滑回取消、侧向/屏外释放、第二手指、系统取消、导航禁用、AP不足、不可弃置卡；实际航行中饮水消耗指定UID，实际战斗攻击扣一次AP，布料攻击无效组合不消耗。
- `tests/mobile_settings_visual.gd`：PASS。三档21:9及一档16:9，三页设置GPU渲染与布局断言。
- `tests/test_hand_gestures.gd`：PASS。桌面点击、长按排序、叠牌与弃牌；观察回调避免在局部刷新保留手牌节点时重复连接。
- `tests/test_display_settings.gd`：PASS。平台选项、持久化、UI缩放与规则状态隔离。
- `tests/test_raft_drag_edges.gd`：PASS。无效装备落点、取消、无AP升级及模态遮挡。

截图：[21:9游戏偏好](mobile-settings-1260x540-game.png)、[21:9显示设置](mobile-settings-1680x720-display.png)、[21:9剧情设置](mobile-settings-2520x1080-narrative.png)。

以上为模拟平台、合成触控事件及桌面GPU证据；触屏硬件、系统手势、刘海安全区和真机性能仍需手机复核。未修改规则内容版本和局内存档格式。
