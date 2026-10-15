extends RefCounted
## Local presentation preferences, deliberately separate from GameSession saves.
const RESOLUTIONS := [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]
const QUALITY := [0.5,0.75,1.0]
const FRAME_RATES := [30,60,90,120,0]
var mobile: bool
var ui_scale: float
var quality := 2
var resolution := Vector2i(1280,720)
var fullscreen := false
var motion := true
var fps_limit := 60
var path := "user://display-settings.cfg"

func _init(is_mobile: bool = OS.has_feature("mobile")) -> void:
	mobile=is_mobile; ui_scale=1.25 if mobile else 1.0
func supports_window_options() -> bool: return not mobile
func load_preferences() -> void:
	var config:=ConfigFile.new()
	if config.load(path)!=OK: return
	var scale_value = config.get_value("display","ui_scale",ui_scale)
	if (scale_value is float or scale_value is int) and is_finite(float(scale_value)):
		ui_scale=clampf(float(scale_value),1.0,1.25)
	var quality_value = config.get_value("display","quality",quality)
	if quality_value is int: quality=clampi(quality_value,0,2)
	var size_value = config.get_value("display","resolution",resolution)
	if size_value in RESOLUTIONS: resolution=size_value
	fullscreen=not mobile and config.get_value("display","fullscreen",false)==true
	motion=config.get_value("display","motion",true)==true
	var fps_value = config.get_value("display","fps_limit",60)
	fps_limit=fps_value if fps_value is int and fps_value in FRAME_RATES else 60
func save_preferences() -> Error:
	var config:=ConfigFile.new()
	for key in ["ui_scale","quality","resolution","fullscreen","motion","fps_limit"]: config.set_value("display",key,get(key))
	return config.save(path)
func apply_window(window: Window, change_mode: bool = true) -> void:
	window.content_scale_factor=ui_scale
	Engine.max_fps=fps_limit
	if DisplayServer.get_name()!="headless":
		# The chosen limit (including 0/unlimited) is authoritative on both platforms.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED,window.get_window_id())
	if mobile or not change_mode or DisplayServer.get_name()=="headless": return
	window.mode=Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if not fullscreen:
		var usable:=DisplayServer.screen_get_usable_rect(window.current_screen)
		window.size=resolution.min(usable.size-Vector2i(32,64)).max(Vector2i(640,360))
		window.position=usable.position+(usable.size-window.size)/2
func render_size(logical: Vector2, physical: Vector2i) -> Vector2i:
	# Use physical pixels independently of the canvas scale. Only the 3D viewport
	# is downsampled; text, cards, title video and settings stay sharp.
	var factor: float=float(physical.y)/maxf(logical.y,1.0)
	if mobile: factor*=QUALITY[quality]
	elif fullscreen: factor=minf(factor,float(resolution.y)/maxf(logical.y,1.0))
	return Vector2i(logical*factor).max(Vector2i(2,2))
