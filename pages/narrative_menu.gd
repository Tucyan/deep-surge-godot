extends RefCounted
## Narrative save pickers shared by the home flow and the settings panel.
## UI only: every mutation goes through FlowApp's narrative methods.
const W = preload("res://presentation/widgets.gd")

static func build_choice(parent: Node, app) -> void:
	W.text(parent, "剧情存档", 28, W.GOLD)
	W.text(parent, "剧情与玩法互不影响。同一份剧情档可被多局挂载，已播放的固定剧情会自动跳过。", 15, W.MUTED)
	var saves: Array = app.narrative_store.list_saves()
	if saves.is_empty():
		W.text(parent, "还没有剧情档。可以新建一份，或选择不启用剧情开局。", 16, W.MUTED)
	for entry in saves:
		W.button(parent, "挂载 · %s（第 %d/%d 段）" % [entry.label, int(entry.beats), app.narrative_content.beats.size()],
			func(): app.pick_narrative(str(entry.id)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var name_input := LineEdit.new()
	name_input.name = "NarrativeName"
	name_input.placeholder_text = "剧情档名称（可留空）"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_input)
	W.button(row, "新建剧情档", func(): app.pick_new_narrative(name_input.text))
	W.button(parent, "不启用剧情", func(): app.pick_no_narrative())
	W.button(parent, "返回", func(): app.local_panel = ""; app.render())

static func build_settings(parent: Node, app) -> void:
	W.text(parent, "剧情", 22, W.GOLD)
	if app.narrative == null or not app.narrative.has_save():
		W.text(parent, "本局未挂载剧情档。剧情只在开局时选择，已有进度仍可在下方查看与使用。", 15, W.MUTED)
	else:
		W.text(parent, "当前：" + app.narrative_status(), 16, W.INK)
		for row in app.narrative.summary():
			W.text(parent, "%s · %d（%s）" % [row.name, int(row.value), row.level], 15, W.MUTED)
		W.button(parent, "保存剧情进度", func(): app.save_narrative())
		W.text(parent, "更换剧情档后，后续节拍按新档的好感与进度走；本局已播放的节拍不会重播。", 14, W.MUTED)
	var saves: Array = app.narrative_store.list_saves()
	if saves.is_empty():
		W.text(parent, "还没有任何剧情档。", 15, W.MUTED)
		return
	W.text(parent, "已有剧情档", 17, W.INK)
	for entry in saves:
		if entry.active: continue
		W.button(parent, "切换至 " + str(entry.label), func(): app.switch_narrative(str(entry.id)))
