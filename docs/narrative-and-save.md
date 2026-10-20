# 独立剧情与配对存档
<!-- doc-status: current; doc-role: contract; content-version: godot-flow-v03-03; reviewed: 2026-10-21 -->

剧情模式开发暂停；`flow_app.gd` 的 `story_mode_visible` 默认关闭，相关选档、设置和帮助入口隐藏。本文保留的剧情能力供后续恢复；独立序章、回溯潮涌和普通节点事件仍可用。

当前第一章11个导航节点；章节内容版本为 `chapter1-local-v1`，定义见 [chapter_l1.json](../narrative/content/chapter_l1.json)。本文描述正式入口的当前行为，历史好感演示与旧夜间流程不覆盖它。

## 边界与职责

- 叙事会话不直接读取或修改玩法生命、食水、SAN、AP、手牌、筏格或战斗，只接收voyage/phase投影；core不依赖narrative。
- 好感、线索、剧情道具、休息次数、选项和节拍归叙事状态。剧情坏结局是明确例外：叙事返回ending，由应用协调层调用既有终局/结算路径结束当前航程，不在叙事层发放玩法增益。
- 剧情模式使用单层11航次story档，共用规则执行系统；节点池/天气档独立，饥渴每项1点且不累计挑战式伤害；导入文本与玩法数字冲突时使用本机规则。原文及本地改写记录在 `narrative/content/source/`，不覆写原始来源。

| 模块 | 职责 |
|---|---|
| [NarrativeContent](../narrative/narrative_content.gd) | 加载角色、章节、场景并校验DAG、字段与来源 |
| [NarrativeSchedule](../narrative/narrative_schedule.gd) | 纯调度；当前第一章在navigation按voyage匹配节拍 |
| [NarrativeSession](../narrative/narrative_session.gd) | 剧情状态、准备/完成场景、幂等应用、导出/恢复及配对投影校验 |
| [Chapter1Effects](../narrative/chapter1_effects.gd) | 当前导入章节的线索/道具条件、休息重定向、路径校验与叙事效果 |
| [NarrativeCoordinator](../application/narrative_coordinator.gd) | 持有剧情会话/播放层，选择档案、触发剧情、输入锁和坏结局编排 |
| [PersistenceCoordinator](../application/persistence_coordinator.gd) | 组合剧情与玩法快照、共享profile保存及失败提示 |
| [NarrativeStore](../adapters/narrative_store.gd) | 多槽位文件、活动指针、元数据缓存和失败回滚 |
| [StoryPage](../pages/story_page.gd) | VN播放、两步选项、完成结果；不直接结算玩法 |
| [FlowApp](../flow_app.gd) | 依赖组合与已有页面/测试接口转发 |

## 入口与播放

1. 首页选择剧情模式，先新建或读取剧情档，再进入对应航程；挑战入口不提供剧情档操作。
2. 当前第一章只在navigation且voyage为1～11时查找同号未应用节拍。章节间通用演示调度仍保留，但不是第一章逐节点播放的替代规则。
3. 播放时应用层拒绝玩法命令，不修改规则phase、不消费玩法随机。场景与选项由当前内容提供；保存cursor用于叙事记录，不宣称能精确恢复半句打字进度。
4. 完成结果先校验实际经过的节点/选项，再应用叙事效果并记录节拍；已应用节拍不重复结算。正常剧情结束保存配对槽位，再恢复游戏操作。
5. 坏结局经应用层结束航程、生成结算并保存；当前常规第11节点仍先完成本机生存/终局流程。

当前导入章节的前置条件由Chapter1Effects处理，可能因缺少线索/道具禁用选项，或按休息次数重定向。原通用演示还支持好感门槛过滤及节拍优先级，不将演示的12～15航次样例当作现行第一章内容。信任值限制0～100，完整效果依章节数据；不产生玩法增益。

## 状态和文件布局

| 文件 | 当前用途 |
|---|---|
| `user://narrative/<id>.json` | schema1、chapter/version/label/时间戳、叙事state及配对gameplay快照 |
| `user://narrative/active.json` | 活动槽位ID指针；启动不隐式挂载剧情局 |
| `user://godot-flow-v02.json` | 共享profile、最近结算和单个当前教程/挑战局state；同一文件原子提交 |
| `user://deep-surge-meta.json` | 教程完成、难度解锁与上次选择 |

叙事state包括affinity、flags、items、clues、rest_count、ending、applied_beats、skipped_beats、seen_scenes、choices、cursor和prefs。gameplay使用GameSession.snapshot，含schema2、内容版本、内容指纹、随机算法、revision、state/profile及最近结算。

当前玩法内容为 `godot-flow-v03-03`，指纹包含潮汐遗物及journeys/layers/balance/node_pools/navigation_profiles/weather_profiles/battle_templates/shop_profiles全部定义。玩法状态保存journey（档案ID、层索引、层内航次、Boss胜利记录）、deprivation独立计数、临时节点模板与来源、事件已选随机结果及环境rain_voyage一次性标记。食水费用在确认航行时一次性结算并即时扣除，状态中不再保存待结算的费用锁定；恢复后不得重复结算本次出发的消耗。恢复逐项核对，不接受任意临时敌人、奖励或伪造航耗。配对快照同时保存 `state.collectibles` 的实例、历史、剩余次数与激活标记，以及商店的 `relics/relic_purchased`；恢复进行结构、定义、唯一UID、次数范围及战斗激活阶段校验。漂流遗物堆还保存 encounter 的 `offered/eligible_pool/offer_next_id/picked/picked_uid/offer_source`，恢复校验候选数量、定义、唯一性和阶段；已揭示候选不重抽，已选结果不重发。恢复不重新执行获得奖励、开战触发或抽取货架，详见[潮汐遗物契约](collectible-effects.md)。旧内容版本和指纹不符的玩法档明确拒绝，不作迁移，并保留原文件。

剧情多槽位已经包含配对玩法快照；这不等于挑战模式拥有跨进程多槽位保存。剧情模式加载必须验证当前章节/版本、玩法长度11、mode=story及voyage/phase与已应用节拍一致，再同时替换有效会话。旧版本兼容或迁移不是要求；解析器可容忍的未知字段不代表正式入口承诺旧章节可载入。

## 原子性、奖励与失败恢复

- 挑战/教程的成功命令连同同步自动结算完成后保存完整快照。重启只恢复到首页，查看/取消不dispatch；玩家选择继续才走原resume规则。每次恢复须验证schema、内容版本/指纹、随机算法及状态，恢复不重掷、不重发获取提示。
- 当前只保留一局教程或挑战续玩；新建及切入剧情先确认替换，候选验证和共享写入成功才替换内存。新剧情候选共享提交失败时回滚新槽位与活动指针；加载已有剧情失败恢复原活动指针。剧情两文件仍不承诺跨文件断电事务。
- 共享写入失败保留上次完整档，显示未保存提示和重试。失败未解除时禁止继续规则/购买/会话替换，允许只读查看；当前活动配对剧情的明确恢复保留既有补领路径。待保存期间不触发后续剧情。正常关闭会重试，失败可返回或明确退出并放弃未保存操作。
- 挑战积分和终局状态在同一快照原子提交；终局保存失败后重启回到旧检查点，重新完成结算仍只获得一次应得积分。没有写成功的最新内存操作不作持久化承诺。终局重启不再次发奖，首页显示最近结算摘要且不提供活动续玩。
- 难度解锁在共享终局提交成功后写入独立meta文件；meta写失败时下次启动从有效终局幂等补写，不重新执行结算或奖励。损坏/不兼容共享文件在普通操作中保持原样；明确新建前另存 `.rejected-<时间>-<序号>.json` 原始字节，备份失败取消替换。

- 槽位写入经过临时文件、flush/错误检查和rename，失败提示冒泡到app.message，不把失败当作保存成功。
- 新建/挂载先准备候选；槽位与活动指针提交成功后才替换内存。跨档写入若指针提交失败，恢复旧槽位或移除未挂载新档；已挂载槽位保存不重写指针。解绑先成功写空指针。
- `profile.run_rewards` 按玩法run_id记录 `{points,result}`；积分与领取凭据在同一共享文件原子写入，配对槽位保留对应凭据。两文件独立提交，任一失败均显示失败。
- 共享文件先成功时，旧槽位再次结算按run_id去重；配对槽位先成功时，加载终局档仅补领缺失凭据/积分，不覆盖当前购买或其他航程记录。手动保存同时重试共享进度。
- run_rewards是schema2可选字段；同内容版本缺少它的旧数据可被解析，但无凭据历史终局不自动补奖，不能可靠推断过去是否到账。此处不承诺跨文件断电事务，也不追溯修复引入凭据前的差异。
- 自动保存失败提示优先于好感提示；成功重试清除错误。损坏、版本或配对不匹配时保留原文件，不替换当前有效状态。
- 槽位元数据在成功写入/挂载后失效，进入选档页显式刷新；普通HUD只读存在标记。真实加载仍读取文件并做完整配对校验。

## 已实现与范围限制

已实现独立11节点章节、导入来源保留、叙事条件/效果、坏结局终局、多剧情槽位和配对玩法恢复。游戏命令失败或无效挑战新局不能丢失原剧情会话；挑战候选验证成功后才切换两个会话。

挑战单档跨进程续玩已接入；只承诺最后一次成功保存的完整操作。临时文件、flush和rename经过进程强杀及I/O失败验证，不等于物理断电保证；写入/rename系统调用内部杀死、触摸和发行包尚未验证。实际结果见[挑战中断恢复验证](../evidence/challenge-resume-verification-20261019.md)。

新独立剧情档的已读场景尚未接入回廊；旧回廊只展示五幕序章与原本地旧归档，见 [回廊契约](story-gallery.md)。第二章、完整角色语音系统、挑战跨进程多槽位等不在当前能力声明内。

0.3挑战为25航次三层，Ⅰ/ⅡBoss获胜不生成整局成功/难度解锁；最终存活结算才成功。转层保留筏格、设备、资源、成长、环境剩余时间及随机流；无额外恢复/重复生产。旧剧情11航次、章节版本及旧回廊例外保留，见[配置契约](v03-configuration.md)。

## 验证入口

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_narrative.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_narrative_flow.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_narrative_repairs.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_reward_recovery.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_mode_contract.gd
python tools/verify_challenge_resume.py
python tools/verify_challenge_resume.py --tests test_challenge_resume.gd test_challenge_save_failure.gd test_challenge_story_switch.gd test_challenge_meta_recovery.gd
python tools/verify_challenge_resume.py --gpu --tests test_challenge_save_ui.gd
```

测试须隔离APPDATA/LOCALAPPDATA。奖励恢复测试以目录占用.tmp注入真实I/O失败，覆盖两种文件提交失败方向、磁盘重新加载、手动重试和去重；模式契约覆盖候选失败保留、当前revision和成对提交。

已执行结果见 [2026-10-19架构验证](../evidence/architecture-health-verification.md)，不把此处的命令列表当作本次文档修改重新执行过游戏验收。GPU/触摸/发行包单独验证。改写前的说明保存在 [历史快照](archive/context-20261019/docs--narrative-and-save.md)。
