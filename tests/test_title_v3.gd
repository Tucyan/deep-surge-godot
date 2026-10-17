extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+why)
func run() -> void:
	var title=load("res://presentation/title_menu.gd").new()
	root.add_child(title); title.size=Vector2(1600,900)
	title.create({"active":false,"has_run":false})
	check(title.find_child("TitleLogo",true,false)==null,"Video already contains logo; no duplicate overlay")
	check(title.find_child("TitleLogoBackdrop",true,false)==null,"No leftover logo backdrop")
	check(title.find_child("TitleFrame",true,false)==null,"Separate decorative frame is removed")
	check(title.background.stream.resource_path.ends_with("lighthouse_loop.ogv"),"New lighthouse video is used")
	for pixels in [Vector2(1350,900),Vector2(1600,900),Vector2(2100,900)]:
		title.size=pixels; title._reflow()
		check(title.get_rect().encloses(title.background.get_rect()),"Video stays within viewport")
		check(is_equal_approx(title.background.size.aspect(),16.0/9.0),"Video preserves supplied 16:9 aspect")
		check(title.poster.get_rect().is_equal_approx(title.background.get_rect()),"Poster matches video bounds")
	var fill=title.find_child("TitleBlackFill",true,false)
	check(fill!=null and fill.color==Color.BLACK,"Uncovered area has a black fill")
	title.queue_free(); await process_frame
	print("TITLE V3: "+("PASS" if failures==0 else "FAIL")); quit(failures)
