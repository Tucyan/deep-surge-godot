# 土盆 v2 · 2026-10-15

稳定 AssetId：`model.raft.module.planter`。运行文件：`assets/models/raft-modules/planter.glb`；可编辑源：`planter_v002.blend`。原始部件来自项目自有 `raft-model/raft_v004.blend`，原文件与 raft_modules_v001–v005 均保留。旧错误 GLB 归档为 `planter-before.glb`，不用于运行。

旧模块存在盆框塌缩、土层与植株分离。新生成器 `tools/rebuild_planter.py` 先快照全部 55 个部件的求值世界坐标，再整体缩放、平移，避免在复制/重置变换期间读取不同步的数据。保留 11 根茎、33 片叶，补上盆底。四个材质批次、1508 三角面、112848 字节，米制，GLB Y-up；总体包围盒 1.19 × 0.95 × 0.89 米，底面 y=0.18，高于局部甲板顶约 0.02 米。木材、土与双色叶材质均为可导出的 Principled PBR 常量，叶片双面；无规则随机或运行时几何。

在项目目录运行 Blender 后台脚本 `tools/rebuild_planter.py`，随后执行 `python tools/register_planter_model.py` 和 `python tools/check_planter_model.py`。旧整筏生成器末尾也会调用此独立生成器；`register_blender_raft.py` 保留独立土盆源映射。其余模块保持原有生成链。

验证：`tools/verify_planter_roundtrip.py` 用后台 Blender 打开可编辑源并重导入 GLB，验证四批次、UV、无待应用修改器和包围盒误差 < 0.00001 米。`tests/planter_visual.gd` 用 Godot GPU 拍摄四向近景，并通过真实 install 命令安装土盆，拍摄两种分辨率；赠卡仅为该测试的显式夹具，不表示正常航程获取。

当次验证与局限见 `evidence/planter-v2-verification.md`。没有执行发行构建或其他设备测试。
