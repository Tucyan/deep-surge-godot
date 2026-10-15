# 用户木纹 v2 应用复核

2026-10-15，按五张附件顺序映射：盾架、发电机、捕捞网、箱子、木盆（成熟与幼苗共用）。五张图都是暖棕波纹木纹，但像素各自保留，不拼成图集；运行时只为对应类别加载那张图。

Blender 5.2 将新贴图接入已有材质节点、贴图 sRGB、木材粗糙度 0.90。箱子与六个 GLB（成熟/幼苗木盆加四种设备）均另存版本化 `.blend`，当前模型源中的全部顶点世界位置与 UV 坐标 SHA-256 与贴图应用前一致。六个 GLB 的木材材质统一指向该类别的一张嵌入图，基色为白以完整显示输入纹理。箱子、两种土盆、盾架、发电机、捕捞网的独立近景在 Godot RTX 4060 Compatibility 视口绘制正常；木筏画面沿用夜景，木纹在远景下较柔和。

现场复核：`tests/crate_visual.gd -- --stylized --user-wood-v2`、`tests/planter_visual.gd -- --stylized --user-wood-v2`、`tests/equipment_models_visual.gd -- --user-wood-v2 --fixture` 均输出 PASS。游戏镜头截图是摆放夹具，不代表已为存档安装设备。需要在导入后核对 GLB 所嵌入的贴图是否与对应附件逐像素一致：`python tools/verify_user_wood_v2.py`。
