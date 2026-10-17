extends RefCounted
## Voyage effects only. Mutating methods are called inside dispatch transactions.
const R = preload("res://core/random_streams.gd")
const I = preload("res://core/inventory.gd")
const FOG := ["fog1","fog2","fog3"]
const VISIBILITY := ["full","detailsHidden","typeOnly","unknown"]

static func initialize(s: Dictionary) -> void:
	s.environment={"rolled_voyage":0,"settled_voyage":0,"visibility":{},"revealed":[],"heading_locked":false,"guidance_voyage":0,"headwind_used_voyage":0,"last_movement":{}}

static func active(s: Dictionary, id: String) -> bool:
	for buff in s.buffs:
		if buff.id==id and int(buff.active_from)<=int(s.voyage) and int(buff.remaining)>0: return true
	return false

static func add(ctx, id: String, immediate: bool = false) -> bool:
	var definition: Dictionary=ctx.catalog.entry("environments",id)
	if definition.is_empty(): return ctx.fail("未知环境："+id)
	var s: Dictionary=ctx.state
	var start: int=int(s.voyage)+(0 if immediate else 1)
	for buff in s.buffs:
		if buff.id==id:
			if not immediate and int(buff.active_from)<=int(s.voyage): buff.pending_refresh=int(definition.duration)
			else: buff.active_from=start; buff.remaining=int(definition.duration)
			return true
	if id=="fog3" and s.buffs.any(func(b): return b.id=="confusion") or id=="confusion" and s.buffs.any(func(b): return b.id=="fog3"):
		return ctx.fail("迷雾Ⅲ与混乱不能共存")
	var replaced: Dictionary={}
	if id in FOG:
		for buff in s.buffs:
			if buff.id in FOG:
				if FOG.find(buff.id)>FOG.find(id): return true
				replaced=buff; break
	var size: int=s.buffs.size()-(0 if replaced.is_empty() else 1)
	var negatives := 0
	for buff in s.buffs:
		if buff!=replaced and ctx.catalog.entry("environments",buff.id).negative: negatives+=1
	if size>=3 or definition.negative and negatives>=2: return ctx.fail("环境数量已达上限")
	if not replaced.is_empty(): s.buffs.erase(replaced)
	s.buffs.append({"id":id,"active_from":start,"remaining":int(definition.duration),"pending_refresh":0})
	ctx.log_text("海况："+definition.name+("生效。" if immediate else "将于下一航次生效。"))
	return true

static func can_add(ctx, id: String) -> bool:
	if id in FOG and ctx.state.buffs.any(func(b): return b.id in FOG and FOG.find(b.id)>FOG.find(id)): return false
	var probe=ctx.get_script().new(ctx.catalog); probe.state=ctx.state.duplicate(true)
	return add(probe,id,true)

static func start_round(ctx) -> void:
	var s: Dictionary=ctx.state; var e: Dictionary=s.environment
	if int(e.rolled_voyage)==int(s.voyage): return
	e.rolled_voyage=int(s.voyage); e.visibility={}; e.revealed=[]; e.heading_locked=false
	if int(s.voyage)==1 or int(s.voyage)==int(s.length): return
	if s.get("mode","")=="tutorial": return
	var difficulty: Dictionary=ctx.Difficulty.profile(ctx.catalog,str(s.difficulty))
	var chance: float=float(difficulty.negative_chance)+float(difficulty.positive_chance)
	if R.draw(s.rng,"environment")>=chance: return
	var negative: bool=R.draw(s.rng,"environment")<float(difficulty.negative_chance)/chance
	var pool: Array=[]; var total := 0
	for id in ctx.catalog.table("environments"):
		var d: Dictionary=ctx.catalog.entry("environments",id)
		if d.negative==negative and int(d.weight)>0 and can_add(ctx,id): pool.append(d); total+=int(d.weight)
	if pool.is_empty(): return
	var roll: float=R.draw(s.rng,"environment")*total
	for d in pool:
		roll-=int(d.weight)
		if roll<0: add(ctx,d.id,true); return

static func end_round(ctx) -> void:
	var s: Dictionary=ctx.state; var e: Dictionary=s.environment
	if int(e.settled_voyage)==int(s.voyage): return
	e.settled_voyage=int(s.voyage)
	for buff in s.buffs.duplicate():
		if int(buff.active_from)>int(s.voyage): continue
		if buff.id!="spring": buff.remaining-=1
		if int(buff.pending_refresh)>0:
			buff.active_from=int(s.voyage)+1; buff.remaining=int(buff.pending_refresh); buff.pending_refresh=0
		elif int(buff.remaining)<=0: s.buffs.erase(buff)

static func spring_bonus(ctx) -> int:
	if not active(ctx.state,"spring"): return 0
	for buff in ctx.state.buffs.duplicate():
		if buff.id=="spring": ctx.state.buffs.erase(buff)
	ctx.log_text("漂流丰收：本次涌泉额外获得1份资源。")
	return 1

static func protected_node(ctx, node: Dictionary) -> bool:
	return bool(node.get("boss",false))

static func prepare_navigation(ctx) -> void:
	var s: Dictionary=ctx.state; var levels: Dictionary={}
	var guided: bool=int(s.environment.guidance_voyage)==int(s.voyage)
	for node in s.candidates:
		var level := "full"
		if not protected_node(ctx,node) and not guided:
			if active(s,"fog3"): level="unknown"
			elif active(s,"fog2"): level="typeOnly"
			elif active(s,"fog1") and R.draw(s.rng,"environment")<0.35: level="detailsHidden"
		levels[node.visit_id]=level
	if active(s,"fog3") and not guided:
		for node in s.candidates:
			if not node.has("monster") and node.get("category","")!="battle":
				if levels[node.visit_id]=="unknown": levels[node.visit_id]="typeOnly"
				break
	s.environment.visibility=levels

static func risk(ctx) -> float:
	var s: Dictionary=ctx.state
	if ctx.phase()!="navigation" or s.candidates.size()<2 or s.environment.heading_locked or not active(s,"confusion"): return 0.0
	if s.candidates.any(func(n): return protected_node(ctx,n)): return 0.0
	return 0.10 if int(s.environment.guidance_voyage)==int(s.voyage) else 0.25

static func navigate(ctx, command: String, args: Dictionary) -> bool:
	var s: Dictionary=ctx.state
	if ctx.phase()!="navigation": return ctx.fail("仅导航阶段可侦察或固定航向")
	if command=="fix_heading":
		if risk(ctx)<=0: return ctx.fail("当前没有偏航风险，无需支付")
		if not I.consume(s,"wood",1,"navigation"): return ctx.fail("固定航向需要木头1")
		s.environment.heading_locked=true; ctx.log_text("消耗木头1，固定本次航向。")
		return true
	var id: String=str(args.get("id",""))
	if not s.environment.visibility.has(id) or s.environment.visibility[id]=="full" or id in s.environment.revealed: return ctx.fail("此候选无需侦察或不存在")
	if int(s.player.sanity)<=8: return ctx.fail("侦察需SAN8，支付后至少保留1")
	ctx.change("sanity",-8,"scout"); s.environment.revealed.append(id)
	ctx.log_text("消耗SAN8，揭示一个候选。")
	return true

static func target(ctx, planned: Dictionary) -> Dictionary:
	var s: Dictionary=ctx.state; var actual: Dictionary=planned
	if risk(ctx)>0 and R.draw(s.rng,"movement")<risk(ctx):
		var others: Array=s.candidates.filter(func(n): return n.visit_id!=planned.visit_id)
		actual=R.pick(s.rng,"movement",others)
	s.environment.last_movement={"voyage":int(s.voyage),"planned":planned.visit_id,"actual":actual.visit_id,"outcome":"safeArrival" if planned.visit_id==actual.visit_id else "wrongDirection"}
	if planned.visit_id!=actual.visit_id: ctx.log_text("混乱导致偏航，抵达另一处候选。")
	return actual.duplicate(true)

static func craft_surcharge(s: Dictionary) -> int:
	return 1 if active(s,"headwind") and int(s.environment.headwind_used_voyage)!=int(s.voyage) else 0

static func project(ctx, view: Dictionary) -> void:
	var s: Dictionary=ctx.state
	view.environments=[]
	if ctx.phase()=="battle":
		view.battle.enemy_direct_damage=ctx.Battle.incoming_damage(ctx)
	for buff in s.buffs:
		var d: Dictionary=ctx.catalog.entry("environments",buff.id)
		d.erase("weight"); d.erase("duration")
		d.merge({"remaining":int(buff.remaining),"pending":int(buff.active_from)>int(s.voyage),"pending_refresh":int(buff.pending_refresh)},true)
		view.environments.append(d)
	view.navigation={"wrong_direction_chance":risk(ctx),"heading_locked":s.environment.heading_locked,"guided":int(s.environment.guidance_voyage)==int(s.voyage),"last_movement":s.environment.last_movement.duplicate(true)}
	view.erase("environment"); view.erase("buffs")
	if ctx.phase()!="navigation": return
	var projected: Array=view.get("candidates",[]).duplicate(true)
	view.candidates=[]
	for index in range(s.candidates.size()):
		var node: Dictionary=s.candidates[index]
		var level: String=s.environment.visibility.get(node.visit_id,"full")
		if node.visit_id in s.environment.revealed: level="full"
		var item: Dictionary=projected[index].duplicate(true) if level=="full" else {"visit_id":node.visit_id,"name":"未知海域","description":"海况遮蔽信息，可侦察后决定。"}
		if level in ["detailsHidden","typeOnly"]:
			item.kind=node.kind
			item.name=node.name if level=="detailsHidden" else "未知地点 · "+str({"supply":"补给","exchange":"交换","battle":"战斗","environment":"海况","rest":"休整","shop":"商店","ruin":"遗迹","risk":"风险"}.get(node.kind,node.kind))
		item.visibility=level
		view.candidates.append(item)

static func valid(ctx, s: Dictionary) -> bool:
	if not s.get("buffs") is Array or s.buffs.size()>3 or not s.get("environment") is Dictionary: return false
	var e: Dictionary=s.environment
	for key in ["rolled_voyage","settled_voyage","guidance_voyage","headwind_used_voyage"]:
		if not ctx.Rules.integer(e.get(key)) or e[key]<0 or e[key]>s.voyage+(1 if key=="guidance_voyage" else 0): return false
	if int(e.rolled_voyage)!=int(s.voyage) or not e.get("heading_locked") is bool or not e.get("visibility") is Dictionary or not e.get("revealed") is Array or not e.get("last_movement") is Dictionary: return false
	var seen: Array=[]; var negative := 0; var fog := 0
	for b in s.buffs:
		if not b is Dictionary or not b.get("id") is String or b.id in seen: return false
		var d: Dictionary=ctx.catalog.entry("environments",b.id)
		if d.is_empty(): return false
		for key in ["active_from","remaining","pending_refresh"]:
			if not ctx.Rules.integer(b.get(key)): return false
		if b.active_from<1 or b.active_from>s.voyage+1 or b.remaining<1 or b.remaining>d.duration or b.pending_refresh<0 or b.pending_refresh>d.duration: return false
		seen.append(b.id); negative+=1 if d.negative else 0; fog+=1 if b.id in FOG else 0
	if negative>2 or fog>1 or "fog3" in seen and "confusion" in seen: return false
	var ids: Array=[]
	for n in s.candidates:
		if not n is Dictionary: return false
		ids.append(n.get("visit_id",""))
	if s.phase=="navigation" and e.visibility.size()!=ids.size(): return false
	for id in e.visibility:
		if not id is String or e.visibility[id] not in VISIBILITY or s.phase=="navigation" and id not in ids: return false
	var revealed: Array=[]
	for id in e.revealed:
		if not id is String or not e.visibility.has(id) or id in revealed: return false
		revealed.append(id)
	if not e.last_movement.is_empty():
		var m: Dictionary=e.last_movement
		if not ctx.Rules.integer(m.get("voyage")) or m.voyage<1 or m.voyage>s.voyage or not m.get("planned") is String or not m.get("actual") is String or m.get("outcome") not in ["safeArrival","wrongDirection"]: return false
		if (m.planned==m.actual)!=(m.outcome=="safeArrival"): return false
	return true
