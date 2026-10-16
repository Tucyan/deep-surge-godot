# 深潮 UI 拆分素材

本压缩包从生图重绘的素材图中提取 4 个主要面板，分别保存为透明背景 PNG：

- `01_left_circle_panel.png`：左侧主面板，中心圆形区域透明。
- `02_top_center_panel.png`：中间上方信息面板，带眼睛、罗盘等装饰。
- `03_bottom_center_panel.png`：中间下方信息面板，带播放按钮。
- `04_right_side_panel.png`：右侧竖向面板，带沙漏与灯塔。

## 使用说明

1. 四张图片均包含 RGBA Alpha 通道，不含原图背景与名称标签。
2. 按需将图片作为 Godot `TextureRect` 纹理导入，建议 `Expand Mode = Ignore Size`，保持纵横比。
3. 图片中复杂装饰并非可直接无损任意缩放的九宫格边框。若要适配任意面板宽高比，建议单独制作 `NinePatchRect` 的角、边和中间区域。
4. 这批素材经过生成式重绘，部分局部细节可能与原始参考图存在差异。
