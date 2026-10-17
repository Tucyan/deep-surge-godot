# 开场序章素材来源

- `开局剧情整合包（含有文本、图片和背景音乐）(1).zip` SHA256 `29fd06e6a633c542c2a6ecd7c45144c822733a36afce4a9087c0672516350ce2`
- `blip-voice-godot-addon(1).zip` SHA256 `cc5d1612ef134eddea3405ec2179a307cd61534d9dfb41b364bda5197c423469`

五张 PNG 和 OGG 原字节保留于 assets/opening-intro；额外未引用图片不接入。scenes.json 仅重映射路径和新增黑色留白显示区域，旁白不改写。插件 addons/blip_voice 全部文件与 ZIP 原字节一致，运行时仅实例化独立 BlipVoice，不启用编辑器面板或修改全局单例。

稳定 AssetId、各文件 hash、依赖和运行映射见 assets/manifest.json 的 opening.*、audio.blip-voice、ui.opening-intro、ui.game-bootstrap。
