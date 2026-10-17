# 手机战斗可读性优化 · 2026-10-18

后续空间修订：按用户反馈，战斗阶段隐藏视角切换和复位按钮；手机面板左边距由128改为28逻辑像素。新增断言先复现按钮仍显示/左侧空间未释放，修复后三档21:9及补充16:9的GPU测试均PASS；收尾阶段两个按钮恢复显示的断言通过。资产登记同步更新`ui.battle.panels`与`ui.hud.voyage-adapter`当前版本/hash。

Windows / Godot 4.7.2 / RTX 4060 Laptop / OpenGL Compatibility，模拟手机平台分支，自由比例、125% UI。未在Android真机安装或重新导出APK。

手机战斗四面板利用上方空白横向展开，保留顶部状态条、左侧视角按钮及底部手牌/AP/迎击。正文至少18逻辑字号，取消整组缩小文字。怪物图片等比；其余三张原素材以NinePatch伸展内部，固定边角与图标尺寸；原始PNG未修改。标题固定，长意图/预览与增益内容可在各自内容区滚动。日志跳过/撤退纵向排列，重置及增益下拉同样至少44逻辑像素高。手机选中卡片上抬12逻辑像素，保持容量数字可见。没有改动战斗规则或局内存档格式。

`tests/mobile_battle_visual.gd` GPU测试先因信息区过窄、缩小字号和触控按钮不足失败；新增选牌遮挡断言也先复现失败。修复后全部PASS：21:9的1260×540、1680×720、2520×1080，以及补充16:9的1280×720。检查普通/组合预览、字号与区域宽度、触控高度、屏幕边界、手牌间隔、容量无遮挡、预览不修改规则状态；增益选择后详情可滚动至底部，教程紧凑高度仍包含跳过/撤退。

本次回归：`test_mobile_hand.gd`、`test_battle_actions.gd`、`test_battle_equipment_ui.gd`、`test_hand_gestures.gd`、`test_hand_click.gd`均PASS。桌面`test_battle_panel_art.gd` GPU测试PASS，保留四图原比例与桌面交互。

资产登记更新：`ui.battle.panels`、`ui.hand.fan`版本/hash/运行映射，以及三张伸展面板的手机运行映射。

本次6项资产hash校验PASS，四张PNG与原源文件字节相同。全量`tools/check_supplied_assets.py`仍失败于此次未修改的`ui.hud.voyage-adapter`登记hash与代码不一致；未为通过全量检查而改写其他工作的登记。

截图：[21:9组合预览](mobile-battle-1680x720-selected.png)、[21:9小屏初始界面](mobile-battle-1260x540-initial.png)、[增益预览滚动到底部](mobile-battle-1680x720-boost.png)。
