# 航行扣除与失败提示验证（2026-10-21）

分支 `codex/monster-art-20261021`。航行规则先提交并保存结果；失败时暂缓页面刷新，保留航行画面并禁用底层操作。提示以32px字体、深色半透明无边框底显示扣除明细；失败额外显示生命或精神归零。2.4秒停留与0.25秒淡出，或点击/触摸任意处关闭；提示移除后显示正式结算页，关闭输入被消费。

- `tests/test_departure_notice.gd`：普通航行、扣血死亡点击关闭、扣血死亡自动关闭、精神归零触摸关闭；检查失败文案、延迟结算、禁用操作、实际数值、关闭输入不穿透、状态/随机不变。无头与GPU运行通过。
- `tests/test_navigation_partial_refresh.gd`：选择目标与普通局部刷新，以及失败提示结束后的完整结算路径；断言通过，退出时仍报告8个ObjectDB实例/4个资源未释放，尚未定位，该项不视为干净退出。
- `tests/test_voyage_survival.gd`：出发扣费与生存规则通过。
- `python tools/check_docs.py`：通过。

GPU截图：[普通](departure-notice-normal.png)、[失败](departure-notice-fatal.png)。1680×720逻辑窗口、手机UI模式，已目视检查。未验证真实手机触摸硬件和发行包；触摸输入使用Godot事件注入验证。
