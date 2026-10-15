# 一级滤水器状态验收 · 2026-10-15

结论：一级已区分“过滤中”空桶与“本轮产水”有水桶。2/3级保持有水外观；破损显示过滤暂停。规则、周期、产量、随机及存档字段未改。

| 当次检查 | 结果 |
|---|---|
| test_filter_stages.gd 实现前 | FAIL：没有滤水器阶段选择方法 |
| check_filter_model.py 修复间隙前 | FAIL：桶底与木座共面，实际俯视截图可见条纹 |
| test_filter_stages.gd 最终 | PASS：一级0/1进度、2/3级、真实安装、模型替换、标签、破损暂停、不修改规则快照/RNG；真实两轮结算验证淡水产出与重置 |
| check_filter_model.py 最终 | PASS：两模型非水部分几何相同、空/有水区分、水位、开口未封盖、桶壳每边两面闭合、木座间隙>0.009米；UV、单位法线、有限坐标、无退化面、已烘焙变换 |
| verify_filter_roundtrip.py / Blender5.2.2 | PASS：两个源场景与GLB重导入包围盒误差<0.00001米，网格数、UV、无待应用修改器 |
| filter_visual.gd / Godot4.7.2 Compatibility / RTX4060 | PASS：真实安装空桶、两状态四向近景、1600×900与1280×720实机截图 |
| test_planter_stages.gd | PASS：此前土盆状态回归 |
| test_raft_state_visual.gd | PASS：六设备、损伤/脱落/拆除/燃料及表现与规则隔离 |
| test_mechanics.gd | PASS：现有规则回归 |
| check_blender_raft.py | PASS：16模块，63176资产三角面（不是单帧面数） |

实际打开核对空桶与有水前侧、俯视、背侧/底部及游戏镜头：桶有内壁，空桶内部与水面明显不同；抬高桶底后原共面条纹消失。源模型1156/1188三角面，运行文件81844/84140字节，均<0.1MB。

近景为中性灯光；游戏图通过显式测试赠卡后执行真实安装命令。有水游戏图用隔离进度夹具，不能当作正常航程获得或已结算产出的证明；实际生产由独立命令测试覆盖。未验证发行构建/其他硬件；全筏重建链已接入，此次未执行全筏重新建模。

全项目资产hash检查仍需单独看待：既有 `ui.hud.story-adapter` hash不一致，未修改该无关文件或替它重新登记。滤水器相关绑定另行核对。

- [过滤中近景](filter-v1-waiting-front.png)
- [本轮产水近景](filter-v1-ready-front.png)
- [修复后的空桶俯视](filter-v1-waiting-top.png)
- [有水实机1280](filter-v1-ready-raft-1280.png)
- [过滤中实机1600](filter-v1-waiting-raft-1600.png)

来源与重建见 [资产源记录](../asset-sources/filter-states-v1/README.md)，规则边界见 [状态设计](../docs/filter-production-visuals.md)。
