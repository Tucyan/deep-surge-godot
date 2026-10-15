# 全量工程快照提交前检查

2026-10-16。用户明确要求将其他作者的未提交修改一并提交。范围为Godot独立仓库；不包含根设计仓库，不自动合并main。

- 12项相关规则/流程检查通过：spring_supply、health_balance、save、round_start_production、battle_actions、combat_integration、new_equipment、action_query、agent_session、routes、encounter_node_balance、node_balance_exploration。
- Node内容检查9项通过，独立Agent stdio进程测试3项通过。
- `test_story.gd`学者封闭/拖离/紧急撤离及独航四条15站路线通过。
- 储物箱当前实际容量已由其他修改更新为3/6/9；将旧测试的一级+1断言同步为+3，未修改玩法数值。
- 同步10项已修改程序化资产的文件hash、登记版本和复核日期，保持资产ID。`check_supplied_assets.py`通过168项hash绑定、20张原始PNG及原海面GLB完整性。
- 当前统一木筏木纹采用粗糙度0.80，`verify_raft_wood.py`像素、材质、几何/UV记录及Godot派生纹理检查通过。此前运行的用户木纹v2粗糙度0.90验证器属于旧方案，不代表现用模型验收；不据旧规则重写模型。
- 待纳入文件无超过90MiB的单文件；沿用现有忽略规则排除Godot缓存、日志、builds、Python缓存和Blender备份。

此记录是本次实际执行的检查范围，不表示每个历史UI/资产验证脚本、Android真机或独立构建均重新验收。
