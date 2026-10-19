extends RefCounted
## Read-only delta of facts committed by the real command, never predicted drops.
static func capture(session) -> Dictionary:
	return {"run_id":session.state.get("run_id",""),"events":session.state.get("stats",{}).get("events",[]).size(),"relics":session.state.get("collectibles",{}).get("history",[]).size()}

static func pending(batches_to_show: Array) -> Dictionary:
	var result: Dictionary={"uids":[],"coins":0}
	for batch in batches_to_show:
		if batch.kind!="card": continue
		for item in batch.items:
			if item.id=="coin": result.coins+=int(item.get("stack_count",1))
			else: result.uids.append(item.uid)
	return result

static func apply_pending(view: Dictionary, waiting: Dictionary) -> void:
	if not view.has("hand"): return
	view.coins=maxi(0,int(view.get("coins",0))-int(waiting.get("coins",0)))
	var visible: Array=[]
	for card in view.hand:
		if card.uid in waiting.get("uids",[]): continue
		if card.id=="coin":
			if view.coins<=0: continue
			card.quantity=view.coins
		visible.append(card)
	view.hand=visible
	view.capacity=preload("res://core/inventory.gd").capacity({"hand":visible.filter(func(card):return card.id!="coin"),"coins":view.coins})

static func batches(session, cursor: Dictionary) -> Array:
	var state: Dictionary=session.state
	if cursor.get("run_id","")=="" or state.get("run_id","")!=cursor.run_id: return []
	var result: Array=[]
	var events: Array=state.get("stats",{}).get("events",[]).slice(int(cursor.events))
	var won: bool=events.any(func(event):return event.kind=="battle_result" and event.get("outcome","")=="won")
	for event in events:
		if event.kind!="card" or event.get("field","")!="obtained": continue
		var reason: String=event.get("reason","")
		var source: String=""
		if reason=="spring": source="涌泉"
		elif reason in ["salvage","origin_salvage"]: source="打捞"
		elif reason in ["reward","bloodMoon"] and won: source="战斗"
		elif reason=="event" or (reason=="reward" and event.get("command","")=="option"): source="节点事件"
		elif reason=="production": source="设备生产"
		if source.is_empty(): continue
		var matches: Array=result.filter(func(batch):return batch.source==source and batch.kind=="card")
		var batch: Dictionary
		if matches.is_empty():
			batch={"source":source,"kind":"card","items":[]}; result.append(batch)
		else: batch=matches[0]
		if event.id=="coin":
			var coins: Array=batch.items.filter(func(item):return item.id=="coin")
			if coins.is_empty():
				batch.items.append({"id":"coin","uid":"coins","stack_count":int(event.amount),"definition":session.catalog.entry("cards","coin").duplicate(true)})
			else: coins[0].stack_count+=int(event.amount)
			continue
		for i in range(int(event.get("amount",1))):
			var id: String=event.id
			batch.items.append({"id":id,"uid":event.get("uid",""),"definition":session.catalog.entry("cards",id).duplicate(true)})
	var history: Array=state.get("collectibles",{}).get("history",[])
	var relics: Array=[]
	for item in history.slice(int(cursor.relics)):
		var definition: Dictionary=session.catalog.entry("relics",item.id)
		relics.append({"id":item.id,"uid":item.uid,"name":definition.name,"description":definition.description})
	if not relics.is_empty(): result.append({"source":"潮汐遗物","kind":"collectible","items":relics})
	return result
