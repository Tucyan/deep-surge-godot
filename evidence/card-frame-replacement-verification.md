# 卡框替换检查（2026-10-17）

用户替换 `assets/images/supplied-ui-20261012/tarot_card_frame.png`，分辨率1024×1536。`ui.card.front` 直接引用此文件，`item_card.gd` 仍从该 AssetId 加载。

检查时缓存 source_md5 为 `0686c6542d68efc6c26c0a7b4272bc20`，与新文件不一致。运行 Godot 4.7.2 `--headless --path . --editor --import --quit` 退出码0，缓存更新为 `0d4c3516199be12e1051be4c9c304e59`，与当前源文件一致。

实际GPU运行 `--path . --script res://tests/nautical_hud_visual.gd`：`NAUTICAL HUD: PASS`，退出码0。已检查 `evidence/nautical-hud-1600x900-100.png`：卡框显示新图的外边、星月图案与底部波纹；此前去掉的类别角标和动作副标题仍未显示。只更新了导入缓存和此素材的来源、版本、尺寸与SHA-256登记；没有修改卡牌布局或规则。旧图来源和hash保留在 previous_source。

当前SHA-256：`06a4eb5372b94bba671b8c35f8305c3e3c4dfcb30062cd4f66559406093ccd89`。
