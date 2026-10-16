extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+why)
func run() -> void:
	var title=load("res://presentation/title_menu.gd").new()
	root.add_child(title); title.size=Vector2(1600,900)
	title.create({"active":false,"has_run":false})
	check(title.find_child("TitleLogo",true,false)!=null,"New transparent logo is visible")
	var logo=title.find_child("TitleLogo",true,false)
	var backdrop=title.find_child("TitleLogoBackdrop",true,false)
	check(backdrop!=null,"Logo has a circular backdrop")
	if backdrop!=null:
		check(backdrop.get_parent()==logo and backdrop.show_behind_parent,"Backdrop follows logo behind its artwork")
		var before: Vector2=backdrop.global_position
		logo.position+=Vector2(25,15)
		check(backdrop.global_position.is_equal_approx(before+Vector2(25,15)*title.composition.scale),"Backdrop follows logo movement")
	check(title.find_child("TitleFrame",true,false)!=null,"Supplied seamless frame is assembled")
	check(title.background.stream.resource_path.ends_with("lighthouse_loop.ogv"),"New lighthouse video is used")
	title.queue_free(); await process_frame
	print("TITLE V3: "+("PASS" if failures==0 else "FAIL")); quit(failures)
