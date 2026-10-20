# 环境与天气投放（0.3）

2026-10-21核对。效果定义在[environments](../content/data/environments.json)，投放定义在[weather_profiles](../content/data/weather_profiles.json)，由当前层引用；[EnvironmentRules](../core/environment_rules.gd)只管理生命周期、修正请求与公开投影，不直接增删候选。当前参数均为试测。

## 当前环境

| ID/名称 | 效果 | 持续/池权重 |
|---|---|---|
| fog1 / 迷雾Ⅰ | 每候选35%隐藏详情，保留名字/类型 | 2航次/负面4 |
| fog2 / 迷雾Ⅱ | 只显示类型 | 2航次/负面1 |
| fog3 / 迷雾Ⅲ | 隐藏名字/类型/详情；确有非战斗候选时保留一条可辨路径 | 1航次/不随机投放 |
| bloodMoon / 血月 | 敌人直接伤害+1，普通胜利额外币1；挑战战斗类别相对权重×1.3 | 2航次/负面3 |
| confusion / 混乱 | 移动25%概率偏航到另一候选，只记实际访问 | 2航次/负面2 |
| headwind / 逆流 | 每航次首次成功制造或安装额外1AP，共享一次标记 | 2航次/不随机投放 |
| current / 顺流 | 出发结算食水费用各−5，可叠避浪 | 2航次/正面3 |
| spring / 漂流丰收 | 下次实际涌泉额外随机基础资源1，领取后移除 | 消费时移除/正面1 |
| rain / 暴雨 | 每航次开始、生产前损坏2～3个不同完好功能格（含空格）；额外饱食+15 | 2航次/ⅡⅢ负面3 |
| battleSquall / 猎潮 | 普通导航所有3槽战斗，合法节点不足用当前层授权模板；战斗权重×2 | 2航次/ⅡⅢ负面3 |

暴雨只选择intact，已破损/脱落格不再命中；不足2格时取全部可用格，无完好格时不抽随机，不直接脱落。每次实际新航次只执行一次，战斗回合不重触发；破损保留设备但停产，后续正常维修/老化规则照常。2航次/+15为当前试测值，2～3 distinct/no-detach为明确语义，不复用会二次脱落的通用DamageCell。

## 投放与保护

Ⅰ和story保留旧六种随机池，Ⅰ不投新暴雨/猎潮；story禁用新增导航乘数，教程不抽环境。Ⅱ/Ⅲ在旧池增加暴雨/猎潮，各权重3。首个层内航次和层末Boss不新增抽取，已有环境仍有效、剩余时间跨层保留。其他航次按难度负面+正面总概率尝试，再按比例选类别和合法权重抽一个；类别无合法项不重抽。profile倍率当前均1，最早层内第2航次。

最多3环境、负面最多2，待生效也占额。同种刷新时间不叠数值，当前生效中再次获得待生效同种时记pending_refresh，轮末获得完整新期限；雾仅留最高级，fog3/confusion互斥。节点AddBuff从下一航次生效，轮初抽到立即生效；轮末老化后、容量整理前计时，战斗不额外计时。spring等实际领取后移除。

Environment.navigation_modifiers返回软category_weights、minimum_battles、all_battles及授权battle_templates；全战斗指全部3槽，不能用权重假冒保证。[候选生成器](../core/navigation_rules.gd)先挑合法战斗，缺额才补模板，不增加第4槽；教程/固定Boss/Ⅰ安全优先。内容校验拒绝安全冲突、无合法模板或无法补足的配置。候选与迷雾结果生成后固定，查看/侦察/取消/恢复均不重抽。

## 侦察、导引与保存

公开可见性full/detailsHidden/typeOnly/unknown。隐藏候选不带真实节点ID、敌人、选项或奖励，仍用visit_id选择。Boss完整可见且免偏航。

- scout：导航支付SAN8，愚者每航次首次有效侦察4，支付后至少1；不能重复支付已知候选。
- fix_heading：有偏航风险时木头1、0AP，只保护本次移动。
- 灯塔请求导引需完好燃灯，0AP且不耗燃料；下一航次公开所有候选，混乱风险降为10%。

state.buffs保存id/active_from/remaining/pending_refresh；state.environment保存rolled/settled/rain_voyage标记、可见性/侦察、定向/导引、逆流首次标记和最近移动。环境抽取与暴雨只耗environment流，偏航只耗movement流。save/restore校验ID、期限、互斥、数量及标记，雨读档不重复生效。快照schema2、godot-flow-v03-03，旧版本拒绝并保留。

HUD显示环境名称、待生效、剩余与刷新说明；挑战航次显示`Ⅱ · 航行3/10`。Agent同用environments/navigation及enemy_direct_damage，不公开环境池、原始效果配置或随机流。真实规则雾与3D表现雾独立。

验证：`tests/test_v03_weather.gd`（正式Ⅱ池抽样、软/硬请求、雨真实dispatch生产顺序、缺格、RNG隔离、恢复/恶意配置）、`test_v03_encounters.gd`（3槽模板补位）、`test_environment.gd`（原雾/刷新/导引）、`test_difficulty.gd`（story旧池难度概率）。当次结果见[0.3验证草稿](../evidence/v03-development-verification.md)，历史引入证据仍见[环境v12](../evidence/environment-v12-verification.md)。
