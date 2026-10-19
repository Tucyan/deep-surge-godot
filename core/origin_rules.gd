extends RefCounted
## Origin eligibility is evaluated inside the GameSession transaction.
const Query=preload("res://core/effect_query.gd")
const DEFINITIONS := {
	"strong":{"name":"强壮之人","description":"生命与上限+4；每航次首张有效包扎包多恢复1生命","enabled":true},
	"fool":{"name":"愚者","description":"移动精神航耗少5；每航次首次侦察消耗4精神","enabled":true},
	"restless":{"name":"行动派","description":"基地/战斗AP上限各+1","enabled":true},
	"hoarder":{"name":"囤积癖","description":"容量+3；永久物资≤7张时每航次首次基地打捞额外+1材料；≥12张时每战斗回合开始+1本回合护盾","enabled":true},
	"zealot":{"name":"战斗狂","description":"每回合1战意；胜利额外材料1/2/3张（战后4/7级提升）；战斗候选权重+50%，连续两次未提供战斗后下次保底合法战斗","enabled":true},
	"skeptic":{"name":"无魔之人","description":"免疫敌方中毒/畏惧；每场首次清污染不耗AP","enabled":true},
	"engineer":{"name":"设备匠","description":"安装后完好设备≤4台时Ⅰ级新设备升Ⅱ级，每类一次、每局最多4次；≥5台时每航次首次制造或升级设备返1基地AP","enabled":true},
	"merchant":{"name":"海上掮客","description":"开局3贝币；每店首次购设备减1币，第二家起减2币，最低1币","enabled":true},
	"scavenger":{"name":"拾荒者 · 暂未开放","description":"暂不实现，当前不可选择","enabled":false}
}
const ENGINEER_TYPES := ["lamp","filter","planter","crossbow","shieldRack","spearRack","generator","fishingNet","crate"]

static func active(s: Dictionary, id: String) -> bool:
	return s.get("mode","")!="tutorial" and s.get("origin","")==id

static func initialize(s: Dictionary) -> void:
	s.origin_state={"heal_voyage":0,"scout_voyage":0,"upgrade_voyage":0,"tuned":[],"shops":[],"salvage_voyage":0,"battle_misses":0,"navigation_voyage":0}

static func valid(s: Dictionary) -> bool:
	if not DEFINITIONS.get(s.get("origin",""),{}).get("enabled",false): return false
	if not s.get("origin_state") is Dictionary: return false
	var o: Dictionary=s.origin_state
	if o.size()!=8: return false
	for key in ["heal_voyage","scout_voyage","upgrade_voyage","salvage_voyage","navigation_voyage"]:
		if not number(o.get(key)) or o[key]<0 or o[key]>s.voyage: return false
	var owners: Dictionary={"heal_voyage":"strong","scout_voyage":"fool","upgrade_voyage":"engineer","salvage_voyage":"hoarder","navigation_voyage":"zealot"}
	for key in owners:
		if not active(s,owners[key]) and o[key]!=0: return false
	if not number(o.get("battle_misses")) or o.battle_misses<0 or o.battle_misses>2 or o.battle_misses>o.navigation_voyage: return false
	if not active(s,"zealot") and o.battle_misses!=0: return false
	if not o.get("tuned") is Array or o.tuned.size()>4: return false
	var seen: Array=[]
	for id in o.tuned:
		if id not in ENGINEER_TYPES or id in seen: return false
		seen.append(id)
	if not active(s,"engineer") and not o.tuned.is_empty(): return false
	if not o.get("shops") is Array or o.shops.size()>s.voyage: return false
	if not active(s,"merchant") and not o.shops.is_empty(): return false
	seen=[]
	for id in o.shops:
		if not id is String or id.is_empty() or id in seen: return false
		seen.append(id)
	for card in s.get("hand",[]):
		if not card is Dictionary: return false
		if card.has("origin_progress"): return false
	if not s.get("battle",{}).is_empty():
		var b: Dictionary=s.battle
		if not number(b.get("origin_ap",0)) or b.get("origin_ap",0)<0 or b.get("origin_ap",0)>(1 if active(s,"zealot") else 0): return false
		if not b.get("origin_clean_used",false) is bool: return false
		if not number(b.get("turn")) or not number(b.get("origin_shield_turn")) or b.origin_shield_turn<0 or b.origin_shield_turn>b.turn: return false
		if not active(s,"hoarder") and b.get("origin_shield_turn",0)!=0: return false
	return true

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value))==float(value)

static func combat_ap(s: Dictionary) -> int:
	return int(s.get("battle",{}).get("origin_ap",0)) if active(s,"zealot") else 0

static func payment(s: Dictionary, cost: int, eligible: bool, pollution: bool = false) -> Dictionary:
	var free: bool=pollution and active(s,"skeptic") and not s.battle.get("origin_clean_used",false)
	var actual: int=0 if free else cost
	var special: int=mini(actual,combat_ap(s)) if eligible else 0
	return {"cost":actual,"ordinary_ap":actual-special,"origin_ap":special,"free_clean":free,"allowed":int(s.battle.get("ap",0))>=actual-special}

static func victory_bonus(s: Dictionary) -> int:
	return mini(3,1+int((int(s.level)-1)/3)) if active(s,"zealot") else 0

static func equipment_count(s: Dictionary) -> int:
	var count:=0
	for cell in s.get("cells",[]):
		if cell.get("status","")=="intact" and not cell.get("equipment",{}).is_empty(): count+=1
	return count

static func install_plan(s: Dictionary, id: String, level: int) -> Dictionary:
	# The caller has inserted the new equipment, so it counts toward the four-device limit.
	if active(s,"engineer") and level==1 and id in ENGINEER_TYPES and equipment_count(s)<=4 and s.origin_state.tuned.size()<4 and id not in s.origin_state.tuned:
		return {"level":2,"origin_tune":id}
	return {"level":level,"origin_tune":""}

static func commit_install(s: Dictionary, plan: Dictionary) -> void:
	var id: String=str(plan.get("origin_tune",""))
	if not id.is_empty() and id not in s.origin_state.tuned: s.origin_state.tuned.append(id)

static func install_level(s: Dictionary, id: String, level: int) -> int:
	var plan:=install_plan(s,id,level)
	commit_install(s,plan)
	return int(plan.level)

static func large_workshop(s: Dictionary) -> bool:
	return active(s,"engineer") and equipment_count(s)>=5

static func refund_workshop(ctx, eligible: bool, paid: int) -> void:
	var s: Dictionary=ctx.state
	if not eligible or paid<1 or int(s.origin_state.upgrade_voyage)==int(s.voyage): return
	s.origin_state.upgrade_voyage=int(s.voyage); s.ap+=1
	ctx.log_text("设备匠·规模作业：本航次首次制造或升级设备返还1基地AP。")

static func stock_count(s: Dictionary) -> int:
	var count:=0
	for card in s.get("hand",[]):
		if not card.get("temporary",true) and card.get("id","") not in ["coin","pollution"]: count+=1
	return count

static func low_stock_bonus(s: Dictionary) -> bool:
	return active(s,"hoarder") and stock_count(s)<=7 and int(s.origin_state.salvage_voyage)!=int(s.voyage)

static func battle_weight(s: Dictionary, category: String, base: int) -> int:
	return 30 if category=="battle" and active(s,"zealot") else base

static func status(s: Dictionary) -> String:
	if active(s,"hoarder"):
		var count:=stock_count(s)
		var effect: String="储备充足：回合开始获得1护盾" if count>=12 else ("搜集欲：基地打捞可额外+1材料" if low_stock_bonus(s) else ("搜集欲：本航次额外材料已领取" if count<=7 else "常态：暂无额外增益"))
		return "囤积癖 · 永久物资%d张 · %s" % [count,effect]
	if active(s,"engineer"):
		return "设备匠 · 完好设备%d台 · 精工已用%d/4 · %s" % [equipment_count(s),s.origin_state.tuned.size(),("规模作业本航次已用" if s.origin_state.upgrade_voyage==s.voyage else "规模作业可返1AP") if large_workshop(s) else "精工装配（每类限一次）"]
	if active(s,"zealot"):
		# Do not expose the streak: under fog it would reveal a hidden battle type.
		return "战斗狂 · 战斗权重+50%；连续两次未提供战斗后保底合法战斗；迷雾照常生效"
	return ""

static func use_survival(ctx, card: Dictionary, definition: Dictionary) -> bool:
	var s: Dictionary=ctx.state
	var bonus: bool=active(s,"strong") and card.id=="medkit" and s.player.hp<Query.effective_max(s,ctx.catalog,"hp") and int(s.origin_state.heal_voyage)!=int(s.voyage)
	if not ctx.Rules.effects(ctx,definition.effects): return false
	if bonus:
		s.origin_state.heal_voyage=int(s.voyage)
		ctx.change("hp",1,"origin_healing")
		ctx.log_text("强壮之人：本航次首次有效包扎多恢复1生命。")
	return true

static func scout_cost(s: Dictionary) -> int:
	return 4 if active(s,"fool") and int(s.origin_state.scout_voyage)!=int(s.voyage) else 8

static func enter_shop(s: Dictionary, visit_id: String) -> void:
	if active(s,"merchant") and visit_id not in s.origin_state.shops: s.origin_state.shops.append(visit_id)

static func shop_discount(s: Dictionary) -> int:
	if not active(s,"merchant"): return 0
	var shop: Dictionary=s.get("shop",{})
	if shop.is_empty(): return 0
	for id in shop.stock.slice(3):
		if int(shop.purchased.get(id,0))>0: return 0
	return 1 if s.origin_state.shops.size()<=1 else 2
