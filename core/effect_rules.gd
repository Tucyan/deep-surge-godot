extends RefCounted
const Query=preload("res://core/effect_query.gd")
const Inventory=preload("res://core/inventory.gd")
const Stats=preload("res://core/run_statistics.gd")

static func restore(ctx, stat: String, amount: int, source: String) -> int:
	var before: int=int(ctx.state.player.get(stat,0))
	var after: int=clampi(before+amount,0,Query.effective_max(ctx.state,ctx.catalog,stat))
	ctx.state.player[stat]=after
	Stats.change(ctx.state,stat,before,after,amount,source)
	return after-before

static func clamp_player(ctx) -> void:
	for stat in ["hp","hunger","hydration","sanity"]:
		if ctx.state.get("player",{}).has(stat): restore(ctx,stat,0,"collectible_expiry")

static func commit_uses(ctx, refs: Array) -> void:
	var seen: Array=[]
	for ref in refs:
		if not ref is Dictionary: continue
		var token: String=str(ref.get("source_uid",""))+":"+str(ref.get("key",""))
		if token in seen: continue
		seen.append(token)
		for row in Query.held_effects(ctx.state,ctx.catalog):
			if row.item.uid==ref.get("source_uid") and row.effect.key==ref.get("key") and row.effect.type in ["grant_card","install_level","temporary_max"]:
				row.runtime.remaining=maxi(0,int(row.runtime.get("remaining",0))-1)

static func trigger(ctx, event: String) -> void:
	if event=="battle_end":
		for item in ctx.state.get("collectibles",{}).get("items",[]):
			for runtime in item.get("effects",{}).values(): runtime.active=false
		clamp_player(ctx)
		return
	if event!="battle_start" or ctx.state.get("battle",{}).is_empty(): return
	if ctx.state.battle.get("collectible_effects_started",false): return
	ctx.state.battle.collectible_effects_started=true
	for row in Query.held_effects(ctx.state,ctx.catalog):
		var effect: Dictionary=row.effect
		if effect.get("trigger","")!=event or int(row.runtime.get("remaining",0))<=0: continue
		var benefited:=false
		match effect.type:
			"grant_card":
				Inventory.give(ctx.state,effect.id,int(effect.amount),true,"collectible:"+row.item.uid)
				benefited=int(effect.amount)>0
			"temporary_max":
				if not row.runtime.active:
					row.runtime.active=true
					restore(ctx,effect.stat,int(effect.heal),"collectible:"+row.item.uid)
					benefited=true
		if benefited: commit_uses(ctx,[{"source_uid":row.item.uid,"key":effect.key}])
