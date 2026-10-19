extends RefCounted
## Owns narrative coordinator responsibilities; app is the composition boundary.
const Session = preload("res://core/game_session.gd")
const W = preload("res://presentation/widgets.gd")
const NarrativeContent = preload("res://narrative/narrative_content.gd")
const NarrativeSession = preload("res://narrative/narrative_session.gd")
const NarrativeStore = preload("res://adapters/narrative_store.gd")
var narrative_content: RefCounted
var narrative_store: RefCounted
var narrative: RefCounted
var narrative_overlay: Control
var narrative_playing := false
var pending_narrative: Dictionary = {}
var story_replay: Control

func _init_narrative(app) -> void:
	narrative_store = NarrativeStore.new()
	narrative_content = NarrativeContent.new()
	if not narrative_content.load_content():
		app.message = "剧情内容载入失败：" + narrative_content.error
	narrative = NarrativeSession.new(narrative_content)
	# No implicit attachment on startup. Mode selection is the only load entry.


func _apply_pending_narrative(app) -> void:
	if str(app.session.state.get("mode", "")) != "story":
		narrative.clear()
		pending_narrative = {}
		return
	var mode = str(pending_narrative.get("mode", ""))
	if mode == "": return
	if str(app.session.state.get("mode", "")) != "story":
		pending_narrative = {}
		return
	match mode:
		"attach": app.attach_narrative(str(pending_narrative.get("id", "")))
		"new": app.create_narrative(str(pending_narrative.get("label", "")))
		_: app.detach_narrative()
	pending_narrative = {}


func pick_narrative(app, id: String) -> void:
	if DisplayServer.get_name() == "headless":
		app.load_story_run(id)
	else:
		app.request_command("load_story",{"id":id})

## Prepare the entire new run and slot before replacing any active memory.

func _start_story_run(app, args: Dictionary) -> void:
	if pending_narrative.get("mode", "") != "new":
		app.local_panel = "narrative"; app.setup_mode = ""; app.render(); return
	if args.get("difficulty", "") == "tutorial":
		app.message = "剧情模式请选择正式航程难度"; app.render(); return
	var candidate = Session.new(app.catalog)
	candidate.profile = app.session.profile.duplicate(true)
	if not candidate.dispatch("new", args):
		app.message = candidate.error; app.render(); return
	var story = NarrativeSession.new(narrative_content)
	story.new_save(str(pending_narrative.get("label", "")))
	var payload: Dictionary = story.export_data()
	payload.gameplay = candidate.snapshot()
	var id: String = narrative_store.create_id()
	if not narrative_store.write(id, payload):
		app.message = narrative_store.error; app.render(); return
	app.session = candidate; narrative = story
	pending_narrative = {}; app.setup_mode = ""; app.local_panel = ""; app.save_blocked = false
	app.message = ""; app.hand_layout.order.clear(); app.ui_state.nav_select = ""
	app.world_view.reset_camera_view()
	app.meta.set_last_difficulty(str(args.get("difficulty", "standard")))
	if app.persistence and not app.meta.write_meta(): app.message = app.meta.error
	app._persist_profile()
	app.render(); app._maybe_story()


func load_story_run(app, id: String) -> bool:
	var payload: Dictionary = narrative_store.read(id)
	if payload.get("chapter", "") != "chapter1" or payload.get("version", "") != narrative_content.version or not payload.get("gameplay") is Dictionary:
		app.message = "此剧情档不含兼容的11节点航程；原档已保留，请新建剧情档。"
		app.render(); return false
	var game = Session.new(app.catalog)
	var story = NarrativeSession.new(narrative_content)
	if not game.restore(payload.gameplay) or game.state.get("mode", "") != "story" or int(game.state.get("length", 0)) != 11:
		app.message = "剧情航程存档无效，已保留原文件。"; app.render(); return false
	if not story.load_data(payload):
		app.message = story.error; app.render(); return false
	if not story.matches_run_projection(int(game.state.voyage), game.phase()):
		app.message = "剧情与航程节点不一致，已保留原文件。"; app.render(); return false
	if not narrative_store.set_active(id):
		app.message = narrative_store.error; app.render(); return false
	# Profile is shared meta progress, not rewound by loading an older run slot.
	game.profile = app.session.profile.duplicate(true)
	var recovered: bool = game.Rewards.recover(game.profile, game.state, payload.gameplay.profile)
	game.screen = "game"; game.panel = game.event_panel()
	app.session = game; narrative = story
	app.setup_mode = ""; app.local_panel = ""; pending_narrative = {}; app.message = ""
	app.hand_layout.order.clear(); app.ui_state.nav_select = ""; app.world_view.reset_camera_view()
	if recovered: app._persist_profile()
	app.render(); app._maybe_story()
	return true


func pick_new_narrative(app, label: String) -> void:
	pending_narrative = {"mode":"new", "label":label}
	app.local_panel = ""
	app._remove_modal_layer()
	app.handle_ui("setup", "story")


func pick_no_narrative(app) -> void:
	app.message = "剧情模式必须选择新建或读取剧情档。"
	app.local_panel = "narrative"; app.setup_mode = ""; app.render()


func attach_narrative(app, id: String) -> bool:
	if id == "" or narrative == null: return false
	var data: Dictionary = narrative_store.read(id)
	if data.is_empty():
		app.message = "剧情存档不存在"
		return false
	var candidate = NarrativeSession.new(narrative_content)
	if not candidate.load_data(data):
		app.message = candidate.error
		return false
	if not narrative_store.set_active(id):
		app.message = narrative_store.error
		return false
	narrative = candidate
	return true


func create_narrative(app, label: String) -> bool:
	if narrative == null: return false
	var candidate = NarrativeSession.new(narrative_content)
	candidate.new_save(label)
	var id: String = narrative_store.create_id()
	if not narrative_store.write(id, candidate.export_data()):
		app.message = narrative_store.error
		return false
	narrative = candidate
	return true


func detach_narrative(app) -> void:
	if narrative == null: return
	if not narrative_store.set_active(""):
		app.message = narrative_store.error
		return
	narrative.clear()


func switch_narrative(app, id: String) -> void:
	if app.attach_narrative(id):
		app.message = "已挂载剧情档：" + narrative.label()
		app.render()


func save_narrative(app) -> void:
	if narrative == null or not narrative.has_save(): return
	var saved = app.save_narrative_quiet()
	if not app._persist_profile(): saved = false
	if saved: app.message = "剧情进度已保存"
	app.render()


func narrative_status(app) -> String:
	if narrative == null or not narrative.has_save(): return "本局未挂载剧情档"
	return "%s · 第 %d/%d 段" % [narrative.label(), narrative.applied_count(), narrative_content.beats.size()]

## Opens the next due beat. Only stable phases qualify (see narrative_schedule).

func _maybe_story(app) -> void:
	if app._defer_transition_render or app.transition_busy: return
	if narrative_playing or narrative == null or app.session == null: return
	if app.session.state.is_empty() or app.session.screen != "game": return
	# Narrative beats belong to story runs; challenge and tutorial are self-contained.
	if app.session.state.get("mode","") != "story": return
	if not narrative.has_save(): return
	var beat: Dictionary = narrative.next_beat(int(app.session.state.get("voyage", 1)), app.session.phase())
	if beat.is_empty(): return
	var scene: Dictionary = narrative.begin(str(beat.id))
	if scene.is_empty(): return
	app._open_narrative(narrative.prepare_scene())


func _open_narrative(app, scene: Dictionary) -> void:
	narrative_playing = true
	if is_instance_valid(app.current_page): app.disable_buttons(app.current_page)
	narrative_overlay = preload("res://pages/story_page.gd").new()
	narrative_overlay.name = "NarrativeOverlay"
	narrative_overlay.z_index = 400
	app.add_child(narrative_overlay)
	narrative_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	narrative_overlay.story_completed.connect(app._on_narrative_completed)
	var response: Dictionary = narrative_overlay.load_story(scene)
	if not response.get("ok", false):
		app.message = "剧情载入失败：" + str(response.get("error", ""))
		app._close_narrative()


func _on_narrative_completed(app, result: Dictionary) -> void:
	var changes: Dictionary = narrative.finish(result)
	if not narrative.error.is_empty():
		app.message = narrative.error
		return
	if changes.has("ending"):
		# A narrative bad ending closes this story run through existing settlement.
		app.session.finish("story_bad_end")
		app.session.state.result_text = "剧情结局：" + str(changes.ending)
		app.session.state.settlement = app.session.Settlement.create(app.session.state, app.catalog, "run")
		app.session.last_settlement = app.session.state.settlement.duplicate(true)
	var saved = app.save_narrative_quiet()
	if not app._persist_profile(): saved = false
	app._close_narrative()
	var parts: Array = []
	for id in changes.get("affinity", {}):
		if narrative_content.character(id).is_empty(): continue
		var delta = int(changes.affinity[id])
		parts.append("%s %s%d" % [narrative_content.character(id).name, "+" if delta > 0 else "", delta])
	if saved and not parts.is_empty(): app.message = "好感度：" + "、".join(parts)
	if saved and changes.has("ending"): app.message = "剧情结局：" + str(changes.ending)
	app.render()
	app._maybe_story()


func _close_narrative(app) -> void:
	narrative_playing = false
	if is_instance_valid(narrative_overlay):
		app.remove_child(narrative_overlay)
		narrative_overlay.queue_free()
	narrative_overlay = null


func _open_story_review(app, id: String) -> void:
	if app.local_panel != "recall" or is_instance_valid(story_replay): return
	var record: Dictionary = app.story_gallery.entry(id)
	if record.is_empty(): return
	var replay = preload("res://presentation/opening_intro.gd").new()
	replay.name = "StoryReplay"; replay.z_index = 300
	replay.persist_completion = false
	replay.exit_label = "返回回廊"
	if id != "opening":
		var scenes: Array = []
		var cover: Texture2D = preload("res://pages/story_gallery.gd").cover(record, app.assets)
		for line in record.lines + record.results:
			scenes.append({"texture":cover,"narration":[line]})
		if scenes.is_empty(): replay.free(); return
		replay.playback_data = {"scenes":scenes,"music":"res://assets/opening-intro/music.ogg"}
	var origin = app.get_viewport().gui_get_focus_owner()
	story_replay = replay
	app.add_child(replay)
	var title = W.text(replay.canvas, record.title + (" · 特殊剧情" if record.special else ""), 24, W.GOLD)
	title.position = Vector2(500, 52); title.size = Vector2(600, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay.finished.connect(func():
		app.remove_child(replay); replay.queue_free(); story_replay = null
		if is_instance_valid(origin): origin.grab_focus())
