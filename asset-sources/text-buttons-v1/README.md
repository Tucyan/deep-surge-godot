# 深潮文字按钮来源

用户于 2026-10-17 提供 `deep_surge_resizable_buttons_godot4.zip`，原包保存在本目录。运行图片在 `assets/ui/buttons/`；五张 PNG 和五张 SVG 与原包逐字节一致，hash 见 `inventory.json`。未附额外授权说明，不作额外授权声明。

运行由 `presentation/text_button_art.gd` 通过 `presentation/widgets.gd` 接入原生 Button。底图按原始 82/27 像素九宫格绘制，再根据控件高度等比缩放绘图坐标；双星盘独立绘制。紧凑符号按钮不绘制星盘，边饰适配窄宽度。鼠标与键盘仍由原 Button 处理，绘图层忽略输入。主按钮和当前页签使用悬停底图突出，危险按钮额外偏红；禁用状态优先。

首页、剧情专用选项、卡牌、航海图标和长条/圆形按钮使用各自皮肤；显式替换普通底图时，共用绘图层释放自身覆盖。下拉框、勾选框和开关继续使用各自原生控件。

登记命令：`python tools/register_text_buttons.py`。只刷新本次涉及的 UI 脚本登记，不刷新其他资产 hash。截图与验证范围见 `evidence/text-buttons-verification.md`。
