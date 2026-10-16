extends RefCounted
const Health = preload("res://core/health_balance.gd")
const I = preload("res://core/inventory.gd")
const Stats = preload("res://core/run_statistics.gd")
const R = preload("res://core/random_streams.gd")
const COMBO := {"wood":{"attack":{"damage":0,"shield":1},"block":{"shield":2}},"iron":{"attack":{"damage":1},"block":{"shield":1,"counter":1}},"rope":{"attack":{"damage":0,"enemy_damage_delta":-1},"block":{"bind":true}},"plastic":{"block":{"shield":1,"extend":true}},"cloth":{"block":{"shield":0,"clean":true}}}

static func enter(ctx, enemy_id: String = "", rewards: Dictionary = {}) -> bool:
	var s: Dictionary = ctx.state
	if ctx.phase() != "story" or s.story_step != "choice": return false
	if enemy_id=="": enemy_id=s.node.get("monster","")
	var enemy: Dictionary = ctx.catalog.entry("enemies",enemy_id)
	if enemy.is_empty(): return ctx.fail("没有可迎战的敌人")
	var raft_target := biter_target(ctx) if enemy_id=="biter" else ""
	s.battle = {"id":enemy_id, "hp":int(enemy.hp), "turn":1, "ap":s.player.battle_ap, "entry_hp":s.player.hp, "poison_until":0, "fear_until":0, "shields":[],"raft_target_cell":raft_target}
	if not rewards.is_empty(): s.battle.rewards=rewards.duplicate(true)
	s.phase = "battle"; ctx.panel = "battle"
	Stats.accept_crisis(s)
	Stats.battle_start(s)
	ctx.discover("enemy."+enemy_id)
	# Old saves could contain the repeatable punch card. It is now a free action.
	for card in s.hand.duplicate(true):
		if card.id == "punch": I.remove(s,card.uid,"cleared")
	supply(ctx)
	ctx.log_text("迎战"+enemy.name)
	return true

static func preview(ctx, args: Dictionary = {}) -> Dictionary:
	var copy = ctx.get_script().new(ctx.catalog)
	copy.state = ctx.state.duplicate(true); copy.profile = ctx.profile.duplicate(true)
	var ok: bool = copy.Rules.play(copy,args) if args.has("uid") else action(copy,args)
	return {"valid":ok,"error":copy.error,"battle":copy.state.get("battle",{}).duplicate(true),"player":copy.state.get("player",{}).duplicate(true),"hand":copy.state.get("hand",[]).duplicate(true)}

static func action(ctx, args: Dictionary) -> bool:
	if ctx.phase() != "battle": return false
	var s: Dictionary = ctx.state
	var action_id: String = str(args.get("action", ""))
	s.battle["attack_absorbed"] = 0
	if action_id not in ["attack", "block"]: return ctx.fail("未知战斗行动")
	if int(s.battle.get("ap",0)) < 1: return ctx.fail("战斗AP不足")
	var resource := {}
	var resource_uid: String = str(args.get("resource_uid", ""))
	if resource_uid != "":
		resource = I.find(s,resource_uid)
		if resource.is_empty() or resource.temporary or resource.id not in COMBO or ctx.catalog.entry("cards",resource.id).get("kind","") != "resource": return ctx.fail("组合资源必须是手中真实的基础资源")
	if resource.is_empty() and resource_uid != "": return ctx.fail("组合资源已变化")
	var combo: Dictionary = COMBO.get(resource.get("id",""),{}).get(action_id,{})
	if not resource.is_empty() and combo.is_empty(): return ctx.fail("该材料不能用于此基础行动")
	if combo.get("bind",false) and s.battle.get("bind_used",false): return ctx.fail("本回合已用束缚效果")
	var boost := find_boost(s,str(args.get("buff_uid",""))) if args.has("buff_uid") else {}
	if args.has("buff_uid") and (boost.is_empty() or boost.id!="power" and boost.id!="barrier" or boost.id=="power" and action_id!="attack" or boost.id=="barrier" and action_id!="block" and int(combo.get("shield",0))<=0): return ctx.fail("该增益与行动类型不匹配")
	if action_id == "attack":
		var damage: int = maxi(1,1+int(s.player.get("damage",0))+int(combo.get("damage",0)))
		if s.battle.turn <= int(s.battle.get("fear_until",0)): damage = maxi(1,damage-1)
		if boost.get("id","") == "power": damage += int(ctx.catalog.entry("boosts","power").get("damageBonus",2))
		var effective: int = mini(int(s.battle.hp),damage)
		Stats.increment(s,"damage_dealt",effective); s.battle.hp = maxi(0,int(s.battle.hp)-damage)
		if combo.has("enemy_damage_delta"): s.battle.enemy_damage_delta=mini(int(s.battle.get("enemy_damage_delta",0)),int(combo.enemy_damage_delta))
	else:
		add_shield(s,"action",1+int(combo.get("shield",0)),s.battle.turn, bool(combo.get("extend",false)))
		if boost.get("id","")=="barrier": add_shield(s,"barrier",int(ctx.catalog.entry("boosts","barrier").get("shieldBonus",2)),s.battle.turn+int(ctx.catalog.entry("boosts","barrier").get("lifetime",1)))
		if not combo.is_empty() and combo.has("bind"):
			s.battle.bound_effect = true; s.battle.bind_used=true
		if int(combo.get("counter",0)) > 0: s.battle.counter_ready = true
		if combo.get("clean",false):
			if int(s.battle.get("poison_until",0)) >= int(s.battle.turn): s.battle.poison_until = 0
			elif int(s.battle.get("bleed_until",0)) >= int(s.battle.turn): s.battle.bleed_until = 0
	if action_id=="attack" and int(combo.get("shield",0))>0:
		add_shield(s,"wood_attack",int(combo.shield),s.battle.turn)
		if boost.get("id","")=="barrier": add_shield(s,"barrier",int(ctx.catalog.entry("boosts","barrier").get("shieldBonus",2)),s.battle.turn+int(ctx.catalog.entry("boosts","barrier").get("lifetime",1)))
	if boost.get("id","") != "": consume_boost(s,boost.uid)
	if not resource.is_empty(): I.remove(s,resource.uid,"cost_consumed")
	s.battle.ap -= 1; Stats.increment(s,"battle_ap_spent",1)
	ctx.log_text("执行"+("攻击" if action_id=="attack" else "格挡")+("·"+ctx.catalog.entry("cards",resource.id).name if not resource.is_empty() else ""))
	if s.battle.hp == 0: victory(ctx)
	return true

static func add_shield(state: Dictionary, source: String, amount: int, expires_turn: int, extendable: bool = false) -> void:
	if amount <= 0: return
	if not state.battle.has("shields"): state.battle.shields = []
	state.battle.shields.append({"uid":"shield-%d" % int(state.get("next_shield_id",1)),"source":source,"amount":amount,"expires_turn":expires_turn,"extendable":extendable,"extended":false})
	state.battle.shields.sort_custom(func(a,b): return int(a.expires_turn)<int(b.expires_turn))
	state.next_shield_id = int(state.get("next_shield_id",1))+1

static func find_boost(state: Dictionary, uid: String) -> Dictionary:
	if uid == "": return {}
	for cell in state.get("cells",[]):
		if cell.get("status","")!="intact": continue
		var equipment: Dictionary = cell.get("equipment",{})
		for boost in equipment.get("boost_cards",[]):
			if boost.get("uid","") == uid: return boost.duplicate(true)
	return {}

static func consume_boost(state: Dictionary, uid: String) -> void:
	for cell in state.get("cells",[]):
		var equipment: Dictionary = cell.get("equipment",{})
		for i in range(equipment.get("boost_cards",[]).size()):
			if equipment.boost_cards[i].get("uid","") == uid: equipment.boost_cards.remove_at(i); return

static func victory(ctx) -> void:
	var s: Dictionary = ctx.state
	Stats.battle_result(s,"won")
	var rewards: Dictionary=s.battle.get("rewards",{})
	ctx.give("coin",int(rewards.get("coin",5 if s.node.get("boss",false) else (2 if s.node.get("difficulty", "") in ["hard","boss"] else 1)))); ctx.give("corpse",int(rewards.get("corpse",1)))
	var drops: int = int(rewards.get("resources",2 if s.node.get("difficulty", "") in ["hard","boss"] or s.node.get("boss",false) else 1))
	for i in range(drops): ctx.give(R.pick(s.rng,"rewards",I.RESOURCES),1,false,"battle_reward")
	s.xp += int(rewards.get("xp",20 if s.node.get("boss",false) else 5))
	while s.xp >= 5:
		s.xp -= 5; s.level += 1
		if (int(s.level)-1) % Health.LEVEL_INTERVAL == 0: s.player.hp_max += 1
		if int(s.level)%15==5: s.player.base_ap+=1; s.player.battle_ap+=1
		if int(s.level)%15==10: s.player.limit+=1
	if s.node.get("boss",false): s.boss_defeated = true
	ctx.Campaign.battle_won(ctx)
	exit_battle(ctx,"战斗胜利；奖励已领取。")

static func supply(ctx) -> void:
	if ctx.state.battle.get("id","")=="biter":
		var target: String=biter_target(ctx)
		ctx.state.battle.raft_target_cell=target
		ctx.state.battle.intent={"type":"biter_bite","target_cell":target,"cell_damage":1 if target!="" else 0}
	for cell in ctx.state.cells:
		if cell.status != "intact" or cell.equipment.is_empty(): continue
		var equipment: Dictionary = ctx.catalog.entry("equipment",cell.equipment.id)
		if equipment.has("battleOutput"):
			if equipment.get("battleStartOnly",false) and ctx.state.battle.turn!=1: continue
			ctx.give(equipment.battleOutput,1,true,"equipment",cell.equipment.id,cell.id)
			ctx.state.hand[-1].level = cell.equipment.level
			if equipment.battleOutput == "arrow": ctx.state.hand[-1].stack_limit = cell.equipment.level
		if equipment.has("battleShield"): add_shield(ctx.state,"shieldRack",int(equipment.battleShield),ctx.state.battle.turn)

static func biter_target(ctx) -> String:
	var targets: Array=[]
	for cell in ctx.Rules.outer_cells(ctx.state):
		if cell.status=="intact": targets.append(cell)
	targets.sort_custom(func(a,b): return str(a.id)<str(b.id))
	return str(targets[0].id) if not targets.is_empty() else ""

static func play(ctx, card: Dictionary, definition: Dictionary, args: Dictionary = {}) -> bool:
	var s: Dictionary = ctx.state
	var boost: Dictionary = find_boost(s,str(args.get("buff_uid",""))) if args.has("buff_uid") else {}
	if args.has("buff_uid") and (boost.is_empty() or boost.id!="power" or definition.kind!="combat"): return ctx.fail("该增益只能附加到有效攻击牌")
	if definition.kind not in ["survival","combat","negative"]: return ctx.fail("战斗中不能安装或制造")
	if int(definition.cost) > s.battle.ap: return ctx.fail("战斗AP不足")
	s.battle.ap -= int(definition.cost)
	Stats.increment(s,"battle_ap_spent",int(definition.cost))
	Stats.card(s,card.id,"used",1,"battle",card.uid)
	if card.id=="pollution": Stats.increment(s,"pollution_cleared")
	if definition.kind == "survival":
		for effect in definition.effects: ctx.change(effect.stat,int(effect.delta))
	elif definition.kind == "combat":
		var damage: int = int(definition.damage) + s.player.damage + (int(ctx.catalog.entry("boosts","power").get("damageBonus",2)) if not boost.is_empty() else 0)
		if card.id == "spear" and int(card.get("level",1))>=2: damage += 2
		if s.battle.turn <= s.battle.fear_until: damage -= 1
		var effective: int = mini(int(s.battle.hp),maxi(1,damage))
		Stats.increment(s,"damage_dealt",effective)
		s.battle.hp = maxi(0,s.battle.hp-maxi(1,damage))
	if card.id != "punch": I.remove(s,card.uid)
	if not boost.is_empty(): consume_boost(s,boost.uid)
	ctx.log_text("使用"+definition.name)
	if s.battle.hp == 0: victory(ctx)
	return true

static func end_turn(ctx) -> bool:
	if ctx.phase() != "battle": return false
	var s: Dictionary = ctx.state
	s.battle["attack_absorbed"] = 0
	for card in s.hand:
		if card.id == "pollution":
			ctx.change("hp",-Health.POLLUTION,"pollution")
			if not battle_alive(ctx): return true
	if s.battle.turn <= s.battle.poison_until:
		ctx.change("hp",-1,"poison")
		if not battle_alive(ctx): return true
	var enemy: Dictionary = ctx.catalog.entry("enemies",s.battle.id)
	var direct_damage: int = int(enemy.damage)
	if s.battle.get("bound_effect",false):
		if s.battle.id == "biter": s.battle.bound_biter = true
		elif s.battle.id == "jelly": s.battle.bound_poison = true
		else: direct_damage = maxi(0,direct_damage-2)
	direct_damage=maxi(0,direct_damage+int(s.battle.get("enemy_damage_delta",0)))
	var counter_hit: bool=s.battle.get("counter_ready",false) and s.battle.id in ["biter","crab","crab_elite"]
	s.battle.counter_ready=false
	if s.battle.id == "biter" and not s.battle.get("bound_biter",false): damage_raft_cell(s)
	var soaked: int = absorb_shields(s,direct_damage)
	s.battle["attack_absorbed"] = soaked
	ctx.change("hp",-(direct_damage-soaked),"enemy")
	if not battle_alive(ctx): return true
	if enemy.get("buff","") != "" and s.origin != "skeptic" and not (s.battle.get("bound_poison",false) and s.battle.id=="jelly"):
		if enemy.buff == "poisoned": s.battle.poison_until = s.battle.turn + 3
		if enemy.buff == "fearful": s.battle.fear_until = s.battle.turn + 2
	if enemy.get("pollution",false) and int(s.battle.turn) % 2 == 1: ctx.give("pollution",1,true,"battle")
	if s.battle.turn >= 7:
		ctx.change("hp",-Health.FATIGUE)
		if not battle_alive(ctx): return true
	if counter_hit:
		s.battle.hp=maxi(0,int(s.battle.hp)-1); Stats.increment(s,"damage_dealt",1)
		if s.battle.hp==0: victory(ctx); return true
	decay_shields(s)
	s.battle.turn += 1; s.battle.ap = s.player.battle_ap
	if s.has("stats"):
		var battle_id: String = s.node.get("visit_id","")+"/battle"
		if s.stats.battles.has(battle_id): s.stats.battles[battle_id].turns=s.battle.turn
	Stats.increment(s,"battle_rounds")
	supply(ctx)
	s.battle.bound_effect=false; s.battle.bound_poison=false; s.battle.bound_biter=false; s.battle.bind_used=false; s.battle.enemy_damage_delta=0
	return true

static func absorb_shields(state: Dictionary, damage: int) -> int:
	var remaining: int=damage; var absorbed := 0
	var shields: Array=state.battle.get("shields",[])
	shields.sort_custom(func(a,b): return int(a.expires_turn)<int(b.expires_turn))
	for shield in shields:
		var used: int=mini(remaining,int(shield.amount)); shield.amount-=used; remaining-=used; absorbed+=used
		if remaining<=0: break
	for i in range(shields.size()-1,-1,-1):
		if int(shields[i].amount)<=0: shields.remove_at(i)
	return absorbed

static func decay_shields(state: Dictionary) -> void:
	var shields: Array=state.battle.get("shields",[])
	for i in range(shields.size()-1,-1,-1):
		var shield: Dictionary=shields[i]
		if int(shield.expires_turn)<=int(state.battle.turn):
			if shield.get("extendable",false) and not shield.get("extended",false) and int(shield.amount)>0:
				shield.amount=mini(1,int(shield.amount)); shield.expires_turn=int(state.battle.turn)+1; shield.extended=true
			else: shields.remove_at(i)

static func damage_raft_cell(state: Dictionary) -> void:
	var candidates: Array=[]
	for cell in state.cells:
		if cell.status=="intact" and cell.id==state.battle.get("raft_target_cell",""): candidates.append(cell)
	if candidates.is_empty(): return
	candidates.sort_custom(func(a,b): return str(a.id)<str(b.id))
	var target: Dictionary=candidates[0]
	target.status="damaged"; target.damaged_at=int(state.voyage)

static func battle_alive(ctx) -> bool:
	if ctx.state.player.hp > 0: return true
	if ctx.state.node.kind == "ruin":
		ctx.change("hp",int(ctx.state.battle.entry_hp)-int(ctx.state.player.hp))
		Stats.battle_result(ctx.state,"protected")
		exit_battle(ctx,"遗迹保护生效，恢复入场生命；没有奖励。")
	else:
		Stats.battle_result(ctx.state,"dead")
		ctx.state.battle={}
		ctx.finish("dead")
	return false

static func retreat(ctx) -> bool:
	if ctx.Campaign.has_scene(ctx): return ctx.fail("教学战斗需要实际胜利，不能撤退")
	if ctx.phase() != "battle" or ctx.state.battle.turn < 2: return ctx.fail("第二回合起才可撤退")
	if ctx.state.node.kind == "ruin": ctx.change("hp",int(ctx.state.battle.entry_hp)-int(ctx.state.player.hp))
	else: ctx.change("hp",0 if ctx.state.origin == "zealot" else -Health.RETREAT)
	Stats.battle_result(ctx.state,"dead" if ctx.state.player.hp<=0 else "retreated")
	if ctx.alive():
		exit_battle(ctx,"撤退，没有战斗奖励。")
	return true

static func exit_battle(ctx, text: String) -> void:
	for card in ctx.state.hand.duplicate(true):
		if card.temporary or card.id=="pollution": I.remove(ctx.state,card.uid,"cleared")
	ctx.state.battle = {}
	ctx.result_story(text)
