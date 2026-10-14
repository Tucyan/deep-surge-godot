extends PanelContainer
# Debug-only presentation tool. Never writes game state or shipped defaults.
const SAVE_PATH := "user://title-layout-debug.json"
const KEYS := ["start","continue","journal","shop","recall","quit","logo"]
var targets: Array[Control] = []
var defaults: Dictionary
var picker: OptionButton
var fields: Array[SpinBox] = []
var lock_ratio: CheckBox
var status: Label
var syncing := false
var editor_open := false
var body: VBoxContainer
var title
func setup(menu, logo: Control) -> void:
	title=menu
	for button in menu.buttons: targets.append(button)
	targets.append(logo)
	defaults=snapshot()
	position=Vector2(24,24); custom_minimum_size=Vector2(360,0); z_index=100
	var style:=StyleBoxFlat.new(); style.bg_color=Color(0.025,0.04,0.075,0.96)
	style.content_margin_left=16; style.content_margin_right=16; style.content_margin_top=12; style.content_margin_bottom=12
	add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new(); add_child(column)
	var toggle:=Button.new(); toggle.text="布局调试 · F8"; column.add_child(toggle); toggle.pressed.connect(toggle_editor)
	body=VBoxContainer.new(); column.add_child(body); body.hide()
	picker=OptionButton.new(); body.add_child(picker)
	for label in ["开始游戏","继续游戏","航海笔记","局外商店","回溯潮涌","退出游戏","游戏 Logo"]: picker.add_item(label)
	picker.item_selected.connect(func(_i): sync_fields())
	lock_ratio=CheckBox.new(); lock_ratio.text="锁定宽高比例"; lock_ratio.button_pressed=true; body.add_child(lock_ratio)
	for i in range(4):
		var row:=HBoxContainer.new(); body.add_child(row)
		var label:=Label.new(); label.text=["位置 X","位置 Y","宽度","高度"][i]; label.custom_minimum_size.x=80; row.add_child(label)
		var spin:=SpinBox.new(); spin.min_value=-2000 if i<2 else 20; spin.max_value=4000; spin.step=0.1; spin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(spin); fields.append(spin); spin.value_changed.connect(change_value.bind(i))
	var note:=Label.new(); note.text="参考画布 1672 × 941 · 修改即时预览"; body.add_child(note)
	add_action("保存调试记录",func(): save_to(SAVE_PATH))
	add_action("读取调试记录",load_saved)
	add_action("导出 JSON…",export_dialog)
	add_action("复制 JSON",func(): DisplayServer.clipboard_set(JSON.stringify(snapshot(),"\t")); status.text="参数已复制")
	add_action("恢复默认布局",func(): apply_snapshot(defaults); status.text="已恢复默认；保存记录未覆盖")
	status=Label.new(); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; status.custom_minimum_size.x=320; body.add_child(status)
	sync_fields()
func add_action(label: String, callback: Callable) -> void:
	var button:=Button.new(); button.text=label; body.add_child(button); button.pressed.connect(callback)
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8 and is_visible_in_tree():
		toggle_editor(); get_viewport().set_input_as_handled()
func toggle_editor() -> void:
	editor_open=not editor_open; body.visible=editor_open
	for i in title._tweens:
		if title._tweens[i].is_valid(): title._tweens[i].kill()
	for button in title.buttons:
		button.scale=Vector2.ONE
		button.mouse_filter=Control.MOUSE_FILTER_IGNORE if editor_open else Control.MOUSE_FILTER_STOP
		button.focus_mode=Control.FOCUS_NONE if editor_open else Control.FOCUS_ALL
	if editor_open: sync_fields()
	set_deferred("size",Vector2(360,0))
func sync_fields() -> void:
	syncing=true
	var target:=targets[picker.selected]
	var values:=[target.position.x,target.position.y,target.size.x,target.size.y]
	for i in range(4): fields[i].set_value_no_signal(values[i])
	syncing=false
func change_value(value: float, index: int) -> void:
	if syncing:return
	var target:=targets[picker.selected]
	var ratio:=target.size.x/target.size.y
	match index:
		0: target.position.x=value
		1: target.position.y=value
		2:
			target.size.x=value
			if lock_ratio.button_pressed: target.size.y=value/ratio
		3:
			target.size.y=value
			if lock_ratio.button_pressed: target.size.x=value*ratio
	target.pivot_offset=target.size*0.5
	sync_fields(); status.text="已修改；可保存记录或导出"
func snapshot() -> Dictionary:
	var items:={}
	for i in range(targets.size()):
		var target:=targets[i]
		items[KEYS[i]]={"x":target.position.x,"y":target.position.y,"width":target.size.x,"height":target.size.y}
	return {"schema":1,"reference_size":[1672,941],"items":items}
func apply_snapshot(data: Variant) -> bool:
	if not data is Dictionary or data.get("schema")!=1 or data.get("reference_size")!=[1672,941] or not data.get("items") is Dictionary:return false
	for key in KEYS:
		var item=data.items.get(key)
		if not item is Dictionary:return false
		for field in ["x","y","width","height"]:
			var value=item.get(field)
			if not (value is int or value is float) or not is_finite(float(value)):return false
		if item.width<20 or item.height<20 or item.width>4000 or item.height>4000 or abs(item.x)>2000 or abs(item.y)>2000:return false
	for i in range(targets.size()):
		var item=data.items[KEYS[i]]
		targets[i].position=Vector2(item.x,item.y); targets[i].size=Vector2(item.width,item.height); targets[i].pivot_offset=targets[i].size*0.5
	sync_fields(); return true
func save_to(path: String) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: status.text="保存失败："+error_string(FileAccess.get_open_error()); return false
	file.store_string(JSON.stringify(snapshot(),"\t")); file.close()
	status.text="已保存："+ProjectSettings.globalize_path(path); return true
func load_saved() -> void:
	if not FileAccess.file_exists(SAVE_PATH): status.text="尚无调试记录"; return
	var data=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	status.text="已读取调试记录" if apply_snapshot(data) else "记录格式无效，未修改布局"
func export_dialog() -> void:
	var dialog:=FileDialog.new(); dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE; dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.filters=PackedStringArray(["*.json ; JSON 布局参数"]); dialog.current_file="title-layout.json"
	add_child(dialog); dialog.file_selected.connect(func(path): save_to(path); dialog.queue_free()); dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(780,500))
