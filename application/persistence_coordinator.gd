extends RefCounted
## Coordinates profile, difficulty progress and paired story saves. File formats
## and atomic replacement remain owned by the storage adapters.
func _sync_meta_progress(app) -> void:
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

## Challenge/story persistence stores shared purchases and rewards, never a
## resumable run. Story run state belongs exclusively to its paired slot.

func _persist_profile(app) -> bool:
	if not app.persistence or app.save_blocked: return true
	var payload: Dictionary = app.session.snapshot()
	if app.session.state.get("mode", "") != "tutorial": payload.state = {}
	if not app.store.write(payload):
		app.message = app.store.error
		return false
	return true

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
