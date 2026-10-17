extends SceneTree
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+text)
func reject(s, name: String, args: Dictionary = {}) -> void:
	var before: Dictionary = s.snapshot()
	check(not s.dispatch(name,args),"拒绝 "+name)
	check(s.snapshot() == before,"拒绝不消耗物资/随机/剧情游标 "+name)
func _init() -> void:
	var c = load("res://content/catalog.gd").new(); c.load_catalog()
	var s = load("res://core/game_session.gd").new(c)
	s.dispatch("new",{"mode":"story","origin":"strong","seed":22})
	# Isolated service fixture; complete 15-station routes are in test_story.gd.
	var f: Dictionary = s.snapshot()
	f.state.phase = "nightHub"; f.state.environment.rolled_voyage = 6; f.state.voyage = 6; f.state.ap = 0; f.state.completed = 6
	f.state.node = c.entry("nodes","camp"); f.state.node.visit_id = "service-test-fixture"
	f.state.campaign.route = "scholar"; f.state.campaign.day_closed = 5
	f.state.campaign.quests["QUEST.L1.ANOMALOUS_CABIN"] = {"status":"active","claimed":false}
	f.state.campaign.night = {"voyage":6,"stage":"services","budget":1,"selected":"","exchanged":false,"result":""}
	f.state.hand = []; f.state.coins = 0
	s.I.give(f.state,"rope",3,false,"test-fixture")
	check(s.restore(f),"服务夹具载入")
	check(s.dispatch("accept_quest"),"自愿接委托"); reject(s,"accept_quest")
	var capacity: int = s.I.capacity(s.state)
	check(s.dispatch("submit_quest"),"付绳索2领取奖励")
	check(s.I.count(s.state,"rope") == 1 and s.I.count(s.state,"food") == 2 and s.I.count(s.state,"water") == 2 and s.I.count(s.state,"calm") == 2,"消耗和奖励由实例追踪")
	check(s.state.campaign.night.budget == 1 and s.state.ap == 0,"委托不耗主要行动也不刷新AP")
	reject(s,"submit_quest")
	check(s.I.capacity(s.state) == capacity+4,"只有一次实物奖励")
	check(s.dispatch("night_actions"),"服务后开放行动")
	reject(s,"night_action",{"id":"depth"})
	var stats: Dictionary = s.state.player.duplicate(true)
	var pool: Array = s.state.pool.duplicate()
	check(s.dispatch("night_action",{"id":"seam"}),"获得接缝线索")
	check(s.state.player.sanity == stats.sanity-5 and s.state.player.hunger == stats.hunger and s.state.player.hydration == stats.hydration and s.state.ap == 0,"调查只扣试测SAN，无额外移动食水/AP刷新")
	check(s.state.pool == pool,"调查不消耗普通池")
	reject(s,"night_action",{"id":"rest"}); reject(s,"finish_night")
	var bad: Dictionary = s.snapshot(); bad.state.campaign.night.budget = 2
	check(not s.restore(bad),"拒绝超额夜间预算存档")
	bad = s.snapshot(); bad.state.campaign.clues = ["false_depth"]
	check(not s.restore(bad),"拒绝缺前置的线索存档")
	check(s.dispatch("night_ack") and s.dispatch("finish_night"),"读完夜间结果才可结算")
	check(s.state.voyage == 7 and s.phase() == "navigation","夜间结束后仅推进一次航行")
	reject(s,"finish_night")
	# Final emergency fixture: no resources and 1HP must still have an affordable exit.
	f = s.snapshot(); f.state.voyage = 15; f.state.environment.rolled_voyage = 15; f.state.completed = 14; f.state.phase = "preparation"; f.state.ap = 3
	f.state.candidates = []; f.state.node = c.entry("story_nodes","ST.L1.F15"); f.state.node.visit_id = "emergency-test-fixture"
	f.state.hand = []; f.state.coins = 0; f.state.player.hp = 1
	f.state.player.hunger = 100; f.state.player.hydration = 100 # Isolate emergency exit from final survival damage.
	check(s.restore(f),"危机夹具载入")
	check(s.dispatch("enter") and s.dispatch("skip"),"进入最终危机，跳过仅文字")
	reject(s,"skip"); reject(s,"option",{"id":"seal"}); reject(s,"option",{"id":"tow"}); reject(s,"leave_encounter")
	check(s.dispatch("option",{"id":"release"}),"零资源生命1仍能选择撤离")
	check(s.state.player.hp == 1 and s.state.campaign.resolution.outcome == "C","没有死亡或虚假复活")
	check(s.dispatch("advance") and s.state.campaign.runtime.id == "ST.L1.EP15","结果后必须读尾声")
	check(s.dispatch("skip") and s.dispatch("option",{"id":"continue"}) and s.dispatch("advance"),"尾声必须明确完成")
	check(s.dispatch("end_voyage") and s.phase() == "chapterComplete" and s.profile.points == 0,"先收尾再停章，不发整局点数")
	# Survival settles at day end; tutorial supplies can be used before then.
	var dead = load("res://core/game_session.gd").new(c); dead.dispatch("new",{"mode":"story","origin":"strong","seed":22})
	f = dead.snapshot(); f.state.player.hp = 1; f.state.player.hunger = 0; f.state.player.hydration = 0
	check(dead.restore(f),"移动濒死夹具")
	check(dead.dispatch("voyage",{"id":dead.state.candidates[0].visit_id}) and dead.phase() == "preparation","移动不再结算饥渴扣血")
	check(dead.state.player.hp == 1 and dead.I.count(dead.state,"food") == 3,"活着到站并领取补给，结束航行前可使用")
	print("STORY EDGES: %s (委托仅一次、夜间原子操作、危机零资源出口、航末生存结算)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
