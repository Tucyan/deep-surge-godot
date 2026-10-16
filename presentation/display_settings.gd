extends RefCounted
## Local presentation preferences, deliberately separate from GameSession saves.
const RESOLUTIONS := [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]
const QUALITY := [0.5,0.75,1.0,1.25]
const CLARITY_NAMES := ["流畅","清晰","高清","超高清"]
const FRAME_RATES := [30,60,90,120,0]
const CAMERA_MOUSE_BUTTONS := [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]
var mobile: bool
var ui_scale: float
var quality := 2
var resolution := Vector2i(1280,720)
var free_aspect := false
var fullscreen := false
var motion := true
var view_locked := false
var camera_orbit_button := MOUSE_BUTTON_RIGHT
var camera_pan_button := MOUSE_BUTTON_LEFT
var camera_reset_key := KEY_R
var fps_limit := 60
var path := "user://display-settings.cfg"

func _init(is_mobile: bool = OS.has_feature("mobile")) -> void:
	mobile=is_mobile; ui_scale=1.25 if mobile else 1.0
func supports_window_options() -> bool: return not mobile
static func mouse_button_name(button: int) -> String:
	return {MOUSE_BUTTON_LEFT:"左键",MOUSE_BUTTON_RIGHT:"右键",MOUSE_BUTTON_MIDDLE:"中键"}.get(button,"未绑定")
static func valid_camera_reset_key(key: Variant) -> bool:
	return key is int and ((key>=KEY_A and key<=KEY_Z) or (key>=KEY_0 and key<=KEY_9) or (key>=KEY_F1 and key<=KEY_F12) or key in [KEY_HOME,KEY_END,KEY_INSERT,KEY_PAGEUP,KEY_PAGEDOWN])
func set_camera_mouse_binding(action: String, button: int) -> bool:
	if action not in ["orbit","pan"] or button not in CAMERA_MOUSE_BUTTONS: return false
	var target: String="camera_orbit_button" if action=="orbit" else "camera_pan_button"
	var other: String="camera_pan_button" if action=="orbit" else "camera_orbit_button"
	if get(other)==button: set(other,get(target))
	set(target,button); return true
func reset_camera_bindings() -> void:
	camera_orbit_button=MOUSE_BUTTON_RIGHT; camera_pan_button=MOUSE_BUTTON_LEFT; camera_reset_key=KEY_R
func camera_help() -> String:
	return "%s旋转，%s水平平移，滚轮缩放；%s平滑复位" % [mouse_button_name(camera_orbit_button),mouse_button_name(camera_pan_button),OS.get_keycode_string(camera_reset_key)]
func load_preferences() -> void:
	var config:=ConfigFile.new()
	if config.load(path)!=OK: return
	var scale_value = config.get_value("display","ui_scale",ui_scale)
	if (scale_value is float or scale_value is int) and is_finite(float(scale_value)):
		ui_scale=clampf(float(scale_value),1.0,1.25)
	var quality_value = config.get_value("display","quality",quality)
	if quality_value is int: quality=clampi(quality_value,0,3)
	var size_value = config.get_value("display","resolution",resolution)
	if size_value in RESOLUTIONS: resolution=size_value
	elif size_value==Vector2i(1600,900): resolution=Vector2i(1280,720)
	free_aspect=config.get_value("display","free_aspect",false)==true
	fullscreen=not mobile and config.get_value("display","fullscreen",false)==true
	motion=config.get_value("display","motion",true)==true
	view_locked=config.get_value("display","view_locked",false)==true
	var orbit_value=config.get_value("display","camera_orbit_button",MOUSE_BUTTON_RIGHT)
	var pan_value=config.get_value("display","camera_pan_button",MOUSE_BUTTON_LEFT)
	if orbit_value is int and pan_value is int and orbit_value in CAMERA_MOUSE_BUTTONS and pan_value in CAMERA_MOUSE_BUTTONS and orbit_value!=pan_value:
		camera_orbit_button=orbit_value; camera_pan_button=pan_value
	else:
		camera_orbit_button=MOUSE_BUTTON_RIGHT; camera_pan_button=MOUSE_BUTTON_LEFT
	var reset_value=config.get_value("display","camera_reset_key",KEY_R)
	camera_reset_key=reset_value if valid_camera_reset_key(reset_value) else KEY_R
	var fps_value = config.get_value("display","fps_limit",60)
	fps_limit=fps_value if fps_value is int and fps_value in FRAME_RATES else 60
func save_preferences() -> Error:
	var config:=ConfigFile.new()
	for key in ["ui_scale","quality","resolution","free_aspect","fullscreen","motion","view_locked","camera_orbit_button","camera_pan_button","camera_reset_key","fps_limit"]: config.set_value("display",key,get(key))
	return config.save(path)
func apply_window(window: Window, change_mode: bool = true) -> void:
	window.content_scale_factor=ui_scale
	window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND if free_aspect else Window.CONTENT_SCALE_ASPECT_KEEP
	Engine.max_fps=fps_limit
	if DisplayServer.get_name()!="headless":
		# The chosen limit (including 0/unlimited) is authoritative on both platforms.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED,window.get_window_id())
	if mobile or not change_mode or DisplayServer.get_name()=="headless": return
	window.mode=Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if not fullscreen and not free_aspect:
		var usable:=DisplayServer.screen_get_usable_rect(window.current_screen)
		window.size=resolution.min(usable.size-Vector2i(32,64)).max(Vector2i(640,360))
		window.position=usable.position+(usable.size-window.size)/2
func render_size(logical: Vector2, physical: Vector2i) -> Vector2i:
	# Use physical pixels independently of the canvas scale. Only the 3D viewport
	# is downsampled; text, cards, title video and settings stay sharp.
	var factor: float=float(physical.y)/maxf(logical.y,1.0)
	if mobile: factor*=QUALITY[quality]
	elif fullscreen or free_aspect: factor=minf(factor,float(resolution.y)/maxf(minf(logical.x,logical.y),1.0))
	return Vector2i(logical*factor).max(Vector2i(2,2))
