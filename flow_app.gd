extends Control
const Session = preload("res://core/game_session.gd")
const Catalog = preload("res://content/catalog.gd")
const Assets = preload("res://presentation/asset_catalog.gd")
const Store = preload("res://adapters/save_store.gd")
const W = preload("res://presentation/widgets.gd")
const World = preload("res://presentation/voyage_world.gd")
const SettlementPage = preload("res://pages/settlement_page.gd")
const PAGES := {"home":preload("res://pages/flow_home.gd"),"setup":preload("res://pages/new_game_setup.gd"),"game":preload("res://pages/voyage_hud.gd"),"story":preload("res://pages/flow_story.gd"),"battle":preload("res://pages/flow_battle.gd"),"craft":preload("res://pages/craft_page.gd"),"build":preload("res://pages/craft_page.gd"),"raft":preload("res://pages/paged_reference.gd"),"shop":preload("res://pages/shop_page.gd"),"encyclopedia":preload("res://pages/paged_reference.gd"),"meta_shop":preload("res://pages/paged_reference.gd"),"night":preload("res://pages/night_page.gd"),"journal":preload("res://pages/story_journal.gd")}
var catalog := Catalog.new()
var assets := Assets.new()
var store := Store.new()
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

func _ready() -> void:
	theme = W.theme()
	if not catalog.load_catalog(): W.text(self,"内容载入失败："+catalog.error,24); return
	session = Session.new(catalog)
	world_view = World.new()
	add_child(world_view)
	world_view.create(assets)
	if persistence:
		hand_layout.load_preferences()
		var saved := store.read()
		if not store.error.is_empty(): message = store.error; save_blocked = true
		elif not saved.is_empty() and not session.restore(saved): message = session.error; save_blocked = true
	if persistence:
		display_settings.load_preferences()
		display_settings.apply_window(get_window())
	world_view.motion=display_settings.motion
	world_view.camera_controls.locked=display_settings.view_locked
	world_view.camera_orbit_button=display_settings.camera_orbit_button
	world_view.camera_pan_button=display_settings.camera_pan_button
	resized.connect(update_render_resolution)
	update_render_resolution.call_deferred()
	render()

func update_render_resolution() -> void:
	if is_instance_valid(world_view) and is_instance_valid(world_view.viewport):
		world_view.set_render_size(display_settings.render_size(size,get_window().size))
		_update_world_framing.call_deferred()

func _update_world_framing() -> void:
	if not is_instance_valid(layout) or not world_view.visible: return
	var frame:=layout.find_child("VoyageOperationFrame",true,false)
	var tray:=layout.find_child("VoyageHandTray",true,false)
	if frame==null or tray==null: return
	var top:=196.0
	var right: float=frame.global_position.x-global_position.x-18.0
	var bottom: float=tray.global_position.y-global_position.y-58.0
	var safe:=Rect2(Vector2(24,top),Vector2(maxf(200,right-24),maxf(160,bottom-top)))
	world_view.set_framing_rect(Rect2(safe.position/size,safe.size/size))

func apply_display_settings(change_mode: bool = true) -> void:
	var focused:=get_viewport().gui_get_focus_owner()
	var restore_slider_focus: bool=is_instance_valid(focused) and focused.name=="UIScale"
	display_settings.apply_window(get_window(),change_mode)
	world_view.motion=display_settings.motion
	world_view.camera_controls.locked=display_settings.view_locked
	world_view.camera_orbit_button=display_settings.camera_orbit_button
	world_view.camera_pan_button=display_settings.camera_pan_button
	if persistence and display_settings.save_preferences()!=OK: message="显示设置保存失败"
	update_render_resolution.call_deferred()
	render()
	if restore_slider_focus: _restore_scale_focus.call_deferred()

func _restore_scale_focus() -> void:
	var slider:=layout.find_child("UIScale",true,false)
	if is_instance_valid(slider): slider.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if camera_binding_capture:
		if event.keycode==KEY_ESCAPE:
			camera_binding_capture=false; render()
		elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and display_settings.valid_camera_reset_key(int(event.keycode)):
			display_settings.camera_reset_key=int(event.keycode); camera_binding_capture=false; apply_display_settings(false)
		get_viewport().set_input_as_handled(); return
	if not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and event.keycode==display_settings.camera_reset_key:
		if is_instance_valid(world_view) and world_view.camera_input_enabled:
			world_view.reset_camera_view(); get_viewport().set_input_as_handled()

func handle_ui(action: String, value: String = "") -> void:
	if action=="camera_reset":
		world_view.reset_camera_view(); return
	if action=="event_target":
		if session.phase()!="story": return
		var target: Dictionary=session.Rules.find_cell(session.state,value)
		if target.is_empty(): return
		if is_instance_valid(event_target_surface): event_target_surface.hide(); event_target_surface.queue_free()
		event_target_surface=preload("res://presentation/raft_surface.gd").new()
		event_target_surface.create(world_view,[]); event_target_surface.select(target)
		return
	match action:
		"setup": setup_mode = value
		"quit": get_tree().quit(); return
		"local_panel": local_panel = value
		"hand_page": ui_state.hand_page = maxi(0,int(value))
		"list_page": ui_state.list_page = maxi(0,int(value)); ui_state.selected_id = ""
		"selected_id": ui_state.selected_id = value
		"category": ui_state.category = value; ui_state.list_page = 0; ui_state.selected_id = ""
		"card": ui_state.card = value
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

func handle_command(command: String, args: Dictionary = {}) -> void:
	reset_hand_visual = command == "new"
	var old_panel: String = session.panel
	if not session.dispatch(command,args):
		message = session.error
	else:
		message = ""
		local_panel = ""
		ui_state.card = ""
		ui_state.battle_selection = ""
		if old_panel != session.panel:
			ui_state.list_page = 0; ui_state.selected_id = ""; ui_state.category = ""
			ui_state.craft_tab = "craft"; ui_state.transmute_target = "wood"; ui_state.transmute_uids = ""
			ui_state.transmute_count = 1
		if command == "new":
			setup_mode = ""; save_blocked = false; hand_layout.order.clear(); world_view.reset_camera_view()
		if persistence and not save_blocked and not store.write(session.snapshot()): message = store.error
	render()

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
	var view: Dictionary = session.view()
	view.setup_mode = setup_mode
	view.ui_state = ui_state.duplicate(true)
	view.hand_layout = hand_layout
	view.ui_scale = display_settings.ui_scale
	view.camera_help = display_settings.camera_help()
	if view.has("hand"):
		var arranged: Array=hand_layout.build(view.hand)
		hand_layout.order.clear()
		for group in arranged: hand_layout.order.append_array(group.stack_uids)
	var report: Dictionary = view.get("settlement",{}) if view.screen=="game" and view.phase in ["finished","chapterComplete"] else {}
	if local_panel=="recall" and not session.last_settlement.is_empty(): report=session.last_settlement.duplicate(true)
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
		if not message.is_empty(): W.text(settlement_host,message,17,Color("efb395")).position=Vector2(24,8)
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
		var event_content:=preload("res://presentation/hud_frame.gd").new(); event_content.name="NodeEventFrame"; event_surface.add_child(event_content)
		event_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		event_content.anchor_left=1.0; event_content.anchor_top=0.0
		event_content.offset_left=-356; event_content.offset_top=200
		event_content.offset_right=-24; event_content.offset_bottom=-302
		if display_settings.ui_scale>1.0:
			event_content.offset_top=182; event_content.offset_bottom=-280
		var event_style: StyleBoxFlat=PAGES.game.compact_style()
		event_style.content_margin_top=14; event_style.content_margin_bottom=12
		event_content.add_theme_stylebox_override("panel",event_style)
		page("story",event_content,view)
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
		if panel_id in ["craft","shop","build"]:
			inset.anchor_left=0; inset.anchor_right=1; inset.anchor_top=0; inset.anchor_bottom=1
		if panel_id=="settings":
			inset.anchor_left=0.5; inset.anchor_right=0.5; inset.anchor_top=0.04; inset.anchor_bottom=0.96
			var panel_width:=minf(700.0,size.x-40.0)
			inset.offset_left=-panel_width*0.5; inset.offset_right=panel_width*0.5
		host.add_child(inset)
		var dialog := W.panel(inset)
		var surface: PanelContainer=dialog.get_parent(); surface.name="ModalSurface"
		if panel_id=="settings": W.text(dialog,"设置",28,W.GOLD)
		if not message.is_empty(): W.text(dialog,message,17,Color("ecb49a"))
		if panel_id in ["help","settings","recall"]: local_content(dialog,panel_id,view)
		else: current_page = page(panel_id,dialog,view)
		W.corner_close(surface,func():
			if local_panel != "": local_panel = ""; render()
			else: handle_command("close"))
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
	_update_world_framing.call_deferred()

func local_content(parent: Node, id: String, view: Dictionary) -> void:
	if id == "recall":
		W.text(parent,"回溯潮涌",32,W.GOLD)
		if view.profile.endings.is_empty(): W.text(parent,"尚无已记录的航程结局。",20)
		else:
			for ending in view.profile.endings:
				W.text(parent,{"survived":"灯火未熄","withdrawn":"离开潮眼","dead":"沉入深潮","mad":"迷失潮声","abandon":"返回岸边"}.get(ending,ending),20)
	elif id == "help":
		W.text(parent,"航行须知",32,W.GOLD)
		for line in ["出发支付一次食水与SAN航耗，抵达后进入准备。","准备与收尾共享基地AP；制造消耗AP，设备安装不消耗AP。","事件先读文字，再作选择；战斗和商店结束后返回剧情。","轮末处理筏格老化与超限整理；下一轮开始时设备生产。","事件自动显示在航行画面，完成当前事件后才能再次导航。"]: W.text(parent,line,20)
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
	dialog.confirmed.connect(func(): handle_command("abandon"); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()
