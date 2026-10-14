extends Control
const Session = preload("res://core/game_session.gd")
const Catalog = preload("res://content/catalog.gd")
const Assets = preload("res://presentation/asset_catalog.gd")
const Store = preload("res://adapters/save_store.gd")
const W = preload("res://presentation/widgets.gd")
const World = preload("res://presentation/voyage_world.gd")
const PAGES := {"home":preload("res://pages/flow_home.gd"),"setup":preload("res://pages/new_game_setup.gd"),"game":preload("res://pages/voyage_hud.gd"),"story":preload("res://pages/flow_story.gd"),"battle":preload("res://pages/flow_battle.gd"),"craft":preload("res://pages/paged_reference.gd"),"raft":preload("res://pages/paged_reference.gd"),"shop":preload("res://pages/paged_reference.gd"),"encyclopedia":preload("res://pages/paged_reference.gd"),"meta_shop":preload("res://pages/paged_reference.gd"),"logs":preload("res://pages/paged_reference.gd"),"night":preload("res://pages/night_page.gd"),"journal":preload("res://pages/story_journal.gd")}
var catalog := Catalog.new()
var assets := Assets.new()
var store := Store.new()
var session: RefCounted
var current_page: Control
var layout: Control
var setup_mode := ""
var message := ""
var save_blocked := false
var persistence := true
var world_view: SubViewportContainer
var local_panel := ""
var reset_hand_visual := false
var ui_state := {"hand_page":0,"list_page":0,"selected_id":"","category":"","card":""}

func _ready() -> void:
	theme = W.theme()
	if not catalog.load_catalog(): W.text(self,"内容载入失败："+catalog.error,24); return
	session = Session.new(catalog)
	world_view = World.new()
	add_child(world_view)
	world_view.create(assets)
	if persistence:
		var saved := store.read()
		if not store.error.is_empty(): message = store.error; save_blocked = true
		elif not saved.is_empty() and not session.restore(saved): message = session.error; save_blocked = true
	render()

func handle_ui(action: String, value: String = "") -> void:
	match action:
		"setup": setup_mode = value
		"quit": get_tree().quit(); return
		"local_panel": local_panel = value
		"hand_page": ui_state.hand_page = maxi(0,int(value))
		"list_page": ui_state.list_page = maxi(0,int(value)); ui_state.selected_id = ""
		"selected_id": ui_state.selected_id = value
		"category": ui_state.category = value; ui_state.list_page = 0; ui_state.selected_id = ""
		"card": ui_state.card = value
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
		if old_panel != session.panel:
			ui_state.list_page = 0; ui_state.selected_id = ""; ui_state.category = ""
		if command == "new": setup_mode = ""; save_blocked = false
		if persistence and not save_blocked and not store.write(session.snapshot()): message = store.error
	render()

func page(id: String, parent: Node, view: Dictionary) -> Control:
	var result: Control = PAGES[id].new()
	parent.add_child(result)
	result.action_requested.connect(handle_ui)
	result.command_requested.connect(handle_command)
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if parent is Control and not parent is Container: result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.setup(view,catalog,assets)
	return result

func render() -> void:
	var hand_visual := {}
	if is_instance_valid(layout) and not reset_hand_visual:
		for fan in get_tree().get_nodes_in_group("hand_fans"):
			if layout.is_ancestor_of(fan): hand_visual[fan.get_meta("presentation_role","hand")] = fan.capture_visual()
	reset_hand_visual = false
	if is_instance_valid(layout): remove_child(layout); layout.queue_free()
	var view: Dictionary = session.view()
	view.setup_mode = setup_mode
	view.ui_state = ui_state.duplicate(true)
	world_view.sync(view)
	var host := Control.new(); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host); layout = host
	# Embedded event surface sits above the world, below all persistent HUD controls.
	if view.screen=="game" and view.phase=="story":
		var event_surface:=ColorRect.new(); event_surface.name="NodeEventSurface"
		event_surface.color=Color("0c1b26"); host.add_child(event_surface)
		event_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		event_surface.offset_bottom=-245
		var event_content:=MarginContainer.new(); event_surface.add_child(event_content)
		event_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for margin in ["left","right"]: event_content.add_theme_constant_override("margin_"+margin,64)
		event_content.add_theme_constant_override("margin_top",190)
		event_content.add_theme_constant_override("margin_bottom",100)
		page("story",event_content,view)
	current_page = page("setup" if view.screen == "home" and setup_mode != "" else view.screen,host,view)
	var panel_id: String = local_panel if local_panel != "" else view.panel
	if view.screen=="game" and view.phase=="story" and panel_id=="story": panel_id=""
	if panel_id != "":
		disable_buttons(current_page)
		var shade := ColorRect.new(); shade.z_index = 200; shade.color = Color(0.01,0.02,0.03,0.85)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); host.add_child(shade)
		var inset := MarginContainer.new(); inset.z_index = 201; inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.anchor_left = 0.12; inset.anchor_right = 0.88; inset.anchor_top = 0.10; inset.anchor_bottom = 0.77
		host.add_child(inset)
		var dialog := W.panel(inset)
		var header := HBoxContainer.new(); dialog.add_child(header)
		var title: String = "暂时收起，返回游戏页" if panel_id in ["story","battle","shop"] else "关闭面板"
		W.button(header,title,func():
			if local_panel != "": local_panel = ""; render()
			else: handle_command("close"))
		if view.screen == "game": W.button(header,"返回首页",func(): handle_command("home"))
		if not message.is_empty(): W.text(dialog,message,17,Color("ecb49a"))
		if panel_id in ["help","settings"]: local_content(dialog,panel_id,view)
		else: current_page = page(panel_id,dialog,view)
	elif not message.is_empty():
		var label := W.text(host,message,18,Color("efb395"))
		label.position = Vector2(28,200); label.size = Vector2(580,60)

	for fan in get_tree().get_nodes_in_group("hand_fans"):
		if layout.is_ancestor_of(fan):
			fan.restore_visual(hand_visual.get(fan.get_meta("presentation_role","hand"),{}))

func local_content(parent: Node, id: String, view: Dictionary) -> void:
	if id == "recall":
		W.text(parent,"回溯潮涌",32,W.GOLD)
		if view.profile.endings.is_empty(): W.text(parent,"尚无已记录的航程结局。",20)
		else:
			for ending in view.profile.endings:
				W.text(parent,{"survived":"灯火未熄","withdrawn":"离开潮眼","dead":"沉入深潮","mad":"迷失潮声","abandon":"返回岸边"}.get(ending,ending),20)
	elif id == "help":
		W.text(parent,"航行须知",32,W.GOLD)
		for line in ["出发支付一次食水与SAN航耗，抵达后进入准备。","准备与收尾共享基地AP；制造与安装分别收费。","事件先读文字，再作选择；战斗和商店结束后返回剧情。","轮末先处理筏格老化与生产，超限时整理手牌。","事件自动显示在航行画面，完成当前事件后才能再次导航。"]: W.text(parent,line,20)
	else:
		W.text(parent,"设置",32,W.GOLD)
		var toggle := CheckButton.new(); toggle.text = "海面与木筏动态"; toggle.button_pressed = world_view.motion
		parent.add_child(toggle); toggle.toggled.connect(func(enabled): world_view.motion = enabled)
		if view.active: W.button(parent,"放弃本局",func(): confirm_abandon())

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
