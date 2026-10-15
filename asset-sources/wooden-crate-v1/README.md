# 旧木补给箱 v1 · 2026-10-15

稳定 AssetId：`model.prop.wooden-crate`。运行模型：`assets/models/props/wooden-crate.glb`。编辑源：`wooden_crate_v001.blend` 中的 `Wooden_Crate_v001` 场景。

状态：**staged-not-integrated**。本次只建立模型与资源绑定，不新增设备/卡牌、安装命令、储物容量、物资转移或存档字段。没有替换装饰筏根中原有的木箱。游戏画面中的箱子只出现在独立测试夹具中，不表示箱子玩法完成。

## 造型与坐标

带盖的旧木补给箱；33块独立设计的木板包括底板、四周拼板、角柱、非对称斜撑、盖板和盖上压条。板长、板宽、接缝、端头、轻微弯曲及色差使用固定美术种子35104；边缘有小倒角和轻微不齐。两侧下垂三股绳提手、旧铁钉、背面铰链与前扣为实际几何。避免把整个规则方盒仅贴一张木纹图作为结果。

GLB米制、Y-up；含提手的总尺寸约1.177×0.782×0.878米（宽×高×深），底面y=0。共7000三角面、9网格批次、5材质、5张内嵌图片，文件1404556字节。`CrateBody` 和 `CrateLid` 是分开的父节点，盖子原点在后铰链轴附近；当前只交付静态闭合姿态，没有开盖动画、交互、碰撞体或LOD。

## 木纹资产

原始PNG为 `assets/textures/wooden-crate-v1` 中的5张512×512图片：暖木、深木、灰木三种基色，粗糙度、法线。稳定ID为 `texture.prop.crate.{wood-albedo,wood-dark-albedo,wood-grey-albedo,wood-roughness,wood-normal}`，已登记hash、尺寸、来源、美术种子和依赖。

生成源为 `tools/generate_crate_textures.py`，不调用网络、不消费规则RNG。基色为sRGB，粗糙度与法线为Non-Color；Principled材质直接连接图片节点。每块木板的UV按自身长向铺纹，限制在图片内，避免重复边界造成横截面接缝；侧壁和端面各有UV。贴图已打包到编辑源并内嵌GLB。

Godot常规导入还会在GLB旁生成5张 `wooden-crate_*.png` 派生图片（粗糙度图为glTF打包金属/粗糙度通道），稳定ID为 `texture.prop.crate.imported.*`；这些运行派生图也逐项登记hash、尺寸、原图依赖和生成来源。Godot导入后再次运行登记器可同步派生记录。

## 复建与检查

在Godot项目目录执行：

1. `python tools/generate_crate_textures.py`。
2. 本机Blender后台执行 `--background --python tools/build_wooden_crate.py`；可选 `-- --blockout` 只生成归档体块，不覆盖运行GLB。
3. `python tools/register_crate_asset.py`，仅登记木箱模型与5张纹理。
4. Blender后台执行 `--background --python tools/verify_crate_asset.py`，验证重导入、包围盒、法线、UV、三角面和独立箱盖。
5. Godot先常规导入资源，再执行 `--path . --script tests/crate_visual.gd`，通过AssetCatalog实际加载、缓存、实例化并生成多视角和游戏比例夹具截图。

`build-report.json`记录每块木板尺寸/弯曲、种子、原点和包围盒；`validation.json`为当次导出重导入检查。历史体块位于 `crate_blockout.glb`，不作为运行资产。此次未运行整筏重建、不修改原Blender场景或全局设置。

实际检查与局限见 [验收记录](../../evidence/crate-v1-verification.md)。
