extends SceneTree
var failures := 0
var catalog
const I = preload("res://core/inventory.gd")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: "+message)
func fixture(options: Array):
	var s=load("res://core/game_session.gd").new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	s._auto_advancing=true
	s.state.phase="story"; s.state.story_step="choice"; s.state.hand=[]
	s.state.node={"id":"fixture","kind":"supply","name":"测试事件","description":"test-fixture","options":options,"visit_id":"fixture-visit"}
	return s
func test_exchange() -> void:
	var s=fixture([{"id":"exchange","name":"交换","description":"3? 不，是1换2","operation":"exchange","cost":0}])
	s.give("cloth"); var uid: String=s.state.hand[-1].uid
	var before=s.snapshot()
	check(not s.dispatch("option",{"id":"exchange","input_uid":uid,"target":"cloth"}),"交换不能同类输入输出")
	check(s.snapshot()==before,"无效交换原子回滚")
	check(s.dispatch("option",{"id":"exchange","input_uid":uid,"target":"plastic"}),"合法定向交换")
	check(I.count(s.state,"cloth")==0 and I.count(s.state,"plastic")==2,"实际消费1张指定实例并给2张")
	check(not s.dispatch("option",{"id":"exchange","input_uid":uid,"target":"iron"}),"同访问不能重复领交易")
func test_targets() -> void:
	var s=fixture([{"id":"repair","name":"修复","description":"修格","conditions":{"target":"damaged_cell"},"effects":[{"type":"RepairCell"}]}])
	s.state.cells[0].status="damaged"; s.state.cells[0].damaged_at=1
	s.state.cells[0].equipment={"id":"filter","level":1,"progress":1,"fuel":0,"boost_cards":[],"production_bonus":0}
	var before=s.snapshot()
	check(not s.dispatch("option",{"id":"repair","cell":"cell-1"}),"不能修完好格")
	check(s.snapshot()==before,"无效目标回滚")
	check(s.dispatch("option",{"id":"repair","cell":"cell-0"}),"免费修复目标")
	check(s.state.cells[0].status=="intact" and s.state.cells[0].equipment.progress==1 and s.state.ap==3,"修复保留设备进度不花AP")
	var d=fixture([{"id":"catch","name":"接货","description":"明确格损","conditions":{"target":"empty_outer_cell","min_intact":2},"effects":[{"type":"DamageTargetCell"},{"type":"GiveCard","id":"iron","amount":3}]}])
	d.state.cells[0].equipment={"id":"lamp","level":1,"progress":0,"fuel":1}
	before=d.snapshot()
	check(not d.dispatch("option",{"id":"catch","cell":"cell-0"}),"不能用有设备格支付格损")
	check(d.snapshot()==before,"格损失败不发奖励")
	check(d.dispatch("option",{"id":"catch","cell":"cell-1"}),"明确空格变破损")
	check(d.state.cells[1].status=="damaged" and d.state.cells[0].status=="intact" and I.count(d.state,"iron")==3,"只伤指定格并发一次奖")
func test_ap_and_conditions() -> void:
	var s=fixture([{"id":"work","name":"强行扳开","description":"生命换本轮AP","statCosts":{"hp":2},"effects":[{"type":"ChangeAP","delta":3}]}])
	check(s.dispatch("option",{"id":"work"}) and s.state.ap==6 and s.state.player.hp==14,"本轮AP可超过上限但真实支付生命")
	check(s.state.player.base_ap==3,"不改永久AP上限")
	var low=fixture([{"id":"work","name":"扳开","description":"生命支付","statCosts":{"hp":2},"effects":[{"type":"ChangeAP","delta":3}]}])
	low.state.player.hp=2
	check(not low.dispatch("option",{"id":"work"}),"主动生命支付至少保留1")
	var net=fixture([{"id":"net","name":"用网","description":"设备条件","conditions":{"equipment":"fishingNet"},"effects":[{"type":"GiveCard","id":"wood","amount":3}]}])
	check(not net.dispatch("option",{"id":"net"}),"缺设备不能用条件分支")
	net.state.cells[0].equipment={"id":"fishingNet","level":1,"progress":0,"fuel":0}
	check(net.dispatch("option",{"id":"net"}) and I.count(net.state,"wood")==3,"完好设备解锁且不被消耗")
func test_stages() -> void:
	var take={"id":"take","name":"拿袋","description":"首袋免费","effects":[{"type":"GiveRandomResource","amount":1}],"next_stage":1}
	var more={"id":"more","name":"继续","description":"多拿三份","cost":1,"outcomes":[{"weight":1,"effects":[{"type":"GiveRandomResource","amount":3}],"next_stage":2}]}
	var leave={"id":"leave","name":"收手","description":"保留奖励"}
	var s=fixture([take]); s.state.node.stages=[[take],[more,leave],[leave]]
	check(s.dispatch("option",{"id":"take"}),"领取分段首袋")
	check(s.phase()=="story" and s.state.story_step=="choice" and s.state.get("encounter",{}).get("stage",0)==1,"首袋后仍为当前事件选择")
	check(s.state.hand.size()==1 and s.state.ap==3,"首袋不花AP只发1张")
	var before=s.snapshot()
	check(not s.dispatch("option",{"id":"take"}) and s.snapshot()==before,"旧阶段不能重领")
	check(s.dispatch("option",{"id":"more"}),"继续付AP推进")
	check(s.state.hand.size()==4 and s.state.ap==2,"只消费一次AP并领取本段结果")
	check(s.dispatch("option",{"id":"leave"}) and s.state.story_step=="result","收手进入结果")
	check(s.state.hand.size()==4 and s.state.completed==0,"离开保留奖励，确认结果才算节点")
func test_choices_do_not_roll() -> void:
	var s=fixture([{"id":"pick","name":"随机","description":"随机1","effects":[{"type":"GiveRandomResource","amount":1}]}])
	var before=s.snapshot()
	var query=load("res://core/action_query.gd")
	query.list_actions(s); s.view(); s.view()
	check(s.snapshot()==before,"查询选项和查看不推进活动随机或状态")
	check(s.dispatch("option",{"id":"pick"}) and s.state.hand.size()==1,"随机基础资源效果真实执行")
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"内容加载")
	test_exchange(); test_targets(); test_ap_and_conditions(); test_stages(); test_choices_do_not_roll()
	print("NODE REDESIGN: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
	quit(0 if failures==0 else 1)
