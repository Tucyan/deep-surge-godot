extends SceneTree
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+why)
func _init() -> void:
	var path := "res://assets/fonts/NotoSansSC-VF.ttf"
	check(ResourceLoader.exists(path),"APK carries its own Chinese font")
	if failures > 0: quit(1); return
	var font: FontFile = load(path).duplicate()
	font.allow_system_fallback = false
	var text := "AP。AP，AP；『取走浮木捆』：行动点（AP）×2→结束…"
	for row in load("res://core/tutorial_rules.gd").TEXTS.values():
		text += row[0]+row[1]
	var missing := ""
	for character in text:
		if not font.has_char(character.unicode_at(0)) and not missing.contains(character): missing += character
	check(missing.is_empty(),"tutorial and mixed punctuation render without system fallback: "+missing)
	var W = load("res://presentation/widgets.gd")
	check(W.PORTABLE_FONT.resource_path==path,"UI uses the packaged font resource on Android")
	print("PORTABLE FONT: "+("PASS" if failures==0 else "FAIL"))
	quit(0 if failures==0 else 1)
