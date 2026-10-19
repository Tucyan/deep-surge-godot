extends RefCounted
## Coordinates profile, difficulty progress and paired story saves. File formats
## and atomic replacement remain owned by the storage adapters.
var save_pending := false
var save_error := ""
var pending_replacement: Dictionary = {}

func blocks(app, command: String) -> bool:
	var changes: bool = command in app.Session.Stats.GAME_COMMANDS or command in ["resume","new","load_story","meta_buy","tech"]
	if changes and save_pending:
		app.message = save_error
		return true
	if changes and app.save_blocked and command != "new":
		app.message = "存档损坏或不兼容，原文件已保留；请明确新建航程。"
		return true
	return false

## Confirmation is tied to the original revision; viewing/canceling never dispatches.
func confirm_replacement(app, command: String, args: Dictionary) -> bool:
	if not app.persistence or args.get("replace_current",false): return true
	if not app.save_blocked and not app.session.active(): return true
	pending_replacement = {"command":command,"args":args.duplicate(true),"revision":app.session.revision}
	app.local_panel = "replace_run"
	app.render()
	return false

static func payload_for(game) -> Dictionary:
	var payload: Dictionary = game.snapshot()
	if game.state.get("mode", "") not in ["tutorial", "challenge"]: payload.state = {}
	return payload

## New runs are written before publishing memory, so failure keeps the old run.
func write_candidate(app, game) -> bool:
	if not app.persistence: return true
	if app.save_blocked and not app.store.preserve_rejected():
		app.message = app.store.error
		return false
	if not app.store.write(payload_for(game)):
		app.message = app.store.error + "；未切换航程，原存档已保留。"
		return false
	return true

func _sync_meta_progress(app) -> void:
	if save_pending or app.save_blocked: return
	if app.session.state.is_empty(): return
	if app.session.phase() not in ["finished","chapterComplete"]: return
	var result: String = str(app.session.state.get("result",""))
	var changed = false
	if result == "survived":
		var before: Dictionary = app.meta.snapshot()
		var opened: Array = app.meta.record_clear(str(app.session.state.get("difficulty","standard")))
		changed = before != app.meta.snapshot()
		if not opened.is_empty():
			var names: Array = []
			for id in opened: names.append(str(app.catalog.entry("difficulties",id).get("name",id)))
			app.message = "通关！已解锁新难度：" + "、".join(names)
	if result == "tutorial" and not app.meta.tutorial_done():
		app.meta.record_clear("tutorial"); changed = true
		if app.message == "": app.message = "新手教程完成；返回首页开始正式航程。"
	if (changed or not app.meta.error.is_empty()) and not app.meta.write_meta(): app.message = app.meta.error

## Challenge/tutorial state and shared rewards commit in the same file.
## Story run state belongs exclusively to its paired slot.

func _persist_profile(app) -> bool:
	if not app.persistence: return true
	if app.save_blocked:
		app.message = "存档损坏或不兼容，原文件已保留；请明确新建航程。"
		return false
	if not app.store.write(payload_for(app.session)):
		save_pending = true
		save_error = app.store.error + "；本次操作尚未保存，异常退出将回到上次保存点。请重试保存。"
		app.message = save_error
		return false
	if app.message == save_error: app.message = ""
	save_pending = false; save_error = ""
	return true

func retry(app) -> bool:
	var saved := true
	if app.session.state.get("mode", "") == "story": saved = save_narrative_quiet(app)
	if not _persist_profile(app): saved = false
	if saved:
		_sync_meta_progress(app)
		if app.meta.error.is_empty(): app.message = "进度已保存"
	return saved

## Separate from retained page layouts so the retry remains visible on home,
## settlement screens and modals as well as on the voyage HUD.
func refresh_notice(app) -> void:
	var existing = app.get_node_or_null("SaveFailureNotice")
	if is_instance_valid(existing): app.remove_child(existing); existing.queue_free()
	if not save_pending or app.local_panel == "quit_unsaved": return
	var W = preload("res://presentation/widgets.gd")
	var host := PanelContainer.new()
	host.name = "SaveFailureNotice"; host.z_index = 500
	app.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	if not app.display_settings.mobile: host.anchor_right = 0.78
	host.offset_left = 20; host.offset_right = -20; host.offset_top = 96
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.045,0.06,0.96)
	style.border_color = Color("b18b63"); style.set_border_width_all(1)
	style.content_margin_left = 14; style.content_margin_right = 14
	style.content_margin_top = 8; style.content_margin_bottom = 8
	host.add_theme_stylebox_override("panel",style)
	var row := HBoxContainer.new(); host.add_child(row)
	var label = W.text(row,save_error,17,Color("efb395"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var retry_button = W.button(row,"重试保存",func(): app.handle_ui("retry_save"))
	retry_button.name = "RetrySave"
	retry_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	retry_button.custom_minimum_size = Vector2(160,44)

## Narrative state and its gameplay snapshot are written in one slot payload.
func save_narrative_quiet(app) -> bool:
	if app.narrative == null or not app.narrative.has_save(): return true
	var id: String = app.narrative_store.active_id()
	if id == "": id = app.narrative_store.create_id()
	var payload: Dictionary = app.narrative.export_data()
	if app.session != null and app.session.state.get("mode", "") == "story": payload.gameplay = app.session.snapshot()
	if not app.narrative_store.write(id, payload):
		app.message = app.narrative_store.error
		return false
	return true
