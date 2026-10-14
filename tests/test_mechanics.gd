extends SceneTree
var failures := 0
var catalog
const I = preload("res://core/inventory.gd")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func fixture(node_id: String):
	var s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":17})
	var data: Dictionary = s.snapshot()
	data.state.phase = "preparation"
	data.state.node = catalog.entry("nodes",node_id)
	data.state.node.visit_id = "fixture"
	data.state.ap = 3
	data.state.hand = []
	for id in ["wood","wood","wood","plastic","plastic","cloth","cloth","iron","rope"]: I.give(data.state,id,1,false,"test-fixture")
	data.state.coins = 10
	check(s.restore(data),"测试夹具恢复")
	s.dispatch("resume")
	return s
func _init() -> void:
	catalog = load("res://content/catalog.gd").new()
	catalog.load_catalog()
	var s = fixture("camp")
	check(I.capacity({"coins":0,"hand":[{"id":"arrow","stack_limit":2},{"id":"arrow","stack_limit":2},{"id":"arrow","stack_limit":2}]}) == 2,"二级箭组容量向上取整")
	var square := {"cells":[]}
	for y in range(3):
		for x in range(3): square.cells.append({"x":x,"y":y,"status":"intact"})
	if not s.Rules.has_method("outer_cells"):
		check(false,"筏格损伤需要外围筛选")
	else:
		check(s.Rules.outer_cells(square).size() == 8,"3×3木筏中心不能被外围损伤选中")
	check(not s.Rules.option_reason(s,{"effects":[{"type":"AddBuff","id":"current"}]}).is_empty(),"未接环境选项必须显示禁用原因")
	check(s.dispatch("craft",{"id":"filter"}),"制作滤水器")
	check(s.state.ap == 2 and I.count(s.state,"plastic") == 0,"制造付材料与AP")
	var filter_card: Dictionary = s.state.hand.filter(func(c): return c.id == "filter")[0]
	check(s.dispatch("install",{"uid":filter_card.uid,"cell":"cell-0"}),"安装到空格")
	check(s.state.ap == 1 and I.count(s.state,"filter") == 0,"安装单独付费移出手牌")
	var before: Dictionary = s.snapshot()
	check(not s.dispatch("install",{"uid":"gone","cell":"cell-0"}),"拒绝失效实例")
	check(s.snapshot() == before,"拒绝完全回滚")
	check(s.dispatch("expand",{"x":0,"y":2}),"邻接扩建")
	check(s.state.cells.size() == 5 and I.count(s.state,"wood") == 0,"扩建花两木一AP")
	var action_session = fixture("camp")
	var action_data: Dictionary = action_session.snapshot()
	action_data.state.cells[0].status = "damaged"
	I.give(action_data.state,"repair",1,false,"test-fixture")
	action_session.restore(action_data)
	var repair_card: Dictionary = action_session.state.hand.filter(func(c): return c.id == "repair")[0]
	check(action_session.dispatch("action_card",{"uid":repair_card.uid,"cell":"cell-0"}),"修补包实际修复")
	check(action_session.state.cells[0].status == "intact" and I.count(action_session.state,"repair") == 0,"修补包消费")
	var shop = fixture("trader")
	shop.dispatch("enter"); shop.dispatch("advance")
	check(shop.dispatch("shop_enter"),"商店剧情进入交互")
	check(shop.dispatch("buy",{"id":"lamp","payment":"coin"}),"贝币购买")
	check(shop.state.coins == 8 and I.count(shop.state,"lamp") == 1,"真实支付/交付")
	shop.dispatch("close")
	check(shop.phase() == "interaction" and not shop.dispatch("end_voyage"),"隐藏商店保持阻挡")
	shop.dispatch("event")
	check(shop.dispatch("shop_leave"),"离店")
	check(shop.phase() == "story" and shop.state.story_step == "result","离店回结果剧情")
	check(shop.dispatch("advance") and shop.phase() == "aftermath","剧情end进入收尾")
	var battle = fixture("battle")
	battle.dispatch("enter"); battle.dispatch("advance")
	check(battle.dispatch("fight"),"迎战")
	var punch: Dictionary = battle.state.hand.filter(func(c): return c.id == "punch")[0]
	for i in range(3): check(battle.dispatch("play",{"uid":punch.uid}),"付AP出拳")
	check(battle.state.battle.ap == 0 and battle.state.battle.hp == 3,"三次出拳付费/伤害")
	check(not battle.dispatch("play",{"uid":punch.uid}),"AP不足拒绝")
	check(battle.dispatch("battle_end"),"敌人回合")
	check(battle.state.player.hp == 38 and battle.state.battle.ap == 3,"敌伤与AP设值")
	for i in range(3): battle.dispatch("play",{"uid":punch.uid})
	check(battle.phase() == "story" and battle.state.story_step == "result","胜利返回剧情")
	check(battle.state.ap == 3 and battle.state.coins == 12,"战后基地AP不刷新/奖励一次")
	check(battle.state.hand.filter(func(c): return c.temporary).is_empty(),"清理本场牌")
	battle.dispatch("advance")
	check(battle.state.completed == 1,"剧情end才计节点")
	var rest = fixture("camp")
	rest.dispatch("enter"); rest.dispatch("advance")
	check(rest.dispatch("option",{"id":"rest"}),"原休整选项效果")
	check(rest.state.player.hunger == 80 and rest.state.ap == 3,"实际恢复不补当前AP")
	rest.dispatch("advance"); rest.dispatch("end_voyage")
	while rest.phase() == "discard": rest.dispatch("discard",{"uid":rest.state.hand[0].uid})
	check(rest.phase() == "navigation" and rest.state.voyage == 2,"轮末后才新导航")
	print("MECHANICS: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
