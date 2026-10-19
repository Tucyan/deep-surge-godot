extends RefCounted
## Owns page host responsibilities; app is the composition boundary.
const Tutorial = preload("res://core/tutorial_rules.gd")
const W = preload("res://presentation/widgets.gd")
const SettlementPage = preload("res://pages/settlement_page.gd")
const NarrativeMenu = preload("res://pages/narrative_menu.gd")
const PAGES := {"home":preload("res://pages/flow_home.gd"),"setup":preload("res://pages/new_game_setup.gd"),"game":preload("res://pages/voyage_hud.gd"),"story":preload("res://pages/flow_story.gd"),"battle":preload("res://pages/flow_battle.gd"),"craft":preload("res://pages/craft_page.gd"),"build":preload("res://pages/craft_page.gd"),"raft":preload("res://pages/paged_reference.gd"),"shop":preload("res://pages/shop_page.gd"),"encyclopedia":preload("res://pages/paged_reference.gd"),"meta_shop":preload("res://pages/paged_reference.gd"),}
var current_page: Control
var layout: Control
var title_backdrop: Control
var _base_page: Control
var _modal_root: Control
var _modal_id := ""
var _base_signature := ""
var _blocked_buttons: Dictionary = {}
var _blocked_modes: Dictionary = {}
var _blocked_visuals: Dictionary = {}
var _context_pages: Array[WeakRef]=[]
var _blocked_revision:=-1

func page(app, id: String, parent: Node, view: Dictionary) -> Control:
	var result: Control = PAGES[id].new()
	parent.add_child(result)
	result.action_requested.connect(app.handle_ui)
	result.command_requested.connect(app.request_command)
	_context_pages.append(weakref(result))
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if parent is Control and not parent is Container: result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if result.has_method("configure_session"): result.configure_session(app.session)
	result.setup(view,app.catalog,app.assets)
	return result


func _game_panel_id(app, view: Dictionary) -> String:
	var id: String=app.local_panel if app.local_panel!="" else view.panel
	if view.phase in ["story","battle"] and id in ["story","battle"]: return ""
	return id


func _remove_modal_layer(app) -> void:
	if is_instance_valid(_modal_root):
		_modal_root.get_parent().remove_child(_modal_root); _modal_root.queue_free()
	_modal_root=null; _modal_id=""


func _block_base_controls(app) -> void:
	if not is_instance_valid(_base_page): return
	if _blocked_buttons.is_empty(): _blocked_revision=app.session.revision
	for button in _base_page.find_children("*","BaseButton",true,false):
		var id: int=button.get_instance_id()
		if not _blocked_buttons.has(id): _blocked_buttons[id]={"node":weakref(button),"disabled":button.disabled}
		button.disabled=true
	var interaction=layout.get_node_or_null("RaftInteraction")
	for node in [_base_page,interaction]:
		if not is_instance_valid(node): continue
		var id: int=node.get_instance_id()
		if not _blocked_modes.has(id): _blocked_modes[id]={"node":weakref(node),"mode":node.process_mode}
		node.process_mode=Node.PROCESS_MODE_DISABLED
	for fan in _base_page.find_children("hand_fan","",true,false): fan.cancel_gesture()
	if is_instance_valid(interaction) and is_instance_valid(interaction.surface):
		var visual=interaction.surface
		if not _blocked_visuals.has(visual.get_instance_id()): _blocked_visuals[visual.get_instance_id()]={"node":weakref(visual),"visible":visual.visible}
		visual.hide()
	app.world_view.set_camera_input_enabled(false)


func _restore_base_controls(app, view: Dictionary) -> void:
	for entry in _blocked_buttons.values():
		var node=entry.node.get_ref()
		if is_instance_valid(node): node.disabled=entry.disabled
	for entry in _blocked_modes.values():
		var node=entry.node.get_ref()
		if is_instance_valid(node): node.process_mode=entry.mode
	for entry in _blocked_visuals.values():
		var node=entry.node.get_ref()
		if is_instance_valid(node): node.visible=entry.visible
	_blocked_buttons.clear(); _blocked_modes.clear(); _blocked_visuals.clear()
	var interaction=layout.get_node_or_null("RaftInteraction")
	if is_instance_valid(interaction) and _blocked_revision!=app.session.revision: interaction.refresh_policy()
	_blocked_revision=-1
	app.world_view.set_camera_input_enabled(view.screen=="game" and app._game_panel_id(view)=="")


func _refresh_modal_only(app, view: Dictionary) -> bool:
	if view.screen!="game" or app.narrative_playing or not is_instance_valid(_base_page) or not is_instance_valid(layout): return false
	if _base_signature!=app._retained_hud_signature(): return false
	var panel_id=app._game_panel_id(view)
	var supported: Array=["","settings","help","craft","build","raft","encyclopedia"]
	if not panel_id in supported or not _modal_id in supported: return false
	if panel_id=="" and not is_instance_valid(_modal_root): return false
	app.camera_binding_capture=false
	app._remove_modal_layer()
	current_page=_base_page
	# Base page closures stamp revisions at execution time. Shared hand/battle
	# contexts see the updated dictionary too, preserving stale-command checks.
	var live_pages: Array[WeakRef]=[]
	for reference in _context_pages:
		var node=reference.get_ref()
		if not is_instance_valid(node) or not node.is_inside_tree(): continue
		live_pages.append(reference)
		for field in ["revision","panel","page","ui_state","camera_mode"]: node.context[field]=view[field]
	_context_pages=live_pages
	if panel_id!="": app._build_modal(panel_id,view)
	else: app._restore_base_controls(view)
	app._refresh_hud_notice(panel_id)
	var banner=layout.get_node_or_null("TutorialBanner")
	if is_instance_valid(banner): layout.remove_child(banner); banner.queue_free()
	if panel_id not in ["settings","help","narrative"]: app._add_tutorial_banner(layout,view,panel_id!="")
	return true


func _refresh_hud_notice(app, panel_id: String) -> void:
	var notice=layout.get_node_or_null("HudNotice") as Label
	if panel_id!="" or app.message.is_empty():
		if is_instance_valid(notice): layout.remove_child(notice); notice.queue_free()
		return
	if not is_instance_valid(notice):
		notice=W.text(layout,"",18,Color("efb395")); notice.name="HudNotice"
		notice.position=Vector2(28,200); notice.size=Vector2(580,60)
		var backdrop = StyleBoxFlat.new()
		backdrop.bg_color=Color(0.025,0.045,0.06,0.9)
		backdrop.border_color=Color(0.5,0.56,0.59,0.55)
		backdrop.set_border_width_all(1); backdrop.set_corner_radius_all(5)
		backdrop.content_margin_left=14; backdrop.content_margin_right=14
		backdrop.content_margin_top=10; backdrop.content_margin_bottom=10
		notice.add_theme_stylebox_override("normal",backdrop)
		notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	notice.text=app.message


func render(app, staged: bool = false) -> void:
	if app._defer_transition_render: return
	# A pure modal dismissal needs no inventory projection or story-slot scan.
	if not staged and app.local_panel=="" and is_instance_valid(_modal_root) and is_instance_valid(_base_page) and _base_signature==app._retained_hud_signature():
		var panel: String=app.session.panel
		if app.session.phase() in ["story","battle"] and panel==app.session.phase(): panel=""
		if panel=="":
			var retained: Dictionary=_base_page.context.duplicate(false)
			retained.revision=app.session.revision; retained.panel=app.session.panel
			retained.page=app.session.panel if app.session.panel!="" else app.session.screen
			retained.ui_state=app.ui_state.duplicate(true); retained.camera_mode=app.display_settings.camera_mode
			if app._refresh_modal_only(retained): return
	app.set_meta("mobile_ui",app.display_settings.mobile)
	var view: Dictionary = app.hud_view()
	view["loading_transition"]=staged
	if app._refresh_modal_only(view): return
	_base_page=null; _modal_root=null; _modal_id=""; _base_signature=""
	_context_pages.clear(); _blocked_revision=-1
	_blocked_buttons.clear(); _blocked_modes.clear(); _blocked_visuals.clear()
	app.camera_binding_capture=false
	app.world_view.set_camera_input_enabled(false)
	if is_instance_valid(app.event_target_surface): app.event_target_surface.hide(); app.event_target_surface.queue_free()
	var hand_visual = {}
	if is_instance_valid(layout) and not app.reset_hand_visual:
		for fan in app.get_tree().get_nodes_in_group("hand_fans"):
			if layout.is_ancestor_of(fan): hand_visual[fan.get_meta("presentation_role","hand")] = fan.capture_visual()
	app.reset_hand_visual = false
	if is_instance_valid(layout): app.remove_child(layout); layout.queue_free()
	if view.has("hand"):
		var arranged: Array=app.hand_layout.build(view.hand)
		app.hand_layout.order.clear()
		for group in arranged: app.hand_layout.order.append_array(group.stack_uids)
	var report: Dictionary = view.get("settlement",{}) if view.screen=="game" and view.phase in ["finished","chapterComplete"] else {}
	app.world_view.visible=report.is_empty()
	if not report.is_empty():
		if is_instance_valid(title_backdrop): title_backdrop.hide()
		var settlement_host = Control.new(); settlement_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		app.add_child(settlement_host); layout=settlement_host
		var background = ColorRect.new(); background.color=Color("081b25"); background.mouse_filter=Control.MOUSE_FILTER_IGNORE
		settlement_host.add_child(background); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var settlement_page = SettlementPage.new(); settlement_host.add_child(settlement_page)
		settlement_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		settlement_page.action_requested.connect(app.handle_ui); settlement_page.command_requested.connect(app.handle_command)
		view.settlement=report; settlement_page.setup(view,app.catalog,app.assets); current_page=settlement_page
		if not app.message.is_empty():
			var note = W.text(settlement_host,app.message,17,Color("efb395"))
			note.position=Vector2(24,8); note.size=Vector2(900,44)
			note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		return
	app.world_view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	app.world_view.sync(view)
	if staged:
		await app.get_tree().process_frame
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	# Keep the decoder outside the rebuilt page layout during home interactions.
	if view.screen == "home":
		if not is_instance_valid(title_backdrop):
			title_backdrop = preload("res://presentation/title_menu.gd").new()
			title_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			app.add_child(title_backdrop)
			title_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			title_backdrop.create_background()
			if staged: await app.get_tree().process_frame
		title_backdrop.visible = app.setup_mode == ""
	elif is_instance_valid(title_backdrop):
		app.remove_child(title_backdrop)
		title_backdrop.queue_free()
		title_backdrop = null
	var host = Control.new(); host.mouse_filter=Control.MOUSE_FILTER_IGNORE; host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_child(host); layout = host
	# Embedded event surface sits above the world, below all persistent HUD controls.
	if view.screen=="game" and view.phase=="story":
		var event_surface=ColorRect.new(); event_surface.name="NodeEventSurface"
		event_surface.color=Color(0.025,0.055,0.08,0.78); host.add_child(event_surface)
		event_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# z 1: above the 3D view and its covered utilities (z 0), below the persistent HUD (z 2).
		event_surface.z_index=1
		# Three columns (illustration | prose | options) share one inset so they stay aligned.
		var event_body=Control.new(); event_body.name="NodeEventBodyHost"; event_surface.add_child(event_body)
		event_body.anchor_left=0.0; event_body.anchor_top=0.0; event_body.anchor_right=1.0; event_body.anchor_bottom=1.0
		# Tutorial guidance overlays the heading; event columns retain their full height.
		var story_top: float = 124.0
		event_body.offset_left=56; event_body.offset_top=story_top; event_body.offset_right=-56; event_body.offset_bottom=-328
		app.page("story",event_body,view)
	current_page = app.page("setup" if view.screen == "home" and app.setup_mode != "" else view.screen,host,view)
	var panel_id: String = app.local_panel if app.local_panel != "" else view.panel
	if view.screen=="game" and view.phase in ["story","battle"] and panel_id in ["story","battle"]: panel_id=""
	_base_page=current_page
	if panel_id != "":
		app._build_modal(panel_id,view)
	app._refresh_hud_notice(panel_id)

	for fan in app.get_tree().get_nodes_in_group("hand_fans"):
		if layout.is_ancestor_of(fan):
			fan.restore_visual(hand_visual.get(fan.get_meta("presentation_role","hand"),{}))

	if view.screen=="game" and view.get("can_base",false):
		var interaction=preload("res://presentation/raft_interaction.gd").new()
		host.add_child(interaction); interaction.create(app)
		if panel_id!="": app._block_base_controls()
	app.world_view.set_camera_input_enabled(view.screen=="game" and panel_id=="" and report.is_empty())
	if panel_id not in ["settings","help","narrative"]:
		app._add_tutorial_banner(host,view,panel_id!="")
	_base_signature=app._retained_hud_signature()
	app._update_world_framing.call_deferred()
	if staged:
		var menu=current_page.find_child("HomeMenu",true,false)
		while is_instance_valid(menu) and menu.building:
			await app.get_tree().process_frame
		await app.get_tree().process_frame

## Modal contents retain the original layout; their container is independent of
## the retained game HUD so opening/closing them need not recreate that HUD.

func _build_modal(app, panel_id: String, view: Dictionary) -> void:
	_modal_id=panel_id
	app._block_base_controls()
	var host=Control.new(); host.name="GameModalLayer"; host.z_index=200
	host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_child(host); _modal_root=host
	var shade = ColorRect.new(); shade.z_index = 0; shade.color = Color(0.01,0.02,0.03,0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); host.add_child(shade)
	var inset = MarginContainer.new(); inset.z_index = 1; inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.anchor_left = 0.12; inset.anchor_right = 0.88; inset.anchor_top = 0.10; inset.anchor_bottom = 0.77
	if panel_id in ["battle","raft"]:
		inset.anchor_left=0.035; inset.anchor_right=0.965; inset.anchor_top=0.035; inset.anchor_bottom=0.965
	if panel_id in ["craft","shop","build","encyclopedia","meta_shop"]:
		inset.anchor_left=0; inset.anchor_right=1; inset.anchor_top=0; inset.anchor_bottom=1
	if panel_id == "recall":
		inset.anchor_left=0.035; inset.anchor_right=0.965; inset.anchor_top=0.035; inset.anchor_bottom=0.965
	if panel_id=="settings":
		inset.anchor_left=0.5; inset.anchor_right=0.5; inset.anchor_top=0.04; inset.anchor_bottom=0.96
		var panel_width=minf(700.0,app.size.x-40.0)
		inset.offset_left=-panel_width*0.5; inset.offset_right=panel_width*0.5
	host.add_child(inset)
	var dialog = W.panel(inset)
	var surface: PanelContainer=dialog.get_parent(); surface.name="ModalSurface"
	if panel_id == "recall":
		var gallery_style: StyleBoxFlat = surface.get_theme_stylebox("panel").duplicate()
		gallery_style.bg_color = Color("0b1b24")
		surface.add_theme_stylebox_override("panel", gallery_style)
	if panel_id=="settings": W.text(dialog,"设置",28,W.GOLD)
	if not app.message.is_empty(): W.text(dialog,app.message,17,Color("ecb49a"))
	if panel_id in ["help","settings","narrative","recall"]: app.local_content(dialog,panel_id,view)
	else: current_page = app.page(panel_id,dialog,view)
	W.corner_close(surface,func():
		if app.local_panel != "": app.local_panel = ""; app.render()
		else: app.handle_command("close"))
	if panel_id in ["craft", "build"]:
		var help = Button.new()
		help.name = "CraftHelpButton"; help.text = "?"
		help.accessibility_name = "工作台说明"; help.tooltip_text = "工作台说明"
		surface.get_node("CloseOverlay").add_child(help)
		help.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		help.offset_left = -104; help.offset_right = -60
		help.offset_top = 0; help.offset_bottom = 44
		help.custom_minimum_size = Vector2(44, 44)
		help.add_theme_font_size_override("font_size", 26)
		for state in ["normal", "hover", "pressed", "focus"]:
			var style = StyleBoxFlat.new()
			style.bg_color = Color("203d49") if state in ["hover", "pressed"] else Color("0c1d26")
			style.border_color = W.GOLD if state in ["hover", "focus"] else Color("8b9a9e")
			style.set_border_width_all(2); style.set_corner_radius_all(22)
			help.add_theme_stylebox_override(state, style)
		help.pressed.connect(current_page.show_workbench_help)

## Persistent lesson strip. It never takes mouse input, so it guides without
## blocking the real interface the player is learning. It covers unrelated title
## regions rather than reserving vertical space in events or modal contents.

func _add_tutorial_banner(app, host: Control, view: Dictionary, modal: bool = false) -> void:
	if view.get("mode","") != "tutorial": return
	if view.get("screen","") != "game": return
	var lesson: Dictionary = view.get("tutorial_hint",{})
	if lesson.is_empty(): return
	var outer = PanelContainer.new()
	outer.name = "TutorialBanner"
	outer.z_index = 260
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.anchor_left = 0.5; outer.anchor_right = 0.5; outer.anchor_top = 0; outer.anchor_bottom = 0
	var hint_width: float=minf(840.0,app.size.x-112.0)
	outer.offset_left = -hint_width*0.5; outer.offset_right = hint_width*0.5
	if modal:
		# The header gap between left-hand tabs and right-hand help/close controls.
		outer.anchor_left=0; outer.anchor_right=1
		outer.offset_left=500; outer.offset_right=-144
		outer.offset_top=4; outer.offset_bottom=76
	else:
		# Cover the unrelated voyage heading; preserve all current node/battle space.
		var heading_width: float=minf(600.0,maxf(280.0,(app.size.x-200.0)*.42-24.0))
		outer.anchor_left=0; outer.anchor_right=0
		outer.offset_left=24; outer.offset_right=24+heading_width
		outer.offset_top=8; outer.offset_bottom=96
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03,0.07,0.09,0.94)
	style.border_color = W.GOLD; style.set_border_width_all(1); style.set_corner_radius_all(3)
	style.content_margin_left = 16; style.content_margin_right = 16
	style.content_margin_top = 8; style.content_margin_bottom = 8
	outer.add_theme_stylebox_override("panel",style)
	host.add_child(outer)
	var box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation",3)
	outer.add_child(box)
	var head = W.text(box,"新手教程 · %d/%d · %s" % [int(lesson.get("index",1)),int(lesson.get("total",1)),str(lesson.get("title",""))],18,W.GOLD)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_text: String=str(lesson.get("text",""))
	if lesson.get("id","") in ["enchant_attack2","enchant_block2"]:
		var attack: bool=lesson.id=="enchant_attack2"
		var gesture: String="拖出" if view.get("mobile",false) else "双击"
		hint_text=("选废铁，再%s攻击牌附魔：1 AP、2伤害，消耗废铁1。详见出招预览。" if attack else "选木头，再%s防御牌附魔：1 AP、3护盾，消耗木头1。详见出招预览。") % gesture
	if modal and lesson.get("id","")=="sell3":
		hint_text="切到『出售手牌』，选择尸体并确认出售：获得3贝币，不消耗AP。"
	if modal and lesson.get("id","")=="craft1":
		hint_text="选择『制造滤水器』：消耗塑料2、木头1和1 AP。"
	var body = W.text(box,hint_text,16,W.INK)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var detail = str(lesson.get("detail",""))
	if detail != "":
		var note = W.text(box,detail,15,W.MUTED)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE


func local_content(app, parent: Node, id: String, view: Dictionary) -> void:
	if id == "recall":
		var gallery = preload("res://pages/story_gallery.gd").new()
		parent.add_child(gallery)
		gallery.replay_requested.connect(func(story_id: String): app.handle_ui("recall_story", story_id))
		gallery.setup(app.story_gallery.entries(), app.assets)
	elif id == "narrative":
		NarrativeMenu.build_choice(parent, app)
	elif id == "help":
		W.text(parent,"航行须知",32,W.GOLD)
		for line in ["出发支付SAN航耗，抵达后进入准备；轮末弃牌完成、容量达标后才结算食水。","准备与收尾共享基地AP；制造消耗AP，设备安装不消耗AP。","事件先读文字，再作选择；战斗和商店结束后返回节点结果。","轮末处理筏格老化与超限整理；下一轮开始时完好设备推进生产，周期达标才产出。","事件自动显示在航行画面，完成当前事件后才能再次导航。"]: W.text(parent,line,20)
	else:
		preload("res://presentation/settings_panel.gd").build(parent,app,view)


func disable_buttons(app, node: Node) -> void:
	if node is BaseButton: node.disabled = true
	for child in node.get_children(): app.disable_buttons(child)


func confirm_abandon(app) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "放弃当前航程并按已完成节点结算？"
	dialog.title = "放弃航程"
	app.add_child(dialog)
	for button in [dialog.get_ok_button(), dialog.get_cancel_button()]:
		W.TextButtonArt.apply(button)
	dialog.confirmed.connect(func(): app.handle_command("abandon"); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()
