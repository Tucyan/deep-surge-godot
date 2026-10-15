extends SceneTree
var failures := 0
func check(ok: bool, why: String):
	if not ok: failures += 1; printerr(why)
func _init():
	if not ResourceLoader.exists("res://presentation/hand_layout.gd"):
		check(false,"Missing hand presentation ordering and grouping"); quit(1); return
	var layout = load("res://presentation/hand_layout.gd").new()
	var entries := [card("w1","wood"),card("i1","iron"),card("w2","wood"),card("w3","wood"),card("w4","wood"),card("f1","food","survival"),card("f2","food","survival"),card("wt","wood","resource",true)]
	var before := entries.duplicate(true)
	var groups: Array = layout.build(entries)
	check(groups.size()==5,"Only identical permanent resources merge")
	var wood: Array = groups.filter(func(c):return c.id=="wood" and not c.temporary)
	check(wood.size()==1 and wood[0].stack_count==4 and wood[0].stack_uids==["w1","w2","w3","w4"],"Stack preserves individual UIDs")
	check(groups[0].id=="food" and groups[2].id=="iron","Automatic category and ID order")
	layout.auto_sort=false; layout.stack_resources=false
	check(layout.build(entries).map(func(c):return c.uid)==entries.map(func(c):return c.uid),"Unsorted unstacked keeps acquisition order")
	layout.stack_resources=true; groups=layout.build(entries)
	layout.move_group(groups,0,2)
	check(not layout.auto_sort,"Manual reorder disables automatic sorting")
	check(layout.build(entries).map(func(c):return c.uid)==["i1","f1","w1","f2","wt"],"Dragged stack moves as one group")
	layout.stack_resources=false
	check(layout.build(entries).map(func(c):return c.uid)==["i1","f1","w1","w2","w3","w4","f2","wt"],"Unstack restores individual cards at group position")
	var reduced := entries.filter(func(c):return c.uid!="w1")
	layout.stack_resources=true
	check(layout.build(reduced).filter(func(c):return c.id=="wood" and not c.temporary).size()==3,"Four to three automatically expands remaining instances")
	for amount in range(1,5):
		var boundary: Array=[]
		for i in range(amount): boundary.append(card("b%d" % i,"wood"))
		boundary.append(card("temp","wood","resource",true))
		var built: Array=layout.build(boundary)
		check(built.size()==(2 if amount==4 else amount+1),"Only four permanent resources trigger stacking: %d" % amount)
	check(entries==before,"Presentation leaves source and rule state untouched")
	layout.path="user://hand-layout-test.cfg"; layout.save_preferences()
	var restored=load("res://presentation/hand_layout.gd").new(); restored.path=layout.path; restored.load_preferences()
	check(not restored.auto_sort and restored.stack_resources,"Preferences survive reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(layout.path))
	print("HAND LAYOUT: PASS" if failures==0 else "HAND LAYOUT: FAIL"); quit(failures)
func card(uid: String,id: String,kind: String="resource",temporary: bool=false)->Dictionary:
	return {"uid":uid,"id":id,"temporary":temporary,"definition":{"kind":kind}}
