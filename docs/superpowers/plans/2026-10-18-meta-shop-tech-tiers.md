# 局外商店与两层科技实施计划

目标：沿用全屏图鉴的商品展示，科技以两层节点树替换短列表；先实现每层三点、第一层点亮任意两点解锁第二层。

架构：content/data/tech.json 定义 tier、required_previous、独立价格、通用 modifiers。core/tech_rules.gd 统一层数门槛、存档有效性及公开投影；核心 dispatch 的 tech 命令执行扣点及点亮。UI 仅维护当前选择，查询不消费随机。

试测参数：第一层 knowledge 3、endurance 4、craft 6；第二层 spear 9（矛架）、vitality 10（HP上限+2）、tactics 12（战斗AP+1）。第二层任意节点需第一层2点；每点仅一次，不保留旧单线前置链。版本由21升22，明确拒绝旧档，同版恢复必须通过验证。

- [x] 在 tests/test_tech_tiers.gd 先写门槛、报价、状态不变、扣点、属性、重复购买、无效科技档案、同版恢复与旧版拒绝测试；运行确认旧数据失败。
- [x] 修改 tech.json，增加 tech_rules.gd；run_rules.gd 接入点亮与校验，catalog.gd 验证定义，game_session.gd 更新版本与公开树投影；ActionQuery 增加局外面板候选，Agent observe 同步公开科技投影。
- [x] 修改 tests/content.test.mjs 中科技历史对比为当前独立契约，明确数据参数及层门槛。
- [x] pages/paged_reference.gd：成长补给三列两行，价格状态卡片＋详情；科技改两层节点/进度门槛，选择节点显示详情与点亮按钮。全屏路由在 flow_app.gd；预览复用资产，补币/券原生SVG图标。
- [x] 更新 verify_meta_shop.gd：实际鼠标选点、点亮2个解锁第二层、价格/余额变化、已点亮状态、活动局锁定、四组分辨率/缩放截图。回归 verify_encyclopedia.gd、test_clean_ui.gd。
- [x] 运行 Godot action_query、agent_session、tech_tiers 测试，Node内容测试、Python stdio测试；用 tools/validate_survival_discard.py --trace-prefix tech-v22 生成并重放13条完整路线，再以 test_routes.gd 重放v22证据。
- [x] 同步机制、Agent契约、前端说明、资产清单/hash及验证证据；不提交或推送。

执行：当前会话顺序推进，不启动其他线程；复用现有工作区，保留用户已有改动。
