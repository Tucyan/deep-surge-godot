extends RefCounted
## Explicit fixture builder for tests that manually position a voyage.
## The production lifecycle must never synthesize missing history.
static func complete_before_start(ctx) -> void:
	var history: Array=ctx.state.environment.weather_history
	var recorded: Dictionary={}
	for item in history: recorded[int(item.voyage)]=item
	var layers: Array=ctx.Campaign.profile(ctx.catalog,ctx.state).layers
	var full: Array=[]
	for voyage in range(1,int(ctx.state.voyage)):
		if recorded.has(voyage): full.append(recorded[voyage]); continue
		var local: int=voyage
		for layer_id in layers:
			var length: int=int(ctx.catalog.entry("layers",layer_id).length)
			if local<=length:
				full.append({"voyage":voyage,"layer":layer_id,"local_voyage":local,"all_battles":false}); break
			local-=length
	if recorded.has(int(ctx.state.voyage)): full.append(recorded[int(ctx.state.voyage)])
	ctx.state.environment.weather_history=full
