extends SceneTree
const Session=preload("res://core/game_session.gd")
const Query=preload("res://core/effect_query.gd")
const IDS=["sealedFishTin","emberFuse","kelpRation","copperStill","tideTablet","homeCompass","hunterSpear","rescueBadge","tideBoneBlade","glowConch","crackedCarapace","sunkenCoin","drifterMedkit","barbedBundle","redCoral","drifterQuiver","crimsonVial","scavengerSatchel","foldingRule","sailorsKnot"]
const NODES=["sealedLarder","powderWreck","kelpDryingRack","silentWayfinder","boneHunter","shellGraveyard","drownedMint","rescuePontoon","coralShrine","riggersCache"]
var failures:=0
var checks:=0
var catalog
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+why)
func fresh():
	var s=Session.new(catalog)
	s.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
	s._auto_advancing=true
	return s
func encounter(id: String):
	var s=fresh()
	# Manual arrival keeps the legal current journey/weather and departure lock.
	s.Survival.lock_costs(s)
	s.state.phase="story"; s.state.story_step="choice"
	s.state.node=catalog.entry("nodes",id); s.state.node.visit_id="expedition-test"
	s.state.candidates=[]; s.state.ap=6
	s.Encounter.arrived(s)
	return s
func test_definitions() -> void:
	var enabled: Array=catalog.table("relics").keys().filter(func(id):return catalog.entry("relics",id).get("enabled",false))
	check(enabled.size()==20,"20件图片对应20件启用遗物")
	for id in IDS:
		var d: Dictionary=catalog.entry("relics",id)
		check(d.get("enabled",false) and not d.get("story","").is_empty(),id+"可获得且有故事")
	for id in NODES:
		var d: Dictionary=catalog.entry("nodes",id)
		check(not d.is_empty(),id+"节点已接入")
		if d.is_empty(): continue
		check(d.max_visits==1 and d.min_voyage>=3,"限制遗物获取频率："+id)
		check(d.options.any(func(o):return o.id=="leave" and o.get("effects",[]).is_empty() and o.get("cost",0)==0),"可无代价离开："+id)
func test_new_effects() -> void:
	var modifiers={"emberFuse":{"battle.damage":2,"survival.hydration_cost":5},"kelpRation":{"survival.hunger_cost":-5},"copperStill":{"survival.hydration_cost":-5},"homeCompass":{"inventory.limit":1},"hunterSpear":{"battle.damage":1},"tideBoneBlade":{"battle.damage":2,"survival.hunger_cost":5},"crackedCarapace":{"battle.shield":2},"sunkenCoin":{"battle.damage":1,"battle.shield":-1},"redCoral":{"battle.shield":1},"scavengerSatchel":{"inventory.limit":3}}
	for id in modifiers:
		var s=fresh(); check(s.Collectibles.acquire(s,id),"获得效果："+id)
		for target in modifiers[id]: check(Query.modifier(s.state,catalog,target)==modifiers[id][target],id+"实际修正 "+target)
		if s.state.collectibles.items.is_empty(): continue
		check(s.dispatch("discard_collectible",{"uid":s.state.collectibles.items[0].uid}),"丢弃："+id)
		for target in modifiers[id]: check(Query.modifier(s.state,catalog,target)==0,"丢弃移除持有修正："+id)
	for id in ["tideTablet","glowConch","drifterMedkit"]:
		var s=fresh(); s.state.player.hp=1; s.state.player.sanity=1
		var cap: int=s.state.player.sanity_max
		check(s.Collectibles.acquire(s,id),"获得恢复："+id)
		if id=="tideTablet": check(s.state.player.sanity_max==cap+10 and s.state.player.sanity==21,"石碑精神上限+10/恢复20")
		elif id=="glowConch": check(s.state.player.sanity==31,"螺壳恢复精神30")
		else: check(s.state.player.hp==6,"急救包恢复生命5")
	var s=encounter("boneHunter")
	if catalog.entry("nodes","boneHunter").is_empty(): return
	check(s.Collectibles.acquire(s,"drifterQuiver"),"获得箭筒")
	if not s.state.collectibles.items.is_empty():
		check(s.dispatch("option",{"id":"blade"}),"箭筒试验进入真实战斗")
		check(s.state.hand.filter(func(c):return c.id=="arrow" and c.temporary).size()==2,"箭筒开战两张临时射箭牌")
		check(s.state.collectibles.items[0].effects.values()[0].remaining==1,"箭筒保留第二场次数")
func test_redesigned_effects() -> void:
	var s=fresh(); s.state.player.hunger=1
	var food_cap: int=s.state.player.hunger_max
	check(s.Collectibles.acquire(s,"sealedFishTin") and s.state.player.hunger_max==food_cap+10 and s.state.player.hunger==51,"鱼罐仅恢复饱食并永久增加饱食上限")
	s=fresh(); s.state.player.hp=1
	var hp_cap: int=s.state.player.hp_max
	check(s.Collectibles.acquire(s,"rescueBadge") and s.state.player.hp_max==hp_cap+1 and s.state.player.hp==3 and Query.modifier(s.state,catalog,"inventory.limit")==1,"浮标牌全新生命与容量效果")
	s=fresh(); s.state.player.hp=1; hp_cap=s.state.player.hp_max
	check(s.Collectibles.acquire(s,"crimsonVial") and s.state.player.hp_max==hp_cap+3 and s.state.player.hp==4 and Query.modifier(s.state,catalog,"survival.hydration_cost")==5,"血酿永久成长与水耗代价")
	s=fresh(); check(s.Collectibles.acquire(s,"sailorsKnot"),"获得水手结")
	check(is_equal_approx(Query.probability(s.state,catalog,"enchant_preserve"),.15) and Query.modifier(s.state,catalog,"inventory.limit")==1,"水手结15%保留与容量")
	s=fresh(); check(s.Collectibles.acquire(s,"foldingRule"),"获得折尺")
	check(Query.install_plan(s.state,catalog,{"level":1},{}).level==2 and s.state.collectibles.items[0].effects.promotion.remaining==1 and Query.modifier(s.state,catalog,"inventory.limit")==1,"折尺仅一次升阶与容量")
	for id in ["lifeboatTag","rationTin","fittersBadge","spearParcel","borrowedPulse","luckyKnot","guardian","emptyCompass"]:
		check(catalog.entry("relics",id).is_empty() and not s.Collectibles.acquire(s,id),"旧方案已从运行池移除："+id)
func test_node_transactions() -> void:
	var awarded: Array=[]
	for id in NODES:
		var definition: Dictionary=catalog.entry("nodes",id)
		if definition.is_empty(): continue
		for option in definition.options:
			var s=encounter(id)
			for material in option.get("cardCosts",{}): s.give(material,int(option.cardCosts[material]),false,"event")
			var before: Dictionary=s.snapshot()
			s.view(); s.Encounter.reward_preview(option); preload("res://core/action_query.gd").list_actions(s)
			check(s.snapshot()==before,"查看报价不改变状态："+id+"/"+option.id)
			var restored=Session.new(catalog)
			check(restored.restore(JSON.parse_string(JSON.stringify(before))),"节点领奖前可恢复："+id)
			check(s.dispatch("option",{"id":option.id}),"正常选项："+id+"/"+option.id)
			if option.has("battle"):
				check(s.state.collectibles.items.is_empty(),"尚未胜利不发奖")
				check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"奖励战斗可恢复")
				for step in range(60):
					if s.phase()!="battle": break
					check(s.dispatch("battle_action",{"action":"attack"}) if s.state.battle.ap>0 else s.dispatch("battle_end"),"正常战斗行动")
			if option.id=="leave": check(s.state.collectibles.items.is_empty(),"离开不发奖："+id)
			else:
				check(s.state.collectibles.items.size()==1,"每次只获得一件："+id+"/"+option.id)
				if s.state.collectibles.items.is_empty(): continue
				var item: Dictionary=s.state.collectibles.items[0]
				if item.id not in awarded: awarded.append(item.id)
				check("relic."+item.id in s.profile.discovered,"登记发现："+item.id)
				check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"发奖后可恢复："+item.id)
				check(restored.state.collectibles.items.size()==1,"恢复不重新发奖")
				if not option.has("battle"):
					for material in option.get("cardCosts",{}): check(s.I.count(s.state,material)==s.I.count(before.state,material)-int(option.cardCosts[material]),"实际支付材料")
					check(s.state.ap==before.state.ap-int(option.get("cost",0)),"实际支付AP")
			var after: Dictionary=s.snapshot()
			check(not s.dispatch("option",{"id":option.id}) and s.snapshot()==after,"不能重复领取："+id)
		var s=encounter(id)
		check(not s.Encounter.eligible(s,definition),"单局已访问不再入池："+id)
	check(awarded.size()==20,"节点奖励覆盖全部20张图片")
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"内容加载")
	test_definitions(); test_new_effects(); test_redesigned_effects(); test_node_transactions()
	print("RELIC EXPEDITION: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks]); quit(failures)
