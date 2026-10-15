# 土盆重建验收 · 2026-10-15

结论：已替换运行模型，原盆框重叠及土层/植株分离问题已修复。未修改玩法、设备 ID、槽位映射和其他运行模型；旧源文件保留。

## 当次验证

| 检查 | 结果 |
|---|---|
| 旧 GLB 回归检查 | 失败，检测到非目标 Cube 节点；原错位另有 planter-audit.md 记录 |
| 新 GLB 几何检查 | PASS：盆框宽/深、甲板间隙、土层位于盆内、茎根接触、植株中心、单位法线、有限坐标、无零面积三角形、UV、已烘焙变换 |
| Blender 5.2.2 源文件打开及 GLB 重导入 | PASS：4 网格批次、UV、无待应用修改器，包围盒误差 < 0.00001 米；详见源目录 roundtrip-validation.json |
| Godot 4.7.2 Compatibility / RTX 4060 Laptop GPU | PASS：真实 install 命令创建土盆、实际状态 ID 正确、四向近景及 1600×900 / 1280×720 截图 |
| test_raft_state_visual.gd | PASS：六设备、损坏、脱落、拆除、燃料及表现与规则状态隔离 |
| test_blender_raft.gd | PASS：初始格位、装饰格拒绝占用、旧布局迁移 |
| check_blender_raft.py | PASS：14 个 GLB 的结构/UV/法线检查，资产合计 60502 三角面 |
| 土盆 manifest | PASS：v2、运行文件 SHA256 匹配、独立 Blender 源存在 |

最新几何、GPU、设备状态与布局输出保存为 [planter-v2-checks.txt](planter-v2-checks.txt)。

## 视觉核对

已实际打开并检查前侧、背侧、俯视、底视及木筏 1280 截图：盆框完整，土层居中，茎根接入土层，底面封闭，无原先悬空或板件塌缩。1600 图同次实际生成。总尺寸 1.19×0.95×0.89 米；盆底局部 y=0.18，与甲板约有 0.02 米间隙，避免穿插。四批次 1508 三角面，GLB 112848 字节。近景为中性灯光；木筏图通过测试夹具赠卡后执行真实安装命令，不表示正常航程获得。

- [近景](planter-v2-front.png)
- [背侧](planter-v2-back.png)
- [俯视](planter-v2-top.png)
- [底视](planter-v2-bottom.png)
- [木筏 1600](planter-v2-raft-1600.png)
- [木筏 1280](planter-v2-raft-1280.png)

## 全项目检查限制

`check_supplied_assets.py` 因既有且本次未修改的 `ui.hud.story-adapter` hash 不一致而失败；独立枚举全部绑定结果为 119 项匹配、该 1 项不匹配。没有把全项目资产检查描述为通过，也未修改无关 HUD 文件或重新登记其 hash。未验证发行构建及其他硬件。

## 复建入口

见 [土盆 v2 源记录](../asset-sources/planter-v2/README.md)。整筏生成脚本末尾会调用独立土盆生成器，登记器保留新来源，避免后续运行整筏工具把旧错误模型重新写回。此次未运行整筏重新建模，以保留其他资产。
