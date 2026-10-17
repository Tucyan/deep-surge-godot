@tool
extends EditorPlugin
## 只有壳子，一个字的实现都不在这里。
##
## Godot 规定 plugin.cfg 指向的脚本必须 extends EditorPlugin，而 EditorPlugin
## 是编辑器专有类、导出的游戏里没有它 —— 所以这一层不能和实现合并成一个文件，
## 否则游戏发布版会在启动时加载失败。真正的代码全在 blip_voice.gd 里。

const Impl := preload("res://addons/blip_voice/blip_voice.gd")


func _enter_tree() -> void:
	Impl.install(self)


func _exit_tree() -> void:
	Impl.uninstall(self)
