extends RefCounted
## Mode-scoped story slots. Each slot owns its narrative and gameplay snapshot.
const W = preload("res://presentation/widgets.gd")

static func build_choice(parent: Node, app) -> void:
	W.text(parent, "剧情模式", 28, W.GOLD)
	W.text(parent, "第一章共11个节点，每个节点出发前播放剧情。其余航行规则与挑战模式一致。", 15, W.MUTED)
	W.text(parent, "读取将同时恢复这份剧情档的航程、选择和人物信任。", 15, W.MUTED)
	var saves: Array = app.narrative_store.list_saves(true)
	if saves.is_empty(): W.text(parent, "还没有剧情存档，请先新建。", 16, W.MUTED)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 150
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry in saves:
		var compatible: bool = entry.get("paired", false)
		var label := "读取 · %s（%d/11段）" % [entry.label, int(entry.beats)] if compatible else "旧剧情档 · %s（缺少对应航程，已保留）" % entry.label
		var button := W.button(list, label, func(): app.pick_narrative(str(entry.id)))
		button.disabled = not compatible
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var name_input := LineEdit.new()
	name_input.name = "NarrativeName"
	name_input.placeholder_text = "剧情档名称（可留空）"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_input)
	W.button(row, "新建剧情档", func(): app.pick_new_narrative(name_input.text))
	W.button(parent, "返回", func(): app.local_panel = ""; app.render())

static func build_settings(parent: Node, app) -> void:
	W.text(parent, "剧情", 22, W.GOLD)
	if app.session.state.get("mode", "") != "story" or not app.narrative.has_save():
		W.text(parent, "选择首页的剧情模式后，可以新建或读取剧情存档。挑战模式不使用剧情存档。", 15, W.MUTED)
		return
	W.text(parent, "当前：" + app.narrative_status(), 16, W.INK)
	for row in app.narrative.summary():
		W.text(parent, "%s · %d（%s）" % [row.name, int(row.value), row.level], 15, W.MUTED)
	var state: Dictionary = app.narrative.data.state
	W.text(parent, "剧情道具：" + "、".join(state.get("items", [])), 15, W.MUTED)
	W.text(parent, "本档线索：" + "、".join(state.get("clues", [])), 15, W.MUTED)
	W.button(parent, "保存剧情与航程进度", func(): app.save_narrative())
	W.text(parent, "读档和新建请返回首页，选择剧情模式。", 14, W.MUTED)
