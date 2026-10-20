extends Control
const Session = preload("res://core/game_session.gd")
const Catalog = preload("res://content/catalog.gd")
const Assets = preload("res://presentation/asset_catalog.gd")
const Store = preload("res://adapters/save_store.gd")
const Meta = preload("res://adapters/meta_store.gd")
const Tutorial = preload("res://core/tutorial_rules.gd")
const W = preload("res://presentation/widgets.gd")
const BasePage = preload("res://pages/base_page.gd")
const World = preload("res://presentation/voyage_world.gd")
const SettlementPage = preload("res://pages/settlement_page.gd")
const NarrativeContent = preload("res://narrative/narrative_content.gd")
const NarrativeSession = preload("res://narrative/narrative_session.gd")
const NarrativeStore = preload("res://adapters/narrative_store.gd")
const NarrativeMenu = preload("res://pages/narrative_menu.gd")
const PAGES = preload("res://application/page_host.gd").PAGES
var narrative_coordinator = preload("res://application/narrative_coordinator.gd").new()
var persistence_coordinator = preload("res://application/persistence_coordinator.gd").new()
var page_host = preload("res://application/page_host.gd").new()
var catalog := Catalog.new()
var assets := Assets.new()
var store := Store.new()
var meta := Meta.new()
var session: RefCounted:
	set(value):
		session=value
		if session!=null: session.auto_end_voyage=display_settings.auto_end_voyage
var current_page: Control:
	get: return page_host.current_page
	set(value): page_host.current_page = value
var layout: Control:
	get: return page_host.layout
	set(value): page_host.layout = value
var title_backdrop: Control:
	get: return page_host.title_backdrop
	set(value): page_host.title_backdrop = value
var setup_mode := ""
var message := ""
var save_blocked := false
var persistence := true
## Temporary presentation switch; story content and paired saves remain intact.
@export var story_mode_visible := false
var display_settings = preload("res://presentation/display_settings.gd").new()
var music = preload("res://presentation/music_director.gd").new()
var ambience = preload("res://presentation/ambience_director.gd").new()
var settings_tab := "display"
var camera_binding_capture := false
var hand_layout = preload("res://presentation/hand_layout.gd").new()
var world_view: TextureRect
var local_panel := ""
var reset_hand_visual := false
var ui_state := {"hand_page":0,"list_page":0,"selected_id":"","category":"","card":"","battle_selection":"","craft_tab":"craft","transmute_target":"wood","transmute_uids":"","transmute_count":1}
var _base_page: Control:
	get: return page_host._base_page
	set(value): page_host._base_page = value
var _modal_root: Control:
	get: return page_host._modal_root
	set(value): page_host._modal_root = value
var _modal_id: String:
	get: return page_host._modal_id
	set(value): page_host._modal_id = value
var _base_signature: String:
	get: return page_host._base_signature
	set(value): page_host._base_signature = value
var _blocked_buttons: Dictionary:
	get: return page_host._blocked_buttons
	set(value): page_host._blocked_buttons = value
var _blocked_modes: Dictionary:
	get: return page_host._blocked_modes
	set(value): page_host._blocked_modes = value
var _blocked_visuals: Dictionary:
	get: return page_host._blocked_visuals
	set(value): page_host._blocked_visuals = value
var _context_pages: Array[WeakRef]:
	get: return page_host._context_pages
	set(value): page_host._context_pages = value
var _blocked_revision: int:
	get: return page_host._blocked_revision
	set(value): page_host._blocked_revision = value
var event_target_surface: Node3D
## Narrative is an independent layer: it reads a projection, never GameState.
var narrative_content: RefCounted:
	get: return narrative_coordinator.narrative_content
	set(value): narrative_coordinator.narrative_content = value
var narrative_store: RefCounted:
	get: return narrative_coordinator.narrative_store
	set(value): narrative_coordinator.narrative_store = value
var narrative: RefCounted:
	get: return narrative_coordinator.narrative
	set(value): narrative_coordinator.narrative = value
var narrative_overlay: Control:
	get: return narrative_coordinator.narrative_overlay
	set(value): narrative_coordinator.narrative_overlay = value
var narrative_playing: bool:
	get: return narrative_coordinator.narrative_playing
	set(value): narrative_coordinator.narrative_playing = value
var pending_narrative: Dictionary:
	get: return narrative_coordinator.pending_narrative
	set(value): narrative_coordinator.pending_narrative = value
var transition_busy:=false
var _defer_transition_render:=false
var _transition_command_running:=false
var loading_transition: Control
var acquisition_overlay: Control
var _ui_command_pending:=false
var _receipt_cursor: Dictionary={}
var _pending_receipt: Dictionary={"uids":[],"coins":0}
# Temporary legacy gallery: read archived records; new narrative replay is separate.
var story_gallery = preload("res://adapters/story_gallery_store.gd").new()
var story_replay: Control:
	get: return narrative_coordinator.story_replay
	set(value): narrative_coordinator.story_replay = value

func _ready() -> void:
	set_meta("mobile_ui",display_settings.mobile)
	add_child(music)
	add_child(ambience)
	get_tree().node_added.connect(_queue_mobile_control_policy)
	get_tree().auto_accept_quit = false
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
		# Challenge/tutorial checkpoints include the shared profile atomically.
		# Story runs are loaded explicitly from their paired slot after mode choice.
		if session.state.get("mode", "") not in ["tutorial","challenge"]: session.state = {}
	if persistence:
		meta.read_meta()
		if not meta.error.is_empty() and message.is_empty(): message = meta.error
		# A saved terminal checkpoint can repair a failed, idempotent meta write.
		if not save_blocked: _sync_meta_progress()
	if persistence:
		display_settings.load_preferences()
		display_settings.apply_window(get_window())
	music.apply_preferences(display_settings.music_volume, display_settings.music_enabled)
	ambience.apply_preferences(display_settings.music_volume, display_settings.music_enabled)
	session.auto_end_voyage=display_settings.auto_end_voyage
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
	_warm_craft_art.call_deferred()

func _warm_craft_art() -> void:
	if DisplayServer.get_name()=="headless": return
	var ids: Array=[]
	for id in catalog.table("recipes").keys().slice(0,PAGES.craft.PAGE_SIZE):
		ids.append("card."+str(catalog.entry("recipes",id).output))
	await assets.warm_textures(ids,self)

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
	session.auto_end_voyage=display_settings.auto_end_voyage
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

## Music is local presentation state: volume and mute persist with display
## preferences and never enter the run save.
func apply_audio_settings() -> void:
	music.apply_preferences(display_settings.music_volume, display_settings.music_enabled)
	ambience.apply_preferences(display_settings.music_volume, display_settings.music_enabled)
	if persistence and display_settings.save_preferences()!=OK: message="音频设置保存失败"
	preload("res://presentation/settings_panel.gd").sync_controls(self)

func refresh_hand_preferences() -> void:
	if local_panel=="settings" and is_instance_valid(current_page) and current_page.has_method("refresh_hand_preferences"):
		current_page.refresh_hand_preferences()
		if is_instance_valid(_modal_root): _block_base_controls()
		else: disable_buttons(current_page)
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
	if transition_busy or is_instance_valid(acquisition_overlay): return
	if not story_mode_visible and (action == "narrative_choose" or (action in ["setup", "local_panel"] and value in ["story", "narrative"])): return
	if action=="close_settings":
		if local_panel=="settings": local_panel=""; render()
		return
	if action=="transmute_scroll":
		ui_state.transmute_scroll=maxi(0,int(value)); return
	if action == "retry_save":
		persistence_coordinator.retry(self); render(); _maybe_story(); return
	if action == "cancel_quit":
		local_panel = ""; render(); return
	if action == "quit_without_save":
		get_tree().quit(); return
	if action == "cancel_replacement":
		persistence_coordinator.pending_replacement = {}; local_panel = ""; render(); return
	if action == "confirm_replacement":
		var pending: Dictionary = persistence_coordinator.pending_replacement
		persistence_coordinator.pending_replacement = {}; local_panel = ""
		if pending.is_empty() or pending.revision != session.revision:
			message = "操作已过期，请重新选择航程。"; render(); return
		var submitted: Dictionary = pending.args.duplicate(true)
		submitted.replace_current = true
		request_command(str(pending.command),submitted); return
	if action == "recall_story":
		_open_story_review(value); return
	if action=="camera_toggle":
		display_settings.camera_mode="top" if display_settings.camera_mode=="oblique" else "oblique"
		world_view.set_camera_mode(display_settings.camera_mode)
		if persistence: display_settings.save_preferences()
		if is_instance_valid(current_page) and current_page.has_method("refresh_camera_mode") and _base_signature==_retained_hud_signature():
			current_page.refresh_camera_mode(display_settings.camera_mode)
		else: render()
		return
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
	if action=="setup" and _refresh_home_setup(value): return
	match action:
		"tutorial_choice":
			meta.data.tutorial_prompt_handled = true
			if persistence and not meta.write_meta(): message = meta.error
			if value == "enter": setup_mode = "tutorial"
			elif value == "skip_modes":
				render()
				current_page.select_mode(current_page.get_child(0))
				return
		"setup": setup_mode = value
		"narrative_choose": local_panel = "narrative"; setup_mode = ""
		"quit":
			_request_quit(); return
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
		"battle_selection":
			ui_state.battle_selection = value
			# The battle view already updates its selected cards, preview and confirm
			# button. Persist its UI state without destroying the source controls.
			if session.phase()=="battle" and is_instance_valid(current_page) and current_page.has_method("refresh_battle_selection") and _base_signature==_retained_hud_signature():
				current_page.refresh_battle_selection(value)
				return
		"settlement_exit":
			local_panel=""; request_command("home"); return
		"hand_reordered":
			# The source fan already moved its existing controls. Retain the HUD and
			# world interaction; only a failed preference write needs the error UI.
			if persistence and hand_layout.save_preferences()!=OK:
				message="手牌设置保存失败"
				render()
			return
	if action == "craft_tab" and (session.panel in ["craft", "build"] or local_panel in ["craft", "build"]) \
		and is_instance_valid(current_page) and current_page.has_method("refresh_craft_tab"):
		if current_page.refresh_craft_tab(hud_view()): return
	if action in ["transmute_target", "transmute_uids"] and (session.panel in ["craft", "build"] or local_panel in ["craft", "build"]) \
		and is_instance_valid(current_page) and current_page.has_method("refresh_transmute_ui"):
		if current_page.refresh_transmute_ui(hud_view(), action): return
	render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and local_panel=="settings":
		handle_ui("close_settings"); return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if session == null: get_tree().quit()
		else: _request_quit()

func _request_quit() -> void:
	if persistence_coordinator.save_pending and not persistence_coordinator.retry(self):
		local_panel = "quit_unsaved"
		render(); return
	get_tree().quit()

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

## Preparation replaces only the home content, preserving the backdrop/host.
func _refresh_home_setup(mode: String) -> bool:
	if mode not in ["challenge","story"] or session.screen!="home" or session.panel!="": return false
	if not is_instance_valid(current_page) or _base_signature!=_retained_hud_signature(): return false
	_remove_modal_layer()
	if setup_mode==mode and current_page.get_script()==PAGES.setup: return true
	var view: Dictionary=current_page.context.duplicate(true)
	view.setup_mode=mode; view.revision=session.revision
	view.ui_state=ui_state.duplicate(true); view.meta=meta.snapshot()
	view["loading_transition"]=false
	var host:=current_page.get_parent()
	host.remove_child(current_page); current_page.queue_free()
	setup_mode=mode
	if is_instance_valid(title_backdrop): title_backdrop.hide()
	current_page=page("setup",host,view); _base_page=current_page
	return true

func _visible_candidate(visit_id: String) -> bool:
	for candidate in session.state.get("candidates",[]):
		if str(candidate.get("visit_id",""))==visit_id: return true
	return false

## Presentation fields shared by the full render and the partial refresh paths.
func hud_view() -> Dictionary:
	var view: Dictionary = session.view()
	view.can_resume = session.active()
	view.story_mode_visible = story_mode_visible
	view.save_pending = persistence_coordinator.save_pending
	preload("res://application/acquisition_projection.gd").apply_pending(view,_pending_receipt)
	view.has_story_saves = narrative_store != null and narrative_store.has_saves()
	view.setup_mode = setup_mode
	view.ui_state = ui_state.duplicate(true)
	view.hand_layout = hand_layout
	view.ui_scale = display_settings.ui_scale
	view.mobile = display_settings.mobile
	if view.mobile and not view.get("tutorial_hint",{}).is_empty():
		var mobile_hints := {
			"install1":"按住『滤水器』0.05秒，拖到完好空筏格松开安装（0 AP）；1级每2个后续航行轮产1张淡水，破损时暂停。",
			"discard1":"按住可弃手牌0.05秒，向上拖出手牌区松开弃置，直到容量达标；再结算食水各扣30。",
			"discard2":"按住其他可弃手牌0.05秒，向上拖出手牌区弃置至容量达标。保留贝币用于购买、尸体用于出售教学；滑回取消。",
			"enchant_attack2":"资源牌可附魔操作牌，暂仅支持战斗攻击和防御。轻点『废铁』，再按住『攻击』0.05秒向上拖出松开：消耗废铁1与1战斗AP，伤害1→2；选择和预览不消耗。",
			"enchant_block2":"轻点『木头』，再按住『防御』0.05秒向上拖出松开，打出防御附魔：消耗木头1与1战斗AP，护盾1→3；打出前可查看预览。",
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

## UI-originated page transitions keep the original work, under an animated layer.
## Direct command callers remain synchronous for rules/tests/agent integrations.
func request_command(command: String, args: Dictionary = {}) -> void:
	if transition_busy or _ui_command_pending: return
	if persistence_coordinator.blocks(self,command): render(); return
	_ui_command_pending=true
	var cursor: Dictionary=preload("res://application/acquisition_projection.gd").capture(session)
	_receipt_cursor=cursor if command not in ["new","load_story","home"] else {}
	await _request_command_with_transition(command,args)
	# Loading an existing run must never replay its old rewards.
	if command not in ["new","load_story","home"]:
		var batches: Array=preload("res://application/acquisition_projection.gd").batches(session,cursor)
		await preload("res://application/acquisition_presenter.gd").new().present(self,batches)
	_receipt_cursor={}; _pending_receipt={"uids":[],"coins":0}
	_ui_command_pending=false
	_maybe_story()

func _request_command_with_transition(command: String, args: Dictionary = {}) -> void:
	if transition_busy: return
	var next_voyage := 0
	if not narrative_playing and not session.state.is_empty() and command!="new" and (command in Session.Stats.GAME_COMMANDS or command=="resume"):
		var preview = preload("res://core/action_query.gd").fork(session)
		# Predict the complete dispatch, including automatic settlement, on a copy.
		preview._auto_advancing=false; preview._effect_preview=false
		preview.auto_end_voyage=display_settings.auto_end_voyage
		if preview.dispatch(command,args) and preview.phase()=="navigation" and int(preview.state.voyage)>int(session.state.voyage):
			next_voyage=int(preview.state.voyage)
	if (command not in ["new","home","resume","load_story"] and next_voyage==0) or narrative_playing:
		handle_command(command,args)
		return
	transition_busy=true
	var submitted:=args.duplicate(true)
	var old_layout: Control=layout
	var old_mode: int=old_layout.process_mode if is_instance_valid(old_layout) else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(old_layout): old_layout.process_mode=Node.PROCESS_MODE_DISABLED
	world_view.set_camera_input_enabled(false)
	loading_transition=preload("res://presentation/voyage_transition.gd").new() if next_voyage>0 else preload("res://presentation/loading_transition.gd").new()
	add_child(loading_transition)
	loading_transition.modulate.a=0
	loading_transition.set_stage("第 %d 轮航行 · 潮起再出发" % next_voyage if next_voyage>0 else ("正在返回港湾" if command=="home" else "正在准备航程"))
	await loading_transition.fade(1.0)
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	_defer_transition_render=true; _transition_command_running=true
	if command=="load_story": load_story_run(str(submitted.get("id","")),bool(submitted.get("replace_current",false)))
	else: handle_command(command,submitted)
	_transition_command_running=false; _defer_transition_render=false
	if next_voyage==0: loading_transition.set_stage("正在展开海图" if session.screen=="game" else "正在点亮灯塔")
	await render(true)
	if is_instance_valid(old_layout): old_layout.process_mode=old_mode
	move_child(loading_transition,get_child_count()-1)
	var new_mode: int=layout.process_mode
	layout.process_mode=Node.PROCESS_MODE_DISABLED
	world_view.set_camera_input_enabled(false)
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	else: await get_tree().process_frame
	if next_voyage>0: await get_tree().create_timer(.65).timeout
	else: loading_transition.set_stage("正在显示提示" if not message.is_empty() else "潮路已就绪")
	await loading_transition.fade(0.0)
	layout.process_mode=new_mode
	remove_child(loading_transition); loading_transition.queue_free(); loading_transition=null
	transition_busy=false
	world_view.set_camera_input_enabled(session.screen=="game" and world_view.visible and local_panel=="" and session.panel in ["","story","battle"] and not narrative_playing)
	_maybe_story()

func handle_command(command: String, args: Dictionary = {}) -> void:
	if transition_busy and not _transition_command_running: return
	if persistence_coordinator.blocks(self,command): render(); return
	if narrative_playing:
		message = "请先读完当前剧情"
		return
	# The setup page already disables locked tiers; this keeps the same rule when a
	# call comes from a keyboard shortcut or an older UI surface.
	if command == "new" and not meta.unlocked(str(args.get("difficulty","standard"))):
		message = "该难度尚未解锁：" + meta.unlock_requirement(str(args.get("difficulty","standard")))
		render(); return
	if command == "new" and args.get("mode", "") == "story":
		if not persistence_coordinator.confirm_replacement(self,command,args): return
		_start_story_run(args)
		return
	reset_hand_visual = command == "new"
	var old_panel: String = session.panel
	var old_phase: String = session.phase()
	# Compared after dispatch: the partial path may only be taken when these regions
	# really stayed the same.
	var old_hand: String = JSON.stringify(session.state.get("hand",[]))
	var old_cells: String = JSON.stringify(session.state.get("cells",[]))
	var succeeded := false
	if command == "new" and args.get("mode", "") == "challenge":
		var prepared: Dictionary = preload("res://application/session_coordinator.gd").prepare_challenge(session,narrative_content,args)
		if prepared.ok:
			if not persistence_coordinator.confirm_replacement(self,command,args): return
			if not persistence_coordinator.write_candidate(self,prepared.session): render(); return
			session = prepared.session
			narrative = prepared.narrative
			succeeded = true
		else:
			message = prepared.error
			render()
			return
	else:
		succeeded = session.dispatch(command,args)
	if not succeeded:
		message = session.error
	else:
		if not persistence_coordinator.save_pending: message = ""
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
				meta.set_last_difficulty(picked)
				if persistence: meta.write_meta()
		if not persistence_coordinator.save_pending:
			if session.state.get("mode", "") == "story": save_narrative_quiet()
			# A new challenge was already committed before replacing its session pair.
			if command == "new" or _persist_profile(): _sync_meta_progress()
		if _ui_command_pending and not _receipt_cursor.is_empty():
			var receipts: Array=preload("res://application/acquisition_projection.gd").batches(session,_receipt_cursor)
			_pending_receipt=preload("res://application/acquisition_projection.gd").pending(receipts)
		# Ordinary departure into preparation: update the regions that changed instead
		# of rebuilding the whole page. Every other transition keeps the full path.
		if command=="voyage" and old_phase=="navigation" and session.phase()=="preparation" and message.is_empty() \
			and session.state.get("mode","")!="tutorial" \
			and old_hand==JSON.stringify(session.state.get("hand",[])) and old_cells==JSON.stringify(session.state.get("cells",[])) \
			and update_after_departure():
			return
		# Continuing combat actions retain the battle HUD when the same enemy,
		# hand and raft-cell structures remain active. Terminal/structural changes
		# deliberately fall through to the existing complete render.
		if command in ["battle_action"] and old_phase=="battle" and session.phase()=="battle" and message.is_empty() \
			and local_panel=="" and _modal_root==null and _base_page==current_page and is_instance_valid(current_page) and current_page.has_method("refresh_after_battle") \
			and update_after_battle():
			return
		# Salvage and other stable preparation operations update the existing HUD;
		# operations that change phase, panel or board topology use full render.
		if command=="salvage" and old_phase=="preparation" and session.phase()=="preparation" and message.is_empty() \
			and local_panel=="" and _modal_root==null and _base_page==current_page and is_instance_valid(current_page) and current_page.has_method("refresh_after_operation") \
			and _pending_receipt.get("uids",[]).is_empty() and update_after_operation():
			return
	render()
	if not narrative_playing and not _transition_command_running: _maybe_story()

## Difficulty unlocks are meta progress, so they are recorded at the moment a run
## ends, independently of the single-run save.
func _sync_meta_progress() -> void:
	persistence_coordinator._sync_meta_progress(self)

func _persist_profile() -> bool:
	return persistence_coordinator._persist_profile(self)

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

func update_after_battle() -> bool:
	if local_panel!="" or session.panel!="" or not is_instance_valid(current_page): return false
	var view:=hud_view()
	if not current_page.refresh_after_battle(view): return false
	world_view.sync(view)
	_base_signature=_retained_hud_signature()
	_update_world_framing.call_deferred()
	return true

func update_after_operation() -> bool:
	if local_panel!="" or session.panel!="" or not is_instance_valid(current_page): return false
	var view:=hud_view()
	if not current_page.refresh_after_operation(view): return false
	world_view.sync(view)
	var interaction:=find_child("RaftInteraction",true,false)
	if is_instance_valid(interaction) and interaction.has_method("refresh_policy"): interaction.refresh_policy()
	_base_signature=_retained_hud_signature()
	_update_world_framing.call_deferred()
	return true

func _init_narrative() -> void:
	narrative_coordinator._init_narrative(self)

func _apply_pending_narrative() -> void:
	narrative_coordinator._apply_pending_narrative(self)

func pick_narrative(id: String) -> void:
	narrative_coordinator.pick_narrative(self, id)

func _start_story_run(args: Dictionary) -> void:
	narrative_coordinator._start_story_run(self, args)

func load_story_run(id: String, replace_current: bool = false) -> bool:
	return narrative_coordinator.load_story_run(self, id, replace_current)

func pick_new_narrative(label: String) -> void:
	narrative_coordinator.pick_new_narrative(self, label)

func pick_no_narrative() -> void:
	narrative_coordinator.pick_no_narrative(self)

func attach_narrative(id: String) -> bool:
	return narrative_coordinator.attach_narrative(self, id)

func create_narrative(label: String) -> bool:
	return narrative_coordinator.create_narrative(self, label)

func detach_narrative() -> void:
	narrative_coordinator.detach_narrative(self)

func switch_narrative(id: String) -> void:
	narrative_coordinator.switch_narrative(self, id)

func save_narrative() -> void:
	narrative_coordinator.save_narrative(self)

func save_narrative_quiet() -> bool:
	return persistence_coordinator.save_narrative_quiet(self)

func narrative_status() -> String:
	return narrative_coordinator.narrative_status(self)

func _maybe_story() -> void:
	if _ui_command_pending: return
	narrative_coordinator._maybe_story(self)

func _open_narrative(scene: Dictionary) -> void:
	narrative_coordinator._open_narrative(self, scene)

func _on_narrative_completed(result: Dictionary) -> void:
	narrative_coordinator._on_narrative_completed(self, result)

func _close_narrative() -> void:
	narrative_coordinator._close_narrative(self)

func _open_story_review(id: String) -> void:
	narrative_coordinator._open_story_review(self, id)

func page(id: String, parent: Node, view: Dictionary) -> Control:
	return page_host.page(self, id, parent, view)

func _retained_hud_signature() -> String:
	return preload("res://application/hud_projection.gd").signature(self)+JSON.stringify(_pending_receipt)

func _game_panel_id(view: Dictionary) -> String:
	return page_host._game_panel_id(self, view)

func _remove_modal_layer() -> void:
	page_host._remove_modal_layer(self)

func _block_base_controls() -> void:
	page_host._block_base_controls(self)

func _restore_base_controls(view: Dictionary) -> void:
	page_host._restore_base_controls(self, view)

func _refresh_modal_only(view: Dictionary) -> bool:
	return page_host._refresh_modal_only(self, view)

func _refresh_hud_notice(panel_id: String) -> void:
	page_host._refresh_hud_notice(self, panel_id)

func _queue_mobile_control_policy(node: Node) -> void:
	if display_settings.mobile and node is Control and is_ancestor_of(node):
		_apply_mobile_control_policy.call_deferred(weakref(node))

func _apply_mobile_control_policy(reference: WeakRef) -> void:
	var node := reference.get_ref() as Control
	if not is_instance_valid(node) or not is_ancestor_of(node) or not display_settings.mobile: return
	W.suppress_mobile_hover(node)
	preload("res://presentation/touch_scroll.gd").configure(node)

func render(staged: bool = false) -> void:
	set_meta("mobile_ui",display_settings.mobile)
	persistence_coordinator.refresh_notice(self)
	await page_host.render(self, staged)
	music.sync(self)
	ambience.sync(self)
	if display_settings.mobile:
		for node in find_children("*","Control",true,false):
			W.suppress_mobile_hover(node)
			preload("res://presentation/touch_scroll.gd").configure(node)

func _build_modal(panel_id: String, view: Dictionary) -> void:
	page_host._build_modal(self, panel_id, view)

func _add_tutorial_banner(host: Control, view: Dictionary, modal: bool = false) -> void:
	page_host._add_tutorial_banner(self, host, view, modal)

func local_content(parent: Node, id: String, view: Dictionary) -> void:
	page_host.local_content(self, parent, id, view)

func disable_buttons(node: Node) -> void:
	page_host.disable_buttons(self, node)

func confirm_abandon() -> void:
	page_host.confirm_abandon(self)
