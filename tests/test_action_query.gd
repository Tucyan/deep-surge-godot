extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: "+message)
func _init() -> void:
	if not ResourceLoader.exists("res://core/action_query.gd"):
		check(false,"缺少统一操作查询"); quit(1); return
	var query = load("res://core/action_query.gd")
	var catalog = load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"加载内容")
	var s = load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	var before: Dictionary = s.snapshot()
	var actions: Array = query.list_actions(s)
	check(not actions.is_empty(),"导航有操作")
	check(query.list_actions(s)==actions and s.snapshot()==before,"重复查询稳定且不写状态/RNG/统计")
	var ids := {}
	for action in actions:
		check(not ids.has(action.action_id),"操作ID唯一"); ids[action.action_id]=true
		var copy = query.fork(s)
		check(copy.dispatch(action.command,action.args),"列出的合法操作可实际执行："+action.command)
	check(s.snapshot()==before,"副本不污染活动会话")
	var policy=load("res://presentation/raft_actions.gd").new()
	policy.refresh(s)
	s.state.hand=[]
	# A UI projection and its quotes must refer to the same captured revision.
	check(policy.quote("transmute",{"target":"wood"}).allowed,"木筏报价固定在refresh时的状态")
	s.state=before.state.duplicate(true)
	s.state.phase="aftermath"; s.state.ap=0; s.state.hand=[]; s.give("water")
	s.state.player.hydration=s.state.player.hydration_max
	var quote: Dictionary=query.quote(s,"play",{"uid":s.state.hand[0].uid})
	check(quote.allowed and not quote.effective,"满属性恢复牌合法但不阻止自动结束")
	check(not query.has_effective_action(s),"没有有效行动")
	s.state.player.hydration=0
	check(query.has_effective_action(s),"有效免费恢复保留行动")
	# Existing kinds/effects automatically support newly named content.
	catalog._tables.cards["test_water"]=catalog.entry("cards","water")
	s.state.mode="challenge"; s.state.phase="preparation"; s.state.node=catalog.entry("nodes","camp"); s.state.player.hydration=0; s.give("test_water")
	var new_uid: String=s.state.hand[-1].uid
	check(query.list_actions(s).any(func(a):return a.command=="play" and a.args.get("uid","")==new_uid),"新增现有效果卡牌无需修改查询")
	print("ACTION QUERY: %s" % ("PASS" if failures==0 else "FAIL")); quit(failures)
