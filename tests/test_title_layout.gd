extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr(message)

func run() -> void:
	var menu = preload("res://presentation/title_menu.gd").new()
	root.add_child(menu)
	for zoom in [1.0, 1.25]:
		menu.create({"active":false, "has_run":false, "ui_scale":zoom}, false)
		for dimensions in [Vector2(2174,665), Vector2(1666,665), Vector2(976,950), Vector2(1600,900), Vector2(1280,720), Vector2(1920,820)]:
			menu.size = dimensions
			menu._reflow()
			var fit: float = minf(dimensions.x / 1672.0, dimensions.y / 941.0)
			var artwork := Rect2((dimensions - Vector2(1672,941) * fit) * 0.5, Vector2(1672,941) * fit)
			for button in menu.buttons:
				var rect: Rect2 = button.get_global_rect()
				check(artwork.grow(1).encloses(rect), "%s %s: %s escapes artwork" % [dimensions, zoom, button.name])
			var group_center: float = (menu.buttons[0].get_global_rect().position.y + menu.buttons[-1].get_global_rect().end.y) * 0.5
			check(absf(group_center - dimensions.y * 0.5) < dimensions.y * 0.02, "%s %s: menu is not vertically centered" % [dimensions, zoom])
		menu.free()
		menu = preload("res://presentation/title_menu.gd").new()
		root.add_child(menu)
	menu.free()
	print("Title layout failures: ", failures)
	quit(1 if failures else 0)
