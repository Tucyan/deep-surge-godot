extends Control
const Session = preload("res://core/game_session.gd")
const Catalog = preload("res://content/catalog.gd")
const Assets = preload("res://presentation/asset_catalog.gd")
const Store = preload("res://adapters/save_store.gd")
const Meta = preload("res://adapters/meta_store.gd")
const Tutorial = preload("res://core/tutorial_rules.gd")
const W = preload("res://presentation/widgets.gd")
const World = preload("res://presentation/voyage_world.gd")
const SettlementPage = preload("res://pages/settlement_page.gd")
const NarrativeContent = preload("res://narrative/narrative_content.gd")
const NarrativeSession = preload("res://narrative/narrative_session.gd")
const NarrativeStore = preload("res://adapters/narrative_store.gd")
const NarrativeMenu = preload("res://pages/narrative_menu.gd")
const PAGES := {"home":preload("res://pages/flow_home.gd"),"setup":preload("res://pages/new_game_setup.gd"),"game":preload("res://pages/voyage_hud.gd"),"story":preload("res://pages/flow_story.gd"),"battle":preload("res://pages/flow_battle.gd"),"craft":preload("res://pages/craft_page.gd"),"build":preload("res://pages/craft_page.gd"),"raft":preload("res://pages/paged_reference.gd"),"shop":preload("res://pages/shop_page.gd"),"encyclopedia":preload("res://pages/paged_reference.gd"),"meta_shop":preload("res://pages/paged_reference.gd"),}
var catalog := Catalog.new()
var assets := Assets.new()
var store := Store.new()
var meta := Meta.new()
var session: RefCounted
var current_page: Control
var layout: Control
var title_backdrop: Control
var setup_mode := ""
var message := ""
var save_blocked := false
var persistence := true
var display_settings = preload("res://presentation/display_settings.gd").new()
var settings_tab := "display"
var camera_binding_capture := false
var hand_layout = preload("res://presentation/hand_layout.gd").new()
var world_view: TextureRect
var local_panel := ""
var reset_hand_visual := false
var ui_state := {"hand_page":0,"list_page":0,"selected_id":"","category":"","card":"","battle_selection":"","craft_tab":"craft","transmute_target":"wood","transmute_uids":"","transmute_count":1}
var event_target_surface: Node3D
## Narrative is an independent layer: it reads a projection, never GameState.
var narrative_content: RefCounted
var narrative_store: RefCounted
var narrative: RefCounted
var narrative_overlay: Control
var narrative_playing := false
var pending_narrative: Dictionary = {}
# Temporary legacy gallery: read archived records; new narrative replay is separate.
var story_gallery = preload("res://adapters/story_gallery_store.gd").new()
var story_replay: Control

func _ready() -> void:
	theme = W.theme()
	if not catalog.load_catalog(): W.text(self,"内容载入失败："+catalog.error,24); return
	session = Session.new(catalog)
	world_view = World.new()
	add_child(world_view)
	world_view.create(assets)
	var saved: Dictionary = {}
	if persistence:
		hand_layout.load_preferences()
		saved = store.read()
		if not store.error.is_empty(): message = store.error; save_blocked = true
		elif not saved.is_empty() and not session.restore(saved): message = session.error; save_blocked = true
		# Legacy files remain intact. Only tutorial resumes through this old store;
		# story runs are loaded explicitly from their paired slot after mode choice.
		if session.state.get("mode", "") != "tutorial": session.state = {}
	if persistence:
		meta.read_meta()
		if not meta.error.is_empty() and message.is_empty(): message = meta.error
	if persistence:
		display_settings.load_preferences()
		display_settings.apply_window(get_window())
	_init_narrative()
	if persistence:
		story_gallery.load_archive()
		if not story_gallery.error.is_empty() and message.is_empty(): message = story_gallery.error
	world_view.motion=display_settings.motion
	world_view.set_camera_mode(display_settings.camera_mode)
	world_view.camera_controls.locked=display_settings.view_locked
	world_view.camera_orbit_button=display_settings.camera_orbit_button
	world_view.camera_pan_button=display_settings.camera_pan_button
	resized.connect(update_render_resolution)
	update_render_resolution.call_deferred()
	# Starting a lesson is an explicit choice. Its first step lives in setup so the
	# player can select starting cards before a run or its save is created.
	render()
	_maybe_story.call_deferred()

func update_render_resolution() -> void:
	if is_instance_valid(world_view) and is_instance_valid(world_view.viewport):
		world_view.set_render_size(display_settings.render_size(size,get_window().size))
		_update_world_framing.call_deferred()

func _update_world_framing() -> void:
	if not is_instance_valid(layout) or not world_view.visible: return
	var frame:=layout.find_child("VoyageOperationFrame",true,false)
	var tray:=layout.find_child("VoyageHandTray",true,false)
	if frame==null or tray==null: return
	var heading:=layout.find_child("VoyageEnvironmentNames",true,false) as Control
	if heading==null: return
	var top: float=heading.global_position.y+heading.size.y-global_position.y+16.0
	var right: float=frame.global_position.x-global_position.x-18.0
	var bottom: float=tray.global_position.y-global_position.y-58.0
	var safe:=Rect2(Vector2(24,top),Vector2(maxf(200,right-24),maxf(160,bottom-top)))
	world_view.set_framing_rect(Rect2(safe.position/size,safe.size/size))

func apply_display_settings(change_mode: bool = true, rebuild_ui: bool = true) -> void:
	var focused:=get_viewport().gui_get_focus_owner()
	var restore_slider_focus: bool=is_instance_valid(focused) and focused.name=="UIScale"
	display_settings.apply_window(get_window(),change_mode)
	world_view.motion=display_settings.motion
	world_view.camera_controls.locked=display_settings.view_locked
	world_view.camera_orbit_button=display_settings.camera_orbit_button
	world_view.camera_pan_button=display_settings.camera_pan_button
	if persistence and display_settings.save_preferences()!=OK: message="显示设置保存失败"
	update_render_resolution.call_deferred()
	if not rebuild_ui:
		preload("res://presentation/settings_panel.gd").sync_controls(self)
		return
	render()
	if restore_slider_focus: _restore_scale_focus.call_deferred()

func refresh_hand_preferences() -> void:
	if local_panel=="settings" and is_instance_valid(current_page) and current_page.has_method("refresh_hand_preferences"):
		current_page.refresh_hand_preferences()
		disable_buttons(current_page)
		preload("res://presentation/settings_panel.gd").sync_controls(self)
	else: render()

func _restore_scale_focus() -> void:
	var slider:=layout.find_child("UIScale",true,false)
	if is_instance_valid(slider): slider.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if camera_binding_capture:
		if event.keycode==KEY_ESCAPE:
			camera_binding_capture=false; preload("res://presentation/settings_panel.gd").sync_controls(self)
		elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and display_settings.valid_camera_reset_key(int(event.keycode)):
			display_settings.camera_reset_key=int(event.keycode); camera_binding_capture=false; apply_display_settings(false,false)
		get_viewport().set_input_as_handled(); return
	if not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and event.keycode==display_settings.camera_reset_key:
		if is_instance_valid(world_view) and world_view.camera_input_enabled:
			world_view.reset_camera_view(); get_viewport().set_input_as_handled()

func handle_ui(action: String, value: String = "") -> void:
	if action == "recall_story":
		_open_story_review(value); return
	if action=="camera_toggle":
		display_settings.camera_mode="top" if display_settings.camera_mode=="oblique" else "oblique"
		world_view.set_camera_mode(display_settings.camera_mode)
		if persistence: display_settings.save_preferences()
		render(); return
	if action=="camera_reset":
		world_view.reset_camera_view(); return
	if action=="event_target":
		if is_instance_valid(event_target_surface): event_target_surface.hide(); event_target_surface.queue_free()
		event_target_surface=null
		if value=="" or session.phase()!="story": return
		var target: Dictionary=session.Rules.find_cell(session.state,value)
		if target.is_empty(): return
		event_target_surface=preload("res://presentation/raft_surface.gd").new()
		event_target_surface.create(world_view,[]); event_target_surface.select(target)
		return
	# Choosing a destination is interface state only: no dispatch, no save, no redraw
	# of the world or the hand.
	if action=="nav_select":
		if not select_navigation(value): render()
		return
	match action:
		"setup": setup_mode = value
		"narrative_choose": local_panel = "narrative"; setup_mode = ""
		"quit": get_tree().quit(); return
		"local_panel": local_panel = value
		"hand_page": ui_state.hand_page = maxi(0,int(value))
		"list_page": ui_state.list_page = maxi(0,int(value)); ui_state.selected_id = ""
		"selected_id": ui_state.selected_id = value
		"category": ui_state.category = value; ui_state.list_page = 0; ui_state.selected_id = ""
		"encyclopedia_tab": ui_state.encyclopedia_tab = value
		"card":
			# Viewing a hand card is presentation state only. The hand already owns
			# its hover/description visuals; rebuilding the entire HUD here caused a
			# visible 3D stall and replaced otherwise unchanged scene instances.
			ui_state.card = value
			return
		"craft_tab": ui_state.craft_tab = value
		"transmute_target": ui_state.transmute_target = value
		"transmute_uids": ui_state.transmute_uids = value
		"transmute_count": ui_state.transmute_count = maxi(1, int(value))
		"battle_selection": ui_state.battle_selection = value
		"settlement_exit":
			local_panel=""; handle_command("home"); return
		"hand_reordered":
			if persistence and hand_layout.save_preferences()!=OK: message="手牌设置保存失败"
	render()

## Interface-only destination choice. Returns false when the live panel cannot absorb
## the change and the caller has to fall back to a full render.
func select_navigation(visit_id: String) -> bool:
	if session.screen!="game" or session.phase()!="navigation": return false
	if local_panel!="" or session.panel!="": return false
	if not is_instance_valid(current_page) or not current_page.has_method("refresh_navigation"): return false
	if str(ui_state.get("nav_select",""))==visit_id: return true
	# A stale or unknown destination must not become a usable depart button.
	if not _visible_candidate(visit_id): return true
	ui_state.nav_select = visit_id
	return current_page.refresh_navigation(hud_view())

func _visible_candidate(visit_id: String) -> bool:
	for candidate in session.state.get("candidates",[]):
		if str(candidate.get("visit_id",""))==visit_id: return true
	return false

## Presentation fields shared by the full render and the partial refresh paths.
func hud_view() -> Dictionary:
	var view: Dictionary = session.view()
	view.has_story_saves = narrative_store != null and not narrative_store.list_saves().is_empty()
	view.setup_mode = setup_mode
	view.ui_state = ui_state.duplicate(true)
	view.hand_layout = hand_layout
	view.ui_scale = display_settings.ui_scale
	view.mobile = display_settings.mobile
	if view.mobile and not view.get("tutorial_hint",{}).is_empty():
		var mobile_hints := {
			"install1":"按住『滤水器』0.05秒，拖到完好空筏格松开安装（0 AP）；1级每2个后续航行轮产1张淡水，破损时暂停。",
			"discard1":"按住可弃手牌0.05秒，向上拖出手牌区松开弃置，直到容量达标；再结算食水各扣30。",
			"discard2":"按住可弃手牌0.05秒，向上拖出手牌区松开弃置至容量达标。保留贝币用于交易，滑回手牌区取消。",
			"attack2a":"按住『矛击』0.05秒，向上拖出手牌区松开：1 AP、3点伤害，用后移除。",
			"attack2b":"按住『矛击』0.05秒，向上拖出手牌区松开击败敌人；保留贝币用于交易。"
		}
		var lesson_id: String=str(view.tutorial_hint.get("id",""))
		if mobile_hints.has(lesson_id):
			view.tutorial_hint.text=mobile_hints[lesson_id]
			view.tutorial_reason=mobile_hints[lesson_id]
	view.camera_help = display_settings.camera_help()
	view.camera_mode = display_settings.camera_mode
	view.meta = meta.snapshot()
	return view

func handle_command(command: String, args: Dictionary = {}) -> void:
	if narrative_playing:
		message = "请先读完当前剧情"
		return
	# The setup page already disables locked tiers; this keeps the same rule when a
	# call comes from a keyboard shortcut or an older UI surface.
	if command == "new" and not meta.unlocked(str(args.get("difficulty","standard"))):
		message = "该难度尚未解锁：" + meta.unlock_requirement(str(args.get("difficulty","standard")))
		render(); return
	if command == "new" and args.get("mode", "") == "story":
		_start_story_run(args)
		return
	var previous_session: RefCounted = null
	if command == "new" and args.get("mode", "") == "challenge" and session.state.get("mode", "") == "story":
		previous_session = session
		var fresh := Session.new(catalog)
		fresh.profile = session.profile.duplicate(true)
		session = fresh
	reset_hand_visual = command == "new"
	var old_panel: String = session.panel
	var old_phase: String = session.phase()
	# Compared after dispatch: the partial path may only be taken when these regions
	# really stayed the same.
	var old_hand: String = JSON.stringify(session.state.get("hand",[]))
	var old_cells: String = JSON.stringify(session.state.get("cells",[]))
	if not session.dispatch(command,args):
		message = session.error
		if previous_session != null: session = previous_session
	else:
		message = ""
		local_panel = ""
		ui_state.card = ""
		ui_state.battle_selection = ""
		# Destination choice is a per-navigation decision; never carry it into a new trip.
		if command in ["new","voyage"]: ui_state.nav_select = ""
		if old_panel != session.panel:
			ui_state.list_page = 0; ui_state.selected_id = ""; ui_state.category = ""
			ui_state.craft_tab = "craft"; ui_state.transmute_target = "wood"; ui_state.transmute_uids = ""
			ui_state.transmute_count = 1
		if command == "new":
			setup_mode = ""; save_blocked = false; hand_layout.order.clear(); world_view.reset_camera_view()
			_apply_pending_narrative()
			var picked := str(args.get("difficulty",""))
			if picked != "" and picked != "tutorial":
				meta.set_last_difficulty(picked); meta.write_meta()
		if session.state.get("mode", "") == "story": save_narrative_quiet()
		_persist_profile()
		_sync_meta_progress()
		# Ordinary departure into preparation: update the regions that changed instead
		# of rebuilding the whole page. Every other transition keeps the full path.
		if command=="voyage" and old_phase=="navigation" and session.phase()=="preparation" and message.is_empty() \
			and session.state.get("mode","")!="tutorial" \
			and old_hand==JSON.stringify(session.state.get("hand",[])) and old_cells==JSON.stringify(session.state.get("cells",[])) \
			and update_after_departure():
			return
	render()
	if not narrative_playing: _maybe_story()

## Difficulty unlocks are meta progress, so they are recorded at the moment a run
## ends, independently of the single-run save.
func _sync_meta_progress() -> void:
	if session.state.is_empty(): return
	if session.phase() not in ["finished","chapterComplete"]: return
	var result: String = str(session.state.get("result",""))
	var changed := false
	if result == "survived":
		var before: Dictionary = meta.snapshot()
		var opened: Array = meta.record_clear(str(session.state.get("difficulty","standard")))
		changed = before != meta.snapshot()
		if not opened.is_empty():
			var names: Array = []
			for id in opened: names.append(str(catalog.entry("difficulties",id).get("name",id)))
			message = "通关！已解锁新难度：" + "、".join(names)
	if result == "tutorial" and not meta.tutorial_done():
		meta.record_clear("tutorial"); changed = true
		if message == "": message = "新手教程完成；返回首页开始正式航程。"
	if (changed or not meta.error.is_empty()) and not meta.write_meta(): message = meta.error

## Challenge/story persistence stores shared purchases and rewards, never a
## resumable run. Story run state belongs exclusively to its paired slot.
func _persist_profile() -> bool:
	if not persistence or save_blocked: return true
	var payload: Dictionary = session.snapshot()
	if session.state.get("mode", "") != "tutorial": payload.state = {}
	if not store.write(payload):
		message = store.error
		return false
	return true

## Refresh only the HUD regions that a normal departure changed, then let the world
## decide from its own signatures whether the raft and destination markers move.
func update_after_departure() -> bool:
	if local_panel!="" or session.panel!="": return false
	if is_instance_valid(title_backdrop): return false
	if not is_instance_valid(current_page) or not current_page.has_method("refresh_after_departure"): return false
	var view: Dictionary = hud_view()
	if not current_page.refresh_after_departure(view): return false
	world_view.sync(view)
	var interaction := find_child("RaftInteraction",true,false)
	if is_instance_valid(interaction) and interaction.has_method("refresh_policy"): interaction.refresh_policy()
	_update_world_framing.call_deferred()
	# The full path opens the next narrative beat after rendering; keep that order.
	if not narrative_playing: _maybe_story()
	return true

func _init_narrative() -> void:
	narrative_store = NarrativeStore.new()
	narrative_content = NarrativeContent.new()
	if not narrative_content.load_content():
		message = "剧情内容载入失败：" + narrative_content.error
	narrative = NarrativeSession.new(narrative_content)
	# No implicit attachment on startup. Mode selection is the only load entry.

func _apply_pending_narrative() -> void:
	if str(session.state.get("mode", "")) != "story":
		narrative.clear()
		pending_narrative = {}
		return
	var mode := str(pending_narrative.get("mode", ""))
	if mode == "": return
	if str(session.state.get("mode", "")) != "story":
		pending_narrative = {}
		return
	match mode:
		"attach": attach_narrative(str(pending_narrative.get("id", "")))
		"new": create_narrative(str(pending_narrative.get("label", "")))
		_: detach_narrative()
	pending_narrative = {}

func pick_narrative(id: String) -> void:
	load_story_run(id)

## Prepare the entire new run and slot before replacing any active memory.
func _start_story_run(args: Dictionary) -> void:
	if pending_narrative.get("mode", "") != "new":
		local_panel = "narrative"; setup_mode = ""; render(); return
	if args.get("difficulty", "") == "tutorial":
		message = "剧情模式请选择正式航程难度"; render(); return
	var candidate := Session.new(catalog)
	candidate.profile = session.profile.duplicate(true)
	if not candidate.dispatch("new", args):
		message = candidate.error; render(); return
	var story := NarrativeSession.new(narrative_content)
	story.new_save(str(pending_narrative.get("label", "")))
	var payload: Dictionary = story.export_data()
	payload.gameplay = candidate.snapshot()
	var id: String = narrative_store.create_id()
	if not narrative_store.write(id, payload):
		message = narrative_store.error; render(); return
	session = candidate; narrative = story
	pending_narrative = {}; setup_mode = ""; local_panel = ""; save_blocked = false
	message = ""; hand_layout.order.clear(); ui_state.nav_select = ""
	world_view.reset_camera_view()
	meta.set_last_difficulty(str(args.get("difficulty", "standard")))
	if persistence and not meta.write_meta(): message = meta.error
	_persist_profile()
	render(); _maybe_story()

func load_story_run(id: String) -> bool:
	var payload: Dictionary = narrative_store.read(id)
	if payload.get("chapter", "") != "chapter1" or payload.get("version", "") != narrative_content.version or not payload.get("gameplay") is Dictionary:
		message = "此剧情档不含兼容的11节点航程；原档已保留，请新建剧情档。"
		render(); return false
	var game := Session.new(catalog)
	var story := NarrativeSession.new(narrative_content)
	if not game.restore(payload.gameplay) or game.state.get("mode", "") != "story" or int(game.state.get("length", 0)) != 11:
		message = "剧情航程存档无效，已保留原文件。"; render(); return false
	if not story.load_data(payload):
		message = story.error; render(); return false
	if not story.matches_run_projection(int(game.state.voyage), game.phase()):
		message = "剧情与航程节点不一致，已保留原文件。"; render(); return false
	if not narrative_store.set_active(id):
		message = narrative_store.error; render(); return false
	# Profile is shared meta progress, not rewound by loading an older run slot.
	game.profile = session.profile.duplicate(true)
	game.screen = "game"; game.panel = game.event_panel()
	session = game; narrative = story
	setup_mode = ""; local_panel = ""; pending_narrative = {}; message = ""
	hand_layout.order.clear(); ui_state.nav_select = ""; world_view.reset_camera_view()
	render(); _maybe_story()
	return true

func pick_new_narrative(label: String) -> void:
	pending_narrative = {"mode":"new", "label":label}
	local_panel = ""
	handle_ui("setup", "story")

func pick_no_narrative() -> void:
	message = "剧情模式必须选择新建或读取剧情档。"
	local_panel = "narrative"; setup_mode = ""; render()

func attach_narrative(id: String) -> bool:
	if id == "" or narrative == null: return false
	var data: Dictionary = narrative_store.read(id)
	if data.is_empty():
		message = "剧情存档不存在"
		return false
	var candidate := NarrativeSession.new(narrative_content)
	if not candidate.load_data(data):
		message = candidate.error
		return false
	if not narrative_store.set_active(id):
		message = narrative_store.error
		return false
	narrative = candidate
	return true

func create_narrative(label: String) -> bool:
	if narrative == null: return false
	var candidate := NarrativeSession.new(narrative_content)
	candidate.new_save(label)
	var id: String = narrative_store.create_id()
	if not narrative_store.write(id, candidate.export_data()):
		message = narrative_store.error
		return false
	narrative = candidate
	return true

func detach_narrative() -> void:
	if narrative == null: return
	if not narrative_store.set_active(""):
		message = narrative_store.error
		return
	narrative.clear()

func switch_narrative(id: String) -> void:
	if attach_narrative(id):
		message = "已挂载剧情档：" + narrative.label()
		render()

func save_narrative() -> void:
	if narrative == null or not narrative.has_save(): return
	save_narrative_quiet()
	message = "剧情进度已保存" if narrative_store.error.is_empty() else narrative_store.error
	render()

func save_narrative_quiet() -> bool:
	if narrative == null or not narrative.has_save(): return true
	var id: String = narrative_store.active_id()
	if id == "": id = narrative_store.create_id()
	var payload: Dictionary = narrative.export_data()
	if session != null and session.state.get("mode", "") == "story": payload.gameplay = session.snapshot()
	if not narrative_store.write(id, payload):
		message = narrative_store.error
		return false
	return true

func narrative_status() -> String:
	if narrative == null or not narrative.has_save(): return "本局未挂载剧情档"
	return "%s · 第 %d/%d 段" % [narrative.label(), narrative.applied_count(), narrative_content.beats.size()]

## Opens the next due beat. Only stable phases qualify (see narrative_schedule).
func _maybe_story() -> void:
	if narrative_playing or narrative == null or session == null: return
	if session.state.is_empty() or session.screen != "game": return
	# Narrative beats belong to story runs; challenge and tutorial are self-contained.
	if session.state.get("mode","") != "story": return
	if not narrative.has_save(): return
	var beat: Dictionary = narrative.next_beat(int(session.state.get("voyage", 1)), session.phase())
	if beat.is_empty(): return
	var scene: Dictionary = narrative.begin(str(beat.id))
	if scene.is_empty(): return
	_open_narrative(narrative.prepare_scene())

func _open_narrative(scene: Dictionary) -> void:
	narrative_playing = true
	if is_instance_valid(current_page): disable_buttons(current_page)
	narrative_overlay = preload("res://pages/story_page.gd").new()
	narrative_overlay.name = "NarrativeOverlay"
	narrative_overlay.z_index = 400
	add_child(narrative_overlay)
	narrative_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	narrative_overlay.story_completed.connect(_on_narrative_completed)
	var response: Dictionary = narrative_overlay.load_story(scene)
	if not response.get("ok", false):
		message = "剧情载入失败：" + str(response.get("error", ""))
		_close_narrative()

func _on_narrative_completed(result: Dictionary) -> void:
	var changes: Dictionary = narrative.finish(result)
	if not narrative.error.is_empty():
		message = narrative.error
		return
	if changes.has("ending"):
		# A narrative bad ending closes this story run through existing settlement.
		session.finish("story_bad_end")
		session.state.result_text = "剧情结局：" + str(changes.ending)
		session.state.settlement = session.Settlement.create(session.state, catalog, "run")
		session.last_settlement = session.state.settlement.duplicate(true)
	var saved := save_narrative_quiet()
	if not _persist_profile(): saved = false
	_close_narrative()
	var parts: Array = []
	for id in changes.get("affinity", {}):
		if narrative_content.character(id).is_empty(): continue
		var delta := int(changes.affinity[id])
		parts.append("%s %s%d" % [narrative_content.character(id).name, "+" if delta > 0 else "", delta])
	if saved and not parts.is_empty(): message = "好感度：" + "、".join(parts)
	if saved and changes.has("ending"): message = "剧情结局：" + str(changes.ending)
	render()
	_maybe_story()

func _close_narrative() -> void:
	narrative_playing = false
	if is_instance_valid(narrative_overlay):
		remove_child(narrative_overlay)
		narrative_overlay.queue_free()
	narrative_overlay = null

func _open_story_review(id: String) -> void:
	if local_panel != "recall" or is_instance_valid(story_replay): return
	var record: Dictionary = story_gallery.entry(id)
	if record.is_empty(): return
	var replay = preload("res://presentation/opening_intro.gd").new()
	replay.name = "StoryReplay"; replay.z_index = 300
	replay.persist_completion = false
	replay.exit_label = "返回回廊"
	if id != "opening":
		var scenes: Array = []
		var cover: Texture2D = preload("res://pages/story_gallery.gd").cover(record, assets)
		for line in record.lines + record.results:
			scenes.append({"texture":cover,"narration":[line]})
		if scenes.is_empty(): replay.free(); return
		replay.playback_data = {"scenes":scenes,"music":"res://assets/opening-intro/music.ogg"}
	var origin := get_viewport().gui_get_focus_owner()
	story_replay = replay
	add_child(replay)
	var title := W.text(replay.canvas, record.title + (" · 特殊剧情" if record.special else ""), 24, W.GOLD)
	title.position = Vector2(500, 52); title.size = Vector2(600, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay.finished.connect(func():
		remove_child(replay); replay.queue_free(); story_replay = null
		if is_instance_valid(origin): origin.grab_focus())

func page(id: String, parent: Node, view: Dictionary) -> Control:
	var result: Control = PAGES[id].new()
	parent.add_child(result)
	result.action_requested.connect(handle_ui)
	result.command_requested.connect(handle_command)
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if parent is Control and not parent is Container: result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if result.has_method("configure_session"): result.configure_session(session)
	result.setup(view,catalog,assets)
	return result

func render() -> void:
	camera_binding_capture=false
	world_view.set_camera_input_enabled(false)
	if is_instance_valid(event_target_surface): event_target_surface.hide(); event_target_surface.queue_free()
	var hand_visual := {}
	if is_instance_valid(layout) and not reset_hand_visual:
		for fan in get_tree().get_nodes_in_group("hand_fans"):
			if layout.is_ancestor_of(fan): hand_visual[fan.get_meta("presentation_role","hand")] = fan.capture_visual()
	reset_hand_visual = false
	if is_instance_valid(layout): remove_child(layout); layout.queue_free()
	var view: Dictionary = hud_view()
	if view.has("hand"):
		var arranged: Array=hand_layout.build(view.hand)
		hand_layout.order.clear()
		for group in arranged: hand_layout.order.append_array(group.stack_uids)
	var report: Dictionary = view.get("settlement",{}) if view.screen=="game" and view.phase in ["finished","chapterComplete"] else {}
	world_view.visible=report.is_empty()
	if not report.is_empty():
		if is_instance_valid(title_backdrop): title_backdrop.hide()
		var settlement_host := Control.new(); settlement_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(settlement_host); layout=settlement_host
		var background := ColorRect.new(); background.color=Color("081b25"); background.mouse_filter=Control.MOUSE_FILTER_IGNORE
		settlement_host.add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var settlement_page := SettlementPage.new(); settlement_host.add_child(settlement_page)
		settlement_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		settlement_page.action_requested.connect(handle_ui); settlement_page.command_requested.connect(handle_command)
		view.settlement=report; settlement_page.setup(view,catalog,assets); current_page=settlement_page
		if not message.is_empty():
			var note := W.text(settlement_host,message,17,Color("efb395"))
			note.position=Vector2(24,8); note.size=Vector2(900,44)
			note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		return
	world_view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	world_view.sync(view)
	# Keep the decoder outside the rebuilt page layout during home interactions.
	if view.screen == "home":
		if not is_instance_valid(title_backdrop):
			title_backdrop = preload("res://presentation/title_menu.gd").new()
			title_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(title_backdrop)
			title_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			title_backdrop.create_background()
		title_backdrop.visible = setup_mode == ""
	elif is_instance_valid(title_backdrop):
		remove_child(title_backdrop)
		title_backdrop.queue_free()
		title_backdrop = null
	var host := Control.new(); host.mouse_filter=Control.MOUSE_FILTER_IGNORE; host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host); layout = host
	# Embedded event surface sits above the world, below all persistent HUD controls.
	if view.screen=="game" and view.phase=="story":
		var event_surface:=ColorRect.new(); event_surface.name="NodeEventSurface"
		event_surface.color=Color(0.025,0.055,0.08,0.78); host.add_child(event_surface)
		event_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# z 1: above the 3D view and its covered utilities (z 0), below the persistent HUD (z 2).
		event_surface.z_index=1
		# Three columns (illustration | prose | options) share one inset so they stay aligned.
		var event_body:=Control.new(); event_body.name="NodeEventBodyHost"; event_surface.add_child(event_body)
		event_body.anchor_left=0.0; event_body.anchor_top=0.0; event_body.anchor_right=1.0; event_body.anchor_bottom=1.0
		# Tutorial guidance overlays the heading; event columns retain their full height.
		var story_top: float = 124.0
		event_body.offset_left=56; event_body.offset_top=story_top; event_body.offset_right=-56; event_body.offset_bottom=-328
		page("story",event_body,view)
	current_page = page("setup" if view.screen == "home" and setup_mode != "" else view.screen,host,view)
	var panel_id: String = local_panel if local_panel != "" else view.panel
	if view.screen=="game" and view.phase in ["story","battle"] and panel_id in ["story","battle"]: panel_id=""
	if panel_id != "":
		disable_buttons(current_page)
		var shade := ColorRect.new(); shade.z_index = 200; shade.color = Color(0.01,0.02,0.03,0.85)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); host.add_child(shade)
		var inset := MarginContainer.new(); inset.z_index = 201; inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.anchor_left = 0.12; inset.anchor_right = 0.88; inset.anchor_top = 0.10; inset.anchor_bottom = 0.77
		if panel_id in ["battle","raft"]:
			inset.anchor_left=0.035; inset.anchor_right=0.965; inset.anchor_top=0.035; inset.anchor_bottom=0.965
		if panel_id in ["craft","shop","build","encyclopedia","meta_shop"]:
			inset.anchor_left=0; inset.anchor_right=1; inset.anchor_top=0; inset.anchor_bottom=1
		if panel_id == "recall":
			inset.anchor_left=0.035; inset.anchor_right=0.965; inset.anchor_top=0.035; inset.anchor_bottom=0.965
		if panel_id=="settings":
			inset.anchor_left=0.5; inset.anchor_right=0.5; inset.anchor_top=0.04; inset.anchor_bottom=0.96
			var panel_width:=minf(700.0,size.x-40.0)
			inset.offset_left=-panel_width*0.5; inset.offset_right=panel_width*0.5
		host.add_child(inset)
		var dialog := W.panel(inset)
		var surface: PanelContainer=dialog.get_parent(); surface.name="ModalSurface"
		if panel_id == "recall":
			var gallery_style: StyleBoxFlat = surface.get_theme_stylebox("panel").duplicate()
			gallery_style.bg_color = Color("0b1b24")
			surface.add_theme_stylebox_override("panel", gallery_style)
		if panel_id=="settings": W.text(dialog,"设置",28,W.GOLD)
		if not message.is_empty(): W.text(dialog,message,17,Color("ecb49a"))
		if panel_id in ["help","settings","narrative","recall"]: local_content(dialog,panel_id,view)
		else: current_page = page(panel_id,dialog,view)
		W.corner_close(surface,func():
			if local_panel != "": local_panel = ""; render()
			else: handle_command("close"))
		if panel_id in ["craft", "build"]:
			var help := Button.new()
			help.name = "CraftHelpButton"; help.text = "?"
			help.accessibility_name = "工作台说明"; help.tooltip_text = "工作台说明"
			surface.get_node("CloseOverlay").add_child(help)
			help.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			help.offset_left = -104; help.offset_right = -60
			help.offset_top = 0; help.offset_bottom = 44
			help.custom_minimum_size = Vector2(44, 44)
			help.add_theme_font_size_override("font_size", 26)
			for state in ["normal", "hover", "pressed", "focus"]:
				var style := StyleBoxFlat.new()
				style.bg_color = Color("203d49") if state in ["hover", "pressed"] else Color("0c1d26")
				style.border_color = W.GOLD if state in ["hover", "focus"] else Color("8b9a9e")
				style.set_border_width_all(2); style.set_corner_radius_all(22)
				help.add_theme_stylebox_override(state, style)
			help.pressed.connect(current_page.show_workbench_help)

	elif not message.is_empty():
		var label := W.text(host,message,18,Color("efb395"))
		label.position = Vector2(28,200); label.size = Vector2(580,60)

	for fan in get_tree().get_nodes_in_group("hand_fans"):
		if layout.is_ancestor_of(fan):
			fan.restore_visual(hand_visual.get(fan.get_meta("presentation_role","hand"),{}))

	if view.screen=="game" and view.get("can_base",false) and panel_id=="":
		var interaction=preload("res://presentation/raft_interaction.gd").new()
		host.add_child(interaction); interaction.create(self)
	world_view.set_camera_input_enabled(view.screen=="game" and panel_id=="" and report.is_empty())
	if panel_id not in ["settings","help","narrative"]:
		_add_tutorial_banner(host,view,panel_id!="")
	_update_world_framing.call_deferred()

## Persistent lesson strip. It never takes mouse input, so it guides without
## blocking the real interface the player is learning. It covers unrelated title
## regions rather than reserving vertical space in events or modal contents.
func _add_tutorial_banner(host: Control, view: Dictionary, modal: bool = false) -> void:
	if view.get("mode","") != "tutorial": return
	if view.get("screen","") != "game": return
	var lesson: Dictionary = view.get("tutorial_hint",{})
	if lesson.is_empty(): return
	var outer := PanelContainer.new()
	outer.name = "TutorialBanner"
	outer.z_index = 260
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.anchor_left = 0.5; outer.anchor_right = 0.5; outer.anchor_top = 0; outer.anchor_bottom = 0
	var hint_width: float=minf(840.0,size.x-112.0)
	outer.offset_left = -hint_width*0.5; outer.offset_right = hint_width*0.5
	if modal:
		# The header gap between left-hand tabs and right-hand help/close controls.
		outer.anchor_left=0; outer.anchor_right=1
		outer.offset_left=500; outer.offset_right=-144
		outer.offset_top=4; outer.offset_bottom=76
	else:
		# Cover the unrelated voyage heading; preserve all current node/battle space.
		var heading_width: float=minf(600.0,maxf(280.0,(size.x-200.0)*.42-24.0))
		outer.anchor_left=0; outer.anchor_right=0
		outer.offset_left=24; outer.offset_right=24+heading_width
		outer.offset_top=8; outer.offset_bottom=96
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03,0.07,0.09,0.94)
	style.border_color = W.GOLD; style.set_border_width_all(1); style.set_corner_radius_all(3)
	style.content_margin_left = 16; style.content_margin_right = 16
	style.content_margin_top = 8; style.content_margin_bottom = 8
	outer.add_theme_stylebox_override("panel",style)
	host.add_child(outer)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation",3)
	outer.add_child(box)
	var head := W.text(box,"新手教程 · %d/%d · %s" % [int(lesson.get("index",1)),int(lesson.get("total",1)),str(lesson.get("title",""))],18,W.GOLD)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_text: String=str(lesson.get("text",""))
	if modal and lesson.get("id","")=="craft1":
		hint_text="选择『制造滤水器』：消耗塑料2、木头1和1 AP。"
	var body := W.text(box,hint_text,16,W.INK)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var detail := str(lesson.get("detail",""))
	if detail != "":
		var note := W.text(box,detail,15,W.MUTED)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE

func local_content(parent: Node, id: String, view: Dictionary) -> void:
	if id == "recall":
		var gallery = preload("res://pages/story_gallery.gd").new()
		parent.add_child(gallery)
		gallery.replay_requested.connect(func(story_id: String): handle_ui("recall_story", story_id))
		gallery.setup(story_gallery.entries(), assets)
	elif id == "narrative":
		NarrativeMenu.build_choice(parent, self)
	elif id == "help":
		W.text(parent,"航行须知",32,W.GOLD)
		for line in ["出发支付SAN航耗，抵达后进入准备；轮末弃牌完成、容量达标后才结算食水。","准备与收尾共享基地AP；制造消耗AP，设备安装不消耗AP。","事件先读文字，再作选择；战斗和商店结束后返回节点结果。","轮末处理筏格老化与超限整理；下一轮开始时完好设备推进生产，周期达标才产出。","事件自动显示在航行画面，完成当前事件后才能再次导航。"]: W.text(parent,line,20)
	else:
		preload("res://presentation/settings_panel.gd").build(parent,self,view)

func disable_buttons(node: Node) -> void:
	if node is BaseButton: node.disabled = true
	for child in node.get_children(): disable_buttons(child)

func confirm_abandon() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "放弃当前航程并按已完成节点结算？"
	dialog.title = "放弃航程"
	add_child(dialog)
	for button in [dialog.get_ok_button(), dialog.get_cancel_button()]:
		W.TextButtonArt.apply(button)
	dialog.confirmed.connect(func(): handle_command("abandon"); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()
