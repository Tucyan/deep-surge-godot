extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: "+message)
func has_scroll(node: Node) -> bool:
	if node is ScrollContainer: return true
	for child in node.get_children():
		if has_scroll(child): return true
	return false
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	if not ResourceLoader.exists("res://core/shop_rules.gd"):
		check(false,"正式商店规则尚未实现"); quit(1); return
	var Shop = load("res://core/shop_rules.gd")
	var catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"内容加载")
	var s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	s.state.node = {"id":"trader","kind":"shop","visit_id":"shop-test-a"}
	s.state.phase = "interaction"; s.state.shop = {}; s.state.coins = 100
	var cursor: int=s.state.rng.rewards.cursor
	check(Shop.enter(s),"首次生成货架")
	check(s.state.rng.rewards.cursor==cursor+6,"只用奖励流生成六个不同货物")
	var initial: Dictionary = s.snapshot()
	check(Shop.enter(s) and s.snapshot()==initial,"同次访问重复进入不重抽")
	var v: Dictionary = Shop.view(s)
	check(v.stock.size()==6 and v.relic_slots==3,"六种实物与三处未开放藏品位")
	check(v.stock.filter(func(row):return row.kind=="resource").size()==3,"三种资源")
	check(v.stock.filter(func(row):return row.kind=="equipment").size()==3,"三种设备")
	var ids := {}
	for row in v.stock:
		check(not ids.has(row.id),"货物各不相同"); ids[row.id]=true
		check(row.id!="spearRack","科技未解锁不出售矛架")
	check(Shop.valid_state(s,s.state),"真实货架可存档")
	check(Shop.view(s)==v and s.snapshot()==initial,"投影不修改随机或状态")
	var restored=load("res://core/game_session.gd").new(catalog)
	restored.state=initial.state.duplicate(true); restored.profile=initial.profile.duplicate(true)
	check(Shop.enter(restored) and Shop.view(restored)==v and restored.state.rng==s.state.rng,"恢复同访问货架与随机游标")
	var resource: Dictionary = v.stock.filter(func(row):return row.kind=="resource")[0]
	var another: Dictionary = v.stock.filter(func(row):return row.kind=="resource")[1]
	check(resource.price==1 and resource.remaining==2,"资源初价一币限二")
	check(Shop.buy(s,{"id":resource.id,"payment":"coin"}),"第一张资源购买")
	check(s.state.coins==99 and Shop.view(s).stock.filter(func(row):return row.id==resource.id)[0].price==2,"任一资源购买后全体资源报价翻倍")
	check(Shop.view(s).stock.filter(func(row):return row.id==another.id)[0].price==2,"资源货架共用购买阶梯")
	check(Shop.buy(s,{"id":resource.id,"payment":"coin"}) and s.state.coins==97,"第二张资源扣二币")
	check(Shop.view(s).stock.filter(func(row):return row.id==another.id)[0].price==4,"第二次资源购买后全体资源再次翻倍")
	var before: Dictionary = s.snapshot()
	check(not Shop.buy(s,{"id":resource.id,"payment":"coin"}) and s.snapshot()==before,"售罄购买不改变状态")
	var device: Dictionary = v.stock.filter(func(row):return row.kind=="equipment")[0]
	s.profile.purchases.coupon=1
	check(Shop.view(s).stock.filter(func(row):return row.id==device.id)[0].price==device.base_price-1,"优惠券按原报价减一")
	s.give("corpse",10)
	var corpse_count: int = s.I.count(s.state,"corpse")
	check(Shop.buy(s,{"id":device.id,"payment":"corpse"}),"允许尸体支付")
	check(s.I.count(s.state,"corpse")==corpse_count-ceili(float(device.base_price-1)/2.0),"尸体按优惠后币价除二向上取整")
	check(Shop.view(s).stock.filter(func(row):return row.id==device.id)[0].remaining==0,"设备限一")
	check(Shop.view(s).stock.filter(func(row):return row.id==another.id)[0].base_price==4,"设备购买不推进资源阶梯")
	check(Shop.buy(s,{"id":another.id,"payment":"coin"}),"购买不同资源使用共享第三档")
	var third: Dictionary=Shop.view(s).stock.filter(func(row):return row.kind=="resource" and row.id!=resource.id and row.id!=another.id)[0]
	check(third.base_price==8 and third.price==7 and third.corpse_price==4,"优惠券在共享八币原价后减一并换算尸体")
	corpse_count=s.I.count(s.state,"corpse")
	check(Shop.buy(s,{"id":third.id,"payment":"corpse"}) and s.I.count(s.state,"corpse")==corpse_count-4,"尸体购买资源也推进全店阶梯")
	check(Shop.view(s).stock.filter(func(row):return row.id==another.id)[0].base_price==16,"第四次资源购买后全店原价十六")
	check(Shop.buy(s,{"id":another.id}),"第五张资源购买")
	check(Shop.view(s).stock.filter(func(row):return row.id==third.id)[0].base_price==32,"第六张资源原价三十二")
	check(Shop.buy(s,{"id":third.id}),"第六张资源购买")
	check(Shop.view(s).stock.filter(func(row):return row.kind=="resource").all(func(row):return row.remaining==0),"总计六张资源售罄")
	s.give("medkit",2); s.give("corpse"); s.give("wood",1,true); s.give("pollution"); s.give("arrow")
	s.give("wood")
	var basic_uid: String=s.state.hand[-1].uid
	var basic_before: Dictionary=s.snapshot()
	check(not Shop.sell(s,{"uid":basic_uid}) and s.snapshot()==basic_before,"基础材料禁止出售且失败无副作用")
	var sellable: Array=Shop.view(s).sellable
	check(not sellable.any(func(row):return row.id in s.I.RESOURCES),"出售投影不包含五种基础材料")
	var uid: String=sellable.filter(func(row):return row.id=="medkit")[0].uid
	var corpse_row: Dictionary=sellable.filter(func(row):return row.id=="corpse")[0]
	var coins: int=s.state.coins
	var wood: int=s.I.count(s.state,"medkit")
	check(Shop.sell(s,{"uid":uid}) and s.state.coins==coins+1 and s.I.count(s.state,"medkit")==wood-1,"按UID单张出售换一币")
	check(not Shop.sell(s,{"uid":uid}),"重复出售拒绝")
	var corpse_coins: int=s.state.coins
	check(corpse_row.price==2 and Shop.sell(s,{"uid":corpse_row.uid}) and s.state.coins==corpse_coins+2,"怪物尸体可出售并获得二币")
	for card in s.state.hand:
		if card.temporary or card.id in ["pollution","arrow"]:
			before=s.snapshot()
			check(not Shop.sell(s,{"uid":card.uid}) and s.snapshot()==before,"排除临时污染战斗牌")
	before=s.snapshot()
	check(not Shop.buy(s,{"id":"guardian","payment":"coin"}) and s.snapshot()==before,"旧藏品不得冒充商品")
	s.state.node.visit_id="shop-test-b"
	check(Shop.enter(s) and s.state.shop.visit_id=="shop-test-b","新店重新生成")
	check(Shop.view(s).stock.all(func(row):return row.purchased==0),"新店独立限购重置")
	check(Shop.valid_state(s,s.state),"新店有效")
	var new_resource: Dictionary=Shop.view(s).stock.filter(func(row):return row.kind=="resource")[0]
	check(new_resource.price==1,"优惠券不降低一币起价")
	check(Shop.buy(s,{"id":new_resource.id}) and Shop.view(s).stock.filter(func(row):return row.id==new_resource.id)[0].price==1,"优惠券使第二张二币报价减一")
	s.state.coins=0
	before=s.snapshot()
	check(not Shop.buy(s,{"id":new_resource.id,"payment":"coin"}) and s.snapshot()==before,"余额不足购买无副作用")
	check(not Shop.buy(s,{"id":new_resource.id,"payment":"wood"}) and s.snapshot()==before,"非法支付无副作用")
	s.state.coins=100
	var corrupt: Dictionary=s.state.duplicate(true)
	corrupt.shop.stock[1]=corrupt.shop.stock[0]
	check(not Shop.valid_state(s,corrupt),"存档拒绝重复货架")
	corrupt=s.state.duplicate(true); corrupt.shop.purchased[corrupt.shop.stock[0]]=8
	check(not Shop.valid_state(s,corrupt),"存档拒绝越限计数")
	for nonfinite in [INF,-INF,NAN]:
		corrupt=s.state.duplicate(true); corrupt.shop.purchased[corrupt.shop.stock[0]]=nonfinite
		check(not Shop.valid_state(s,corrupt),"存档拒绝非有限数计数")
	corrupt=s.state.duplicate(true); corrupt.shop.purchased["guardian"]=1
	check(not Shop.valid_state(s,corrupt),"存档拒绝货架外计数")
	corrupt=s.state.duplicate(true)
	var prior: String=corrupt.shop.stock[3]
	corrupt.shop.stock[3]="spearRack"; corrupt.shop.purchased.erase(prior); corrupt.shop.purchased.spearRack=0
	check(not Shop.valid_state(s,corrupt) and Shop.valid_state(s,corrupt,{"tech":["spear"]}),"存档矛架按待载科技校验")
	s.state.phase="preparation"; before=s.snapshot()
	check(not Shop.buy(s,{"id":s.state.shop.stock[0]}) and not Shop.sell(s,{"uid":s.state.hand[0].uid}) and s.snapshot()==before,"商店外不能交易")
	if not ResourceLoader.exists("res://pages/shop_page.gd"):
		check(false,"正式商店UI尚未实现")
	else:
		var page=load("res://pages/shop_page.gd").new()
		root.size=Vector2i(1280,720)
		root.add_child(page)
		page.theme=load("res://presentation/widgets.gd").theme()
		page.size=Vector2(1280,720)
		var projection: Dictionary=Shop.view(s)
		page.setup({"revision":42,"coins":s.state.coins,"node":{"name":"正式商店"},"shop":projection},catalog,null)
		var commands: Array=[]
		page.command_requested.connect(func(command,args):commands.append({"command":command,"args":args}))
		before=s.snapshot()
		page.select_buy(projection.stock[0])
		await process_frame
		await process_frame
		check_dialog_bounds(page,"购买")
		check(commands.is_empty() and s.snapshot()==before,"选择商品不交易也不改变随机")
		page.cancel_selection()
		check(commands.is_empty() and s.snapshot()==before,"取消选择不发命令")
		page.switch_mode(true); page.switch_mode(false)
		check(commands.is_empty() and s.snapshot()==before,"购买出售切换不发命令不改规则")
		check(page.body.get_child(0).get_child_count()==9,"购买网格准确九个位置")
		check(not has_scroll(page),"页面无ScrollContainer")
		page.select_buy(projection.stock[0]); page.confirm_selection()
		check(commands.size()==1 and commands[0].command=="buy" and commands[0].args.revision==42,"确认才发购买与捕获revision")
		page.select_sell(projection.sellable[0])
		await process_frame
		await process_frame
		check_dialog_bounds(page,"出售")
		page.confirm_selection()
		check(commands.size()==2 and commands[1].command=="sell" and commands[1].args.uid==projection.sellable[0].uid,"确认按UID出售")
		page.free()
	await process_frame
	print("FORMAL SHOP: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]); quit(failures)

func check_dialog_bounds(page: Node, kind: String) -> void:
	var dialog: ConfirmationDialog=page.confirmation
	var screen_rect := Rect2(Vector2.ZERO,Vector2(root.size))
	check(screen_rect.encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),kind+"确认框完整在1280×720视口内")
	var dialog_rect := Rect2(Vector2.ZERO,Vector2(dialog.size))
	for button in [dialog.get_ok_button(),dialog.get_cancel_button()]:
		check(button.is_visible_in_tree() and dialog_rect.encloses(button.get_global_rect()),kind+"确认/取消按钮完整在窗口内")
