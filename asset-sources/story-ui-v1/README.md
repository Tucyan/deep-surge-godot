# Story UI v1 · 2026-10-14

生成方式：内置 image_gen.imagegen；一次透明 RGBA 生图。参考：`evidence/title-v2-home.png`，仅取黑白/亮蓝、斜切边、半调网点和罗盘的风格，不取菜单文字或布局。

原图 `ui-sheet.png` 2117×743；保留原始字节。运行矩形裁切由 `tools/register_story_ui.py` 执行，未重绘或修改 alpha。版本和精确区域、尺寸、hash、运行映射在 `inventory.json` 和 `assets/manifest.json`。当前仅做风格化界面素材，不将原图作为完整页面截图。

原始提示词：

> Use case: ui-mockup. Generate a PRODUCTION GAME UI SPRITE SHEET, not a screenshot. Reference image is style reference only: Deep Surge's stark ink black / warm white / electric cobalt blue, sharp oblique angular nautical comic collage, compass glints and halftone dots. Output wide landscape transparent RGBA sheet with THREE isolated blank UI panels, no letters, no words, no numbers anywhere. Upper half: one very wide horizontal galgame dialogue panel (aspect ratio 5:1), dark nearly-black opaque interior with large empty text safe area, doubled thin white/blue angular frame, distinctive cobalt slashes on right edge, small compass motif far left, asymmetrical slanted ends. Lower left: one horizontal choice button (aspect 5:1), black center empty for dynamic text, white narrow inner border, cobalt angular outer edge and halftone at far right. Lower right: one small horizontal toolbar button (aspect 3:1), matching black fill, white/cobalt slanted outline, empty center. All three panels must be completely separated by generous fully transparent gutters, contain no background scenery or checkerboard, no baked-in labels or shadows outside their shapes. Dialogue frame should be bold, premium and readable, geometric screenprint visual style matching the reference. Transparent background.
