extends RefCounted
const I = preload("res://core/inventory.gd")
const Stats = preload("res://core/run_statistics.gd")

static func enter(ctx) -> bool:
	var s: Dictionary = ctx.state
	if ctx.phase() != "story" or s.story_step != "choice" or not s.node.has("monster"): return false
	var enemy: Dictionary = ctx.catalog.entry("enemies",s.node.monster)
	s.battle = {"id":s.node.monster, "hp":int(enemy.hp), "turn":1, "ap":s.player.battle_ap, "entry_hp":s.player.hp, "poison_until":0, "fear_until":0}
	s.phase = "battle"; ctx.panel = "battle"
	Stats.battle_start(s)
	ctx.discover("enemy."+s.node.monster)
	ctx.give("punch",1,true,"battle")
	supply(ctx)
	ctx.log_text("迎战"+enemy.name)
	return true

static func supply(ctx) -> void:
	for cell in ctx.state.cells:
		if cell.status != "intact" or cell.equipment.is_empty(): continue
		var equipment: Dictionary = ctx.catalog.entry("equipment",cell.equipment.id)
		if equipment.has("battleOutput"):
			if equipment.get("battleStartOnly",false) and ctx.state.battle.turn!=1: continue
			ctx.give(equipment.battleOutput,1,true,"equipment",cell.equipment.id,cell.id)
			ctx.state.hand[-1].level = cell.equipment.level
			if equipment.battleOutput == "arrow": ctx.state.hand[-1].stack_limit = cell.equipment.level

static func play(ctx, card: Dictionary, definition: Dictionary) -> bool:
	var s: Dictionary = ctx.state
	if definition.kind not in ["survival","combat","negative"]: return ctx.fail("战斗中不能安装或制造")
	if int(definition.cost) > s.battle.ap: return ctx.fail("战斗AP不足")
	s.battle.ap -= int(definition.cost)
	Stats.increment(s,"battle_ap_spent",int(definition.cost))
	Stats.card(s,card.id,"used",1,"battle",card.uid)
	if card.id=="pollution": Stats.increment(s,"pollution_cleared")
	if definition.kind == "survival":
		for effect in definition.effects: ctx.change(effect.stat,int(effect.delta))
	elif definition.kind == "combat":
		var damage: int = int(definition.damage) + s.player.damage
		if card.id == "spear" and int(card.get("level",1))>=2: damage += 2
		if s.battle.turn <= s.battle.fear_until: damage -= 1
		var effective: int = mini(int(s.battle.hp),maxi(1,damage))
		Stats.increment(s,"damage_dealt",effective)
		s.battle.hp = maxi(0,s.battle.hp-maxi(1,damage))
	if card.id != "punch": I.remove(s,card.uid)
	ctx.log_text("使用"+definition.name)
	if s.battle.hp == 0:
		Stats.battle_result(s,"won")
		ctx.give("coin",5 if s.node.get("boss",false) else 2)
		ctx.give("corpse")
		s.xp += 20 if s.node.get("boss",false) else 5
		while s.xp >= 5:
			s.xp -= 5; s.level += 1; s.player.hp_max += 1
			if int(s.level) % 15 == 5: s.player.base_ap += 1; s.player.battle_ap += 1
			if int(s.level) % 15 == 10: s.player.limit += 1
		if s.node.get("boss",false): s.boss_defeated = true
		ctx.Campaign.battle_won(ctx)
		exit_battle(ctx,"战斗胜利；奖励已领取。")
	return true

static func end_turn(ctx) -> bool:
	if ctx.phase() != "battle": return false
	var s: Dictionary = ctx.state
	for card in s.hand:
		if card.id == "pollution":
			ctx.change("hp",-2,"pollution")
			if not battle_alive(ctx): return true
	if s.battle.turn <= s.battle.poison_until:
		ctx.change("hp",-1,"poison")
		if not battle_alive(ctx): return true
	var enemy: Dictionary = ctx.catalog.entry("enemies",s.battle.id)
	ctx.change("hp",-int(enemy.damage),"enemy")
	if not battle_alive(ctx): return true
	if enemy.get("buff","") != "" and s.origin != "skeptic":
		if enemy.buff == "poisoned": s.battle.poison_until = s.battle.turn + 3
		if enemy.buff == "fearful": s.battle.fear_until = s.battle.turn + 2
	if enemy.get("pollution",false) and int(s.battle.turn) % 2 == 1: ctx.give("pollution",1,true,"battle")
	if s.battle.turn >= 7:
		ctx.change("hp",-2)
		if not battle_alive(ctx): return true
	s.battle.turn += 1; s.battle.ap = s.player.battle_ap
	if s.has("stats"):
		var battle_id: String = s.node.get("visit_id","")+"/battle"
		if s.stats.battles.has(battle_id): s.stats.battles[battle_id].turns=s.battle.turn
	Stats.increment(s,"battle_rounds")
	supply(ctx)
	return true

static func battle_alive(ctx) -> bool:
	if ctx.state.player.hp > 0: return true
	if ctx.state.node.kind == "ruin":
		ctx.change("hp",int(ctx.state.battle.entry_hp)-int(ctx.state.player.hp))
		Stats.battle_result(ctx.state,"protected")
		exit_battle(ctx,"遗迹保护生效，恢复入场生命；没有奖励。")
	else:
		Stats.battle_result(ctx.state,"dead")
		ctx.finish("dead")
	return false

static func retreat(ctx) -> bool:
	if ctx.Campaign.has_scene(ctx): return ctx.fail("教学战斗需要实际胜利，不能撤退")
	if ctx.phase() != "battle" or ctx.state.battle.turn < 2: return ctx.fail("第二回合起才可撤退")
	if ctx.state.node.kind == "ruin": ctx.change("hp",int(ctx.state.battle.entry_hp)-int(ctx.state.player.hp))
	else: ctx.change("hp",0 if ctx.state.origin == "zealot" else -4)
	Stats.battle_result(ctx.state,"dead" if ctx.state.player.hp<=0 else "retreated")
	if ctx.alive():
		exit_battle(ctx,"撤退，没有战斗奖励。")
	return true

static func exit_battle(ctx, text: String) -> void:
	for card in ctx.state.hand.duplicate(true):
		if card.temporary or card.id=="pollution": I.remove(ctx.state,card.uid,"cleared")
	ctx.state.battle = {}
	ctx.result_story(text)
