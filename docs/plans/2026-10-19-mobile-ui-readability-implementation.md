# 手机 UI 阅读与触控优化实施计划

Goal：手机设置整页化，并扩大高频文字与触控区域，改善密集页面布局。
Architecture：在现有表现层增量修改；公共控件提供手机字号下限，固定艺术布局显式适配，不修改规则与存档。
Tech Stack：Godot 4.7.2、GDScript。

- [x] 回归先行：tests/test_mobile_readability.gd，验证设置整页/返回、字号与命中区、游戏快照不变、合成列数、桌面布局保留。先运行确认失败。
- [x] 设置：application/page_host.gd、presentation/settings_panel.gd，整页标题/返回、滚动分类内容、加大设置标题说明及控件、下拉展开菜单、滑条加减。
- [x] 高频控件：presentation/widgets.gd、text_button_art.gd、hud/status_hud.gd、item_card.gd、pages/voyage_hud.gd，统一字号下限、导航及关闭命中区域，四属性仍保持一行。
- [x] 内容页：pages/base_page.gd、flow_story.gd、craft_page.gd、paged_reference.gd、collectibles_page.gd、story_page.gd，扩大正文、手机减少列数/滚动承载、避免剧情文字被整体缩小。
- [x] 验证：新回归、显示/手牌/触摸/剧情回廊相关测试、GPU多尺寸截图、文档检查；隔离用户数据目录。更新当前显示与布局契约，记录真机未验收。

保留已有修改，不自动提交或推送，不打包APK。按本会话逐项实施与复核。

已实施范围以 ../mobile-ui-readability.md 为准；验证见 ../../evidence/mobile-ui-readability-verification.md。图鉴/遗物仍为并排详情，未增加独立文字倍率或150%UI。
