extends RefCounted
const Health = preload("res://core/health_balance.gd")
const I = preload("res://core/inventory.gd")
const Stats = preload("res://core/run_statistics.gd")
const R = preload("res://core/random_streams.gd")
const Origins = preload("res://core/origin_rules.gd")
const EffectQuery = preload("res://core/effect_query.gd")
const RelicRewards = preload("res://core/relic_rewards.gd")
const Effects = preload("res://core/effect_rules.gd")
const COMBO := {"wood":{"attack":{"damage":0,"shield":1},"block":{"shield":2}},"iron":{"attack":{"damage":1},"block":{"shield":1,"counter":1}},"rope":{"attack":{"damage":0,"enemy_damage_delta":-1},"block":{"bind":true}},"plastic":{"block":{"shield":1,"extend":true}},"cloth":{"block":{"shield":0,"clean":true}}}

static func enter(ctx, enemy_id: String = "", rewards: Dictionary = {}) -> bool:
	var s: Dictionary = ctx.state
	if ctx.phase() != "story" or s.story_step != "choice": return false
	if enemy_id=="":
		enemy_id=s.node.get("monster","")
		rewards=s.node.get("rewards",{}).duplicate(true)
	if not RelicRewards.valid_rewards(ctx.catalog.table("relics"),rewards): return ctx.fail("潮汐遗物奖励配置无效")
	if s.get("mode","")=="tutorial" and not rewards.get("relics",[]).is_empty(): return ctx.fail("教程不能获得潮汐遗物")
	var enemy: Dictionary = ctx.Difficulty.enemy(ctx.catalog,s,enemy_id)
	if enemy.is_empty(): return ctx.fail("没有可迎战的敌人")
	var raft_target := biter_target(ctx) if enemy_id=="biter" else ""
	s.battle = {"id":enemy_id, "hp":int(enemy.hp), "turn":1, "ap":s.player.battle_ap, "entry_hp":s.player.hp, "poison_until":0, "fear_until":0, "shields":[],"raft_target_cell":raft_target}
	s.battle.origin_ap=1 if Origins.active(s,"zealot") else 0
	s.battle.origin_clean_used=false
	s.battle.origin_shield_turn=0
	if not rewards.is_empty(): s.battle.rewards=rewards.duplicate(true)
	s.phase = "battle"; ctx.panel = "battle"
	Stats.accept_crisis(s)
	Stats.battle_start(s)
	ctx.discover("enemy."+enemy_id)
	# Old saves could contain the repeatable punch card. It is now a free action.
	for card in s.hand.duplicate(true):
		if card.id == "punch": I.remove(s,card.uid,"cleared")
	Effects.trigger(ctx,"battle_start")
	supply(ctx)
	ctx.log_text("迎战"+enemy.name)
	return true

static func preview(ctx, args: Dictionary = {}) -> Dictionary:
	var copy = ctx.get_script().new(ctx.catalog)
	copy.state = ctx.state.duplicate(true); copy.profile = ctx.profile.duplicate(true)
	copy._effect_preview = true
	var reason: String = preload("res://core/tutorial_rules.gd").guard(copy,"play" if args.has("uid") else "battle_action",args)
	var ok := false
	if reason.is_empty(): ok = copy.Rules.play(copy,args) if args.has("uid") else action(copy,args)
	else: copy.error = reason
	var result: Dictionary={"valid":ok,"error":copy.error,"battle":copy.state.get("battle",{}).duplicate(true),"player":copy.state.get("player",{}).duplicate(true),"hand":copy.state.get("hand",[]).duplicate(true)}
	var chance: float=EffectQuery.probability(ctx.state,ctx.catalog,"enchant_preserve")
	if chance>0.0: result.enchant_preserve_chance=chance
	return result

static func action(ctx, args: Dictionary) -> bool:
	if ctx.phase() != "battle": return false
	var s: Dictionary = ctx.state
	var action_id: String = str(args.get("action", ""))
	s.battle["attack_absorbed"] = 0
	if action_id not in ["attack", "block"]: return ctx.fail("未知战斗行动")
	var payment: Dictionary=action_payment(ctx)
	if not payment.allowed: return ctx.fail("战斗AP不足")
	var resource := {}
	var resource_uid: String = str(args.get("resource_uid", ""))
	if resource_uid != "":
		resource = I.find(s,resource_uid)
		if resource.is_empty() or resource.temporary or resource.id not in COMBO or ctx.catalog.entry("cards",resource.id).get("kind","") != "resource": return ctx.fail("附魔资源必须是手中真实的基础资源")
	if resource.is_empty() and resource_uid != "": return ctx.fail("附魔资源已变化")
	var combo: Dictionary = COMBO.get(resource.get("id",""),{}).get(action_id,{})
	if not resource.is_empty() and combo.is_empty(): return ctx.fail("该材料不能用于此基础行动")
	if combo.get("bind",false) and s.battle.get("bind_used",false): return ctx.fail("本回合已用束缚效果")
	var boost := find_boost(s,str(args.get("buff_uid",""))) if args.has("buff_uid") else {}
	if args.has("buff_uid") and (boost.is_empty() or boost.id!="power" and boost.id!="barrier" or boost.id=="power" and action_id!="attack" or boost.id=="barrier" and action_id!="block" and int(combo.get("shield",0))<=0): return ctx.fail("该增益与行动类型不匹配")
	# Only a fully validated enchanted action may sample the battle stream.
	# Preview consumes material conservatively and exposes only the public chance.
	var preserve_material:=false
	var preserve_chance: float=EffectQuery.probability(s,ctx.catalog,"enchant_preserve")
	if not resource.is_empty() and preserve_chance>0.0 and not ctx._effect_preview:
		preserve_material=R.draw(s.rng,"battle")<preserve_chance
	if action_id == "attack":
		var damage: int = maxi(1,1+int(s.player.get("damage",0))+int(combo.get("damage",0))+EffectQuery.modifier(s,ctx.catalog,"battle.damage"))
		if s.battle.turn <= int(s.battle.get("fear_until",0)): damage = maxi(1,damage-1)
		if boost.get("id","") == "power": damage += int(ctx.catalog.entry("boosts","power").get("damageBonus",2))
		var effective: int = mini(int(s.battle.hp),damage)
		Stats.increment(s,"damage_dealt",effective); s.battle.hp = maxi(0,int(s.battle.hp)-damage)
		if combo.has("enemy_damage_delta"): s.battle.enemy_damage_delta=mini(int(s.battle.get("enemy_damage_delta",0)),int(combo.enemy_damage_delta))
	else:
		add_shield(s,"action",1+int(combo.get("shield",0))+EffectQuery.modifier(s,ctx.catalog,"battle.shield"),s.battle.turn, bool(combo.get("extend",false)))
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
	if not resource.is_empty() and not preserve_material: I.remove(s,resource.uid,"cost_consumed")
	pay(ctx,payment)
	ctx.log_text("执行"+("攻击" if action_id=="attack" else "格挡")+("·"+ctx.catalog.entry("cards",resource.id).name if not resource.is_empty() else ""))
	if s.battle.hp == 0: victory(ctx)
	return true

static func action_payment(ctx) -> Dictionary:
	return Origins.payment(ctx.state,1,true)

static func card_payment(ctx, card: Dictionary, definition: Dictionary) -> Dictionary:
	return Origins.payment(ctx.state,int(definition.get("cost",0)),card.get("id","") in ["spear","pollution"],card.get("id","")=="pollution")

static func pay(ctx, payment: Dictionary) -> void:
	ctx.state.battle.ap-=int(payment.ordinary_ap)
	if int(payment.origin_ap)>0: ctx.state.battle.origin_ap-=int(payment.origin_ap)
	if payment.free_clean: ctx.state.battle.origin_clean_used=true
	Stats.increment(ctx.state,"battle_ap_spent",int(payment.cost))

static func payment_text(payment: Dictionary) -> String:
	if int(payment.origin_ap)>0: return "%d战意" % int(payment.origin_ap)
	return "%d AP" % int(payment.ordinary_ap)

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
	if ctx.EnvironmentRules.active(s,"bloodMoon") and not s.node.get("boss",false): ctx.give("coin",1,false,"bloodMoon")
	var drops: int = int(rewards.get("resources",2 if s.node.get("difficulty", "") in ["hard","boss"] or s.node.get("boss",false) else 1))
	for i in range(drops):
		var drop: String = preload("res://core/tutorial_rules.gd").fixed_resource(s) if s.get("mode","")=="tutorial" else R.pick(s.rng,"rewards",I.RESOURCES)
		ctx.give(drop,1,false,"battle_reward")
	s.xp += int(rewards.get("xp",20 if s.node.get("boss",false) else 5))
	var growth: Dictionary=ctx.catalog.entry("balance","growth")
	var xp_step: int=int(growth.get("xp_per_level",5))
	while s.xp >= xp_step:
		s.xp -= xp_step; s.level += 1
		if (int(s.level)-1) % int(growth.get("hp_interval",3)) == 0: s.player.hp_max += 1
		if int(s.level)%int(growth.get("ap_interval",15))==int(growth.get("ap_remainder",5)): s.player.base_ap+=1; s.player.battle_ap+=1
		if int(s.level)%int(growth.get("ap_interval",15))==int(growth.get("capacity_remainder",10)): s.player.limit+=1
	var bonus: int=Origins.victory_bonus(s)
	for i in range(bonus): ctx.give(R.pick(s.rng,"rewards",I.RESOURCES),1,false,"origin_battle_reward")
	if s.node.get("boss",false): ctx.Campaign.record_boss(ctx)
	# End the current battle before acquiring rewards with battle-start effects.
	cleanup(ctx)
	var relic_summary: Array=[]
	if not RelicRewards.grant(ctx,rewards.get("relics",[]),relic_summary): return
	s.battle={}
	exit_battle(ctx,"战斗胜利；原战利品已领取。"+("战斗狂额外材料×%d（战后等级%d）。" % [bonus,s.level] if bonus>0 else "")+"；".join(relic_summary))

static func supply(ctx) -> void:
	var s: Dictionary=ctx.state
	if Origins.active(s,"hoarder") and int(s.battle.get("origin_shield_turn",0))!=int(s.battle.turn):
		s.battle.origin_shield_turn=int(s.battle.turn)
		if Origins.stock_count(s)>=12:
			add_shield(s,"origin_hoarder",1,int(s.battle.turn))
			ctx.log_text("囤积癖·储备充足：本回合获得1点护盾。")
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
	var payment: Dictionary=card_payment(ctx,card,definition)
	if not payment.allowed: return ctx.fail("战斗AP不足")
	pay(ctx,payment)
	Stats.card(s,card.id,"used",1,"battle",card.uid)
	if card.id=="pollution": Stats.increment(s,"pollution_cleared")
	if definition.kind == "survival":
		if not Origins.use_survival(ctx,card,definition): return false
	elif definition.kind == "combat":
		var damage: int = int(definition.damage) + s.player.damage + EffectQuery.modifier(s,ctx.catalog,"battle.damage") + (int(ctx.catalog.entry("boosts","power").get("damageBonus",2)) if not boost.is_empty() else 0)
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
	var direct_damage: int = incoming_damage(ctx)
	if s.battle.get("bound_effect",false):
		if s.battle.id == "biter": s.battle.bound_biter = true
		elif s.battle.id == "jelly": s.battle.bound_poison = true
	var counter_hit: bool=s.battle.get("counter_ready",false) and s.battle.id in ["biter","crab","crab_elite"]
	s.battle.counter_ready=false
	if s.battle.id == "biter" and not s.battle.get("bound_biter",false): damage_raft_cell(s)
	var soaked: int = absorb_shields(s,direct_damage)
	s.battle["attack_absorbed"] = soaked
	ctx.change("hp",-(direct_damage-soaked),"enemy")
	if not battle_alive(ctx): return true
	if enemy.get("buff","") != "" and not (Origins.active(s,"skeptic") and enemy.buff in ["poisoned","fearful"]) and not (s.battle.get("bound_poison",false) and s.battle.id=="jelly"):
		if enemy.buff == "poisoned": s.battle.poison_until = s.battle.turn + 3
		if enemy.buff == "fearful": s.battle.fear_until = s.battle.turn + 2
	if enemy.get("pollution",false) and int(s.battle.turn) % 2 == 1: ctx.give("pollution",1,true,"battle")
	if s.battle.turn >= int(ctx.catalog.entry("balance","combat").get("fatigue_turn",7)):
		ctx.change("hp",-int(ctx.catalog.entry("balance","combat").get("fatigue_damage",1)))
		if not battle_alive(ctx): return true
	if counter_hit:
		s.battle.hp=maxi(0,int(s.battle.hp)-1); Stats.increment(s,"damage_dealt",1)
		if s.battle.hp==0: victory(ctx); return true
	decay_shields(s)
	s.battle.turn += 1; s.battle.ap = s.player.battle_ap
	s.battle.origin_ap=1 if Origins.active(s,"zealot") else 0
	if s.has("stats"):
		var battle_id: String = s.node.get("visit_id","")+"/battle"
		if s.stats.battles.has(battle_id): s.stats.battles[battle_id].turns=s.battle.turn
	Stats.increment(s,"battle_rounds")
	supply(ctx)
	s.battle.bound_effect=false; s.battle.bound_poison=false; s.battle.bound_biter=false; s.battle.bind_used=false; s.battle.enemy_damage_delta=0
	return true

static func incoming_damage(ctx) -> int:
	var s: Dictionary=ctx.state
	var damage: int=int(ctx.Difficulty.enemy(ctx.catalog,s,s.battle.id).damage)+(1 if ctx.EnvironmentRules.active(s,"bloodMoon") else 0)
	if s.battle.get("bound_effect",false) and s.battle.id not in ["biter","jelly"]: damage=maxi(0,damage-2)
	return maxi(0,damage+int(s.battle.get("enemy_damage_delta",0)))

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
	if protected_exit(ctx):
		ctx.change("hp",int(ctx.state.battle.entry_hp)-int(ctx.state.player.hp))
		Stats.battle_result(ctx.state,"protected")
		exit_battle(ctx,"遗迹保护生效，恢复入场生命；没有奖励。")
	else:
		Stats.battle_result(ctx.state,"dead")
		cleanup(ctx)
		ctx.state.battle={}
		ctx.finish("dead")
	return false

static func retreat(ctx) -> bool:
	if ctx.phase() != "battle" or ctx.state.battle.turn < int(ctx.catalog.entry("balance","combat").get("retreat_turn",2)): return ctx.fail("第二回合起才可撤退")
	if protected_exit(ctx): ctx.change("hp",int(ctx.state.battle.entry_hp)-int(ctx.state.player.hp))
	else: ctx.change("hp",-int(ctx.catalog.entry("balance","combat").get("retreat_damage",4)),"retreat")
	if ctx.state.node.get("boss",false): ctx.state.flags.boss_withdrawn=true
	Stats.battle_result(ctx.state,"dead" if ctx.state.player.hp<=0 else "retreated")
	if ctx.state.player.hp<=0:cleanup(ctx)
	if ctx.alive():
		exit_battle(ctx,"撤退，没有战斗奖励。")
	return true

static func cleanup(ctx) -> void:
	Effects.trigger(ctx,"battle_end")
	for card in ctx.state.hand.duplicate(true):
		if card.temporary or card.id=="pollution": I.remove(ctx.state,card.uid,"cleared")

static func protected_exit(ctx) -> bool:
	return ctx.state.node.get("kind","")=="ruin" or ctx.state.get("encounter",{}).get("battle_request",{}).get("exit_rule","")=="protected"

static func exit_battle(ctx, text: String) -> void:
	if not ctx.state.battle.is_empty(): cleanup(ctx)
	ctx.state.battle = {}
	var continuation: int=int(ctx.state.get("encounter",{}).get("battle_continuation",-1))
	if continuation>=0 and continuation<ctx.state.node.get("stages",[]).size():
		ctx.state.encounter.last_battle_source={"source_stage":int(ctx.state.encounter.stage)}
		for field in ["battle_option","battle_outcome","battle_request","battle_continuation"]:
			if ctx.state.encounter.has(field):ctx.state.encounter.last_battle_source[field]=ctx.state.encounter[field].duplicate(true) if ctx.state.encounter[field] is Dictionary else ctx.state.encounter[field]
		ctx.state.encounter.stage=continuation
		for field in ["battle_option","battle_outcome","battle_request","battle_continuation"]:ctx.state.encounter.erase(field)
		ctx.state.encounter.last_result=text; ctx.state.phase="story";ctx.state.story_step="choice";ctx.panel="story";ctx.log_text(text)
	else:ctx.result_story(text)
