# 普通文字按钮替换验证 · 2026-10-17

本次将共用文字按钮换为用户提供的深蓝/象牙白四态素材。改动位于表现层，不改变核心命令、存档、内容版本或随机流。

## 接入范围

- `presentation/widgets.gd` 的 Button 工厂：模式、新局/起手资源、航行阶段、合成/资源转化、木筏详情、图鉴、局内外商店、战斗普通操作、结算、剧情/夜间通用操作等调用点统一获得皮肤。
- `presentation/settings_panel.gd`：两个页签、返回首页和放弃本局；危险按钮保留红色提示。勾选/开关/下拉继续使用各自控件。
- `pages/craft_page.gd`：移除合成与转化执行按钮的旧纯色覆盖；主操作仍有蓝色强调，禁用优先。
- `pages/shop_page.gd` 与 `flow_app.gd`：原生交易/放弃确认框的确认、取消按钮；`title_layout_debug.gd` 的调试文字操作也接入。
- 首页原图、剧情专用选项、卡牌、航海图标和圆形/长条专用按钮仍由各自皮肤绘制；显式覆盖普通底图后，通用绘图层释放自己的样式/颜色覆盖，避免污染专用状态。

原生 Button 保留输入和回调。装饰忽略鼠标，在原生文字后绘制。保留可见键盘焦点；普通按钮两端星盘不横向拉扁，紧凑符号按钮不绘制星盘。没有把原始场景的最小 220×70 应用到所有控件。

## 实际运行

工作目录：`deep-surge-godot/`。通过本机 `C:/Users/ALmerb/AppData/Local/Programs/godot-mcp/godot.cmd` 调用 Godot `4.7.2.stable.official.ed1daf0bf`。GPU 为 RTX 4060 Laptop / OpenGL Compatibility。

| 命令 | 结果 |
| --- | --- |
| `godot.cmd --headless --path . --script res://tests/test_ui_layout_controls.gd` | `UI LAYOUT CONTROLS: PASS`，退出码 0；100%、113%、125% 缩放、面板关闭、起手资源返回等既有布局回归 |
| `godot.cmd --path . --script res://tests/test_clean_ui.gd` | `CLEAN HUD: PASS`，退出码 0；真实 GPU、无滚动容器、面板/手牌边界与原规则状态保持 |
| `godot.cmd --path . --script res://tests/text_buttons_visual.gd -- --capture` | 最终 `TEXT BUTTONS GPU: PASS (672 visible button checks)`，退出码 0 |
| `python tools/register_text_buttons.py` | 十张 PNG/SVG 与原包 hash 一致；七个直接相关脚本登记完成 |

本次 GPU 检查覆盖 1280×720 的 100%/125% 和 1600×900 的 100%：新局、起手资源、航行、设置两页、合成、资源转化、木筏、正式商店及交易确认、战斗、图鉴和局外商店。对可见普通 Button 检查皮肤与屏幕边界。真实指针验证悬停、按住及松开后仅执行一次原回调，检查键盘焦点仍可用。打开/关闭面板及交易确认不改变规则状态和 RNG。商店/战斗使用隔离测试夹具，`persistence=false`，不读写玩家存档。

实际截图：`text-buttons-{页面}-{宽}x{高}-{缩放}.png`；四态/焦点样例为 `text-buttons-hover-and-disabled.png`、`text-buttons-pressed.png`、`text-buttons-focus.png`。交易确认框截图直接取它自己的视口。

## 未通过与未覆盖

额外尝试 `godot.cmd --path . --script res://tests/flow_ui_smoke.gd` 时，在第 76 行查找首页“继续游戏”即抛出 Nil.disabled。该脚本的 `all_buttons()` 查找仅接收 Button，当前首页已有实现使用 TextureButton（`presentation/title_menu.gd:61`），未进入后续玩法流程。此脚本未通过，已仅终止该次测试进程，没有修改这个既有脚本的匹配方式。不能将本次记录视为完整路线重放通过。

结算、夜间、放弃确认框通过共用入口接入，但本次没有逐一截图其全部流程；不宣称覆盖所有剧情分支、移动端或导出构建。未运行完整规则路线和全量资产检查。资产登记只刷新本次直接改动文件，其他既有 hash 问题不在本次通过范围。

工作区原有改动保留；未提交或推送。
