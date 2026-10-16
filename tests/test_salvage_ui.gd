extends SceneTree
var failures := 0
var app: Control

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var catalog = load("res://content/catalog.gd").new()
	catalog.load_catalog()

	var s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new", {"mode": "challenge", "origin": "strong", "seed": 42})

	var assets = load("res://presentation/asset_catalog.gd").new()
	var parent = Control.new()
	root.add_child(parent)

	# Test in navigation phase
	var view = s.view()
	view.ui_state = {}
	var hud = load("res://pages/voyage_hud.gd").new()
	parent.add_child(hud)
	hud.setup(view, catalog, assets)

	var salvage_btn = parent.find_children("*", "Button", true, false).filter(func(b): return b.text == "打捞 · AP1")
	check(salvage_btn.size() == 1, "导航阶段存在打捞按钮")
	check(not salvage_btn[0].disabled, "有AP时打捞按钮可用")

	# Test in aftermath phase
	s.state.phase = "aftermath"
	s.state.ap = 2
	hud.queue_free()
	await process_frame

	view = s.view()
	view.ui_state = {}
	hud = load("res://pages/voyage_hud.gd").new()
	parent.add_child(hud)
	hud.setup(view, catalog, assets)

	salvage_btn = parent.find_children("*", "Button", true, false).filter(func(b): return b.text == "打捞 · AP1")
	check(salvage_btn.size() == 1, "收尾阶段存在打捞按钮")
	check(not salvage_btn[0].disabled, "收尾阶段有AP时打捞按钮可用")

	# Test disabled when AP is 0
	s.state.ap = 0
	hud.queue_free()
	await process_frame

	view = s.view()
	view.ui_state = {}
	hud = load("res://pages/voyage_hud.gd").new()
	parent.add_child(hud)
	hud.setup(view, catalog, assets)

	salvage_btn = parent.find_children("*", "Button", true, false).filter(func(b): return b.text == "打捞 · AP1")
	check(salvage_btn.size() == 1, "0 AP时打捞按钮仍可见")
	check(salvage_btn[0].disabled, "0 AP时打捞按钮处于禁用状态")

	parent.queue_free()
	await process_frame

	print("SALVAGE UI: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
