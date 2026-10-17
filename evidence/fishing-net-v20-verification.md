# 捕捞网单格模型修订 v20

2026-10-17。捕捞网此前模型包围盒中心沿格子纵深偏移约 0.753m，导致安装后主体挤到相邻格。模型 v004 水平居中并按水平面缩放 0.92，保留高度、绳网几何、材质和 UV。

筏格间距为 X=2.35m、Z=2.10m。Blender 源坐标转换到 Godot 后，模型范围为 X ±0.567m、Z ±0.907m；格边余量分别为 0.608m、0.143m。垂直范围保持 Blender Z=-0.173 至 1.192m。导出 GLB 的 POSITION 包围盒与源范围吻合。GLB hash：`9eef8b70db2df583c53796728cc6c27deea6ad3a56cb8877db26cdf3db7d785d`。Blender 脚本已导出 v004 源与 GLB，并对包围盒执行单格范围断言；Godot 游戏内截图验收未运行。中性光照预览见 `fishing-net-v20-preview.png`。

复建与源说明见 [木筏统一木纹与设备模型](../asset-sources/raft-wood-unified-v1/README.md)。

## 2026-10-17 游戏内外伸问题复核

此前的独立 GLB/Blender 检查不足以确认运行时更新。实际 Godot 导入场景仍为旧模型，Godot Z 范围为 -0.233223 至 1.738471m；测试先复现“缓存与源不一致”和“超出格子”两项失败。完成 Godot `--headless --editor --path . --import` 后，同一 AssetCatalog 入口加载的范围更新为 X ±0.566720m、Z ±0.906979m，与原始 GLB 一致。

使用 Godot 4.7.2 Compatibility / RTX 4060 执行 `--path . --rendering-method gl_compatibility --script res://tests/test_fishing_net_fit.gd -- --visual`，退出码 0、`FISHING NET RUNTIME FIT: PASS`。已查看 `fishing-net-runtime-top.png` 与 `fishing-net-runtime-oblique.png`，网体完整处于单格木板轮廓内。截图为运行模型与甲板夹具，不代表完整玩法重放。已启动的游戏仍须重启以释放 AssetCatalog 内存缓存。
