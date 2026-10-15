extends RefCounted
## Automatic progression consumes the same operation query as other clients.
const Query = preload("res://core/action_query.gd")
static func can_execute(ctx, command: String, args: Dictionary) -> bool:
	return Query.quote(ctx,command,args).effective
static func has_free_battle_card(ctx) -> bool:
	return Query.has_effective_action(ctx,true)
static func has_base_action(ctx) -> bool:
	return Query.has_effective_action(ctx)
static func next_command(ctx) -> String:
	if ctx.phase()=="battle" and ctx.state.battle.ap==0 and not has_free_battle_card(ctx): return "battle_end"
	if ctx.phase()=="aftermath" and not has_base_action(ctx): return "end_voyage"
	return ""
