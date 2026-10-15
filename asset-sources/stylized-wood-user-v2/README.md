# 用户提供的手绘木纹 v2

2026-10-15，直接采用用户上传的五张 1254×1254 PNG。没有裁切、改色、缩放或重编码；运行纹理目录中的 PNG 与附件像素逐字节一致。五张图属于同一暖橙棕色手绘波纹木风格，按上传顺序分别用于盾架、发电机、捕捞网、箱子和木盆。成熟盆与幼苗盆共用木盆图，土、植物、铁件、铜件、机壳、网绳与浮子保持原材质。

木纹粗糙度固定为 0.90；各物件继续使用既有 UV，保持板材纵向或横向的木纹走向。五个输入文件和当前受影响资产的 SHA-256、UV/几何签名见 `application-report.json`。导出的 GLB 嵌入贴图后由 `tools/verify_user_wood_v2.py` 解码，逐像素对比对应用户上传的原图。

应用脚本：`tools/apply_user_wood_v2.py`。它读取先前的版本化 .blend 源，输出新的 Blender 源与 GLB，并确认几何和 UV 未改变。重新导出后先在 Godot 编辑器导入，再执行 `python tools/register_user_wood_v2.py` 记录 GLB 哈希、原图和 Godot 的贴图派生文件。既有 v1 GLB 备份位于 `previous-exports/`，旧可编辑源也仍保留在各 v1/v2/v4 目录。

Godot Compatibility / RTX 4060 预览：`evidence/crate-user-wood-v2-front.png`、`evidence/planter-user-wood-v2-mature-front.png`、`evidence/planter-user-wood-v2-seedling-front.png`、`evidence/equipment-user-wood-v2-raft-fixture-1600.png`。验收记录见 `evidence/user-wood-v2-verification.md`。
