extends SceneTree
var failures := 0
func _init(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures += 1; printerr("FAIL: "+message)
func run():
	var app = load("res://scenes/main.tscn").instantiate(); app.persistence = false; root.add_child(app); await process_frame
	app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await process_frame
	var world = app.world_view
	check(world.raft.get_node_or_null("CampDecoration") == null,"空筏不得显示无对应状态的固定帆/货箱/盆栽")
	var saved = app.session.snapshot()
	var fixture = app.session.view().duplicate(true); fixture.cells = []
	var positions = [Vector2i(2,2),Vector2i(1,2),Vector2i(0,2),Vector2i(0,1),Vector2i(0,0),Vector2i(1,0)]
	var ids = ["lamp","filter","planter","medkit","crossbow","spearRack"]
	for i in range(ids.size()): fixture.cells.append({"id":"visual-%d" % i,"x":positions[i].x,"y":positions[i].y,"status":"intact","equipment":{"id":ids[i],"level":i%3+1,"fuel":2,"progress":1}})
	world.sync(fixture); await process_frame
	for i in range(ids.size()):
		var cell = world.cells.get_node("visual-%d" % i)
		check(cell.has_meta("cell_id") and cell.get_meta("cell_id") == fixture.cells[i].id,"格子ID映射")
		var model = cell.get_node_or_null("Equipment")
		check(model != null and model.get_meta("equipment_id","") == ids[i],"六种设备按真实ID建立模型")
		var label: Label3D=cell.get_node("StateLabel")
		check(label.no_depth_test,"筏格设备描述文字不被木板和设备遮挡")
		check(label.render_priority>0 and label.outline_render_priority>0,"文字及描边在海面透明物体之后渲染")
	fixture.cells[0].status = "damaged"; fixture.cells[1].status = "detached"; fixture.cells[2].equipment = {}
	world.sync(fixture); await process_frame
	check(world.cells.get_node_or_null("visual-1") == null,"脱落格及设备无残留模型")
	var damaged = world.cells.get_node("visual-0")
	check(damaged.get_meta("status","") == "damaged" and damaged.has_node("Damage"),"破损有几何损伤")
	if damaged.has_node("Equipment"): check(damaged.get_node("Equipment").get_meta("active",true) == false,"破损设备停用")
	check(not world.cells.get_node("visual-2").has_node("Equipment"),"设备拆除后模型消失")
	check(not world.lantern.visible,"损坏或无灯时无虚构暖灯")
	fixture.cells[0].status = "intact"; fixture.cells[0].equipment.fuel = 0
	world.sync(fixture); await process_frame
	check(not world.lantern.visible,"无燃料的灯熄灭")
	fixture.cells[0].equipment.fuel = 1; world.sync(fixture); await process_frame
	check(world.lantern.visible,"有燃料且完好的灯亮起")
	check(app.session.snapshot() == saved,"表现夹具不修改规则状态")
	# Real install/fuel/dismantle commands, after restoring the real navigation view.
	app.handle_command("voyage",{"id":app.session.state.candidates[0].visit_id})
	app.session.I.give(app.session.state,"lamp",1,false,"raft-install-test-fixture")
	var uid: String = app.session.state.hand.back().uid
	app.handle_command("install",{"uid":uid,"cell":"cell-0"}); await process_frame
	check(world.cells.get_node("cell-0").has_node("Equipment"),"真实安装命令建立模型")
	app.session.I.give(app.session.state,"wood",1,false,"raft-install-test-fixture")
	app.handle_command("fuel",{"cell":"cell-0","material":"wood"}); await process_frame
	check(world.lantern.visible,"真实添燃料命令点亮设备")
	app.session.I.give(app.session.state,"dismantle",1,false,"raft-install-test-fixture")
	app.handle_command("action_card",{"cell":"cell-0","uid":app.session.state.hand.back().uid,"material":"wood"}); await process_frame
	check(not world.cells.get_node("cell-0").has_node("Equipment") and not world.lantern.visible,"真实拆除命令清理模型与灯光")
	app.queue_free(); await process_frame
	print("RAFT STATE VISUAL: PASS" if failures == 0 else "RAFT STATE VISUAL: FAIL"); quit(failures)
