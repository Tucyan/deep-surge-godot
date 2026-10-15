# 滤水器两状态源记录 · 2026-10-15

编辑源 `filter_states_v001.blend` 包含 `Filter_waiting_v001` 与 `Filter_ready_v001`。源自项目自有 `raft-blender-v1/raft_modules_v005.blend`，原源保留；旧运行GLB归档为 `filter-before.glb`。

| 稳定 AssetId | 文件 | 三角面 | 字节 |
|---|---|---|---|
| model.raft.module.filter-waiting | assets/models/raft-modules/filter-waiting.glb | 1156 | 81844 |
| model.raft.module.filter | assets/models/raft-modules/filter.glb | 1188 | 84140 |

GLB为米制、Y-up。等待状态5网格/6材质表面，有水状态6网格/7表面。高位滤桶、支架、滤布、出水嘴和木座继承原模型。原实心接水桶改为24段、有内外壁及封闭底部的空心桶；外半径0.255、内半径0.229米，桶底y=0.325、内底0.35、桶口0.59；木座顶0.315，间隙0.01米。有水状态另有半径0.226米、水位y=0.552的水面；等待状态无水面。无新增图片或纹理随机。

生成器 `tools/refine_filter_states.py` 在独立后台Blender会话读取v005、快照世界坐标、移除原接水桶和原水面，保留其余部件，然后建立两种场景。导出限于当前场景；保存独立源，不修改用户正在运行的Blender。整筏生成器末尾已接入该步骤。登记器 `register_filter_states.py` 只更新两个滤水器绑定及表现层hash/依赖，并与土盆/整筏登记器串联，避免覆盖新来源。

在Godot项目目录运行本机Blender `--background --python tools/refine_filter_states.py`，随后 `python tools/register_filter_states.py`。几何检查：`python tools/check_filter_model.py`；Blender后台重导入检查：`tools/verify_filter_roundtrip.py`；Godot命令测试：`--headless --path . --script tests/test_filter_stages.gd`；实机截图：`--path . --script tests/filter_visual.gd`。

`build-report.json` 记录关键尺寸；`roundtrip-validation.json` 记录两状态的重导入包围盒/UV检查。映射语义见 [状态设计](../../docs/filter-production-visuals.md)，当次结果见 [验收](../../evidence/filter-v1-verification.md)。
