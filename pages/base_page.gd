extends VBoxContainer
signal action_requested(action: String, value: String)
const W = preload("res://presentation/widgets.gd")
var context: Dictionary
var catalog: RefCounted
var assets: RefCounted
var session: RefCounted

func configure_session(value: RefCounted) -> void:
	session = value

func setup(view: Dictionary, content: RefCounted, art: RefCounted) -> void:
	context = view.duplicate(true)
	catalog = content
	assets = art
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build()

func build() -> void:
	pass

func request(action: String, value: String = "") -> void:
	action_requested.emit(action, value)

func heading(title: String, description: String) -> void:
	W.text(self, title, 36, W.GOLD)
	W.text(self, description, 17, W.MUTED)

func inactive_button(parent: Node, title: String) -> void:
	W.button(parent, title + " · 待接入", func(): pass, true, "规则核心尚未迁移，此操作目前不可执行")
