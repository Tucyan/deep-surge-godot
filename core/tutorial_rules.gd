extends RefCounted
## The tutorial is a special fixed run: one scripted destination per voyage, no
## random rewards, no random weather and a single legal operation at every step.
## It reuses the normal rules and UI so what the player learns is the real game.
const LENGTH := 3
const SEED := 1
const ORIGIN := "strong"
const STARTING := ["wood","wood","plastic","plastic","rope","rope","iron","cloth"]
const NODES := ["drift","battle","trader"]
## Every operation that mutates a run. Interface-only commands (panel, close,
## camera, home) stay available so the player can look around while learning.
const MUTATING := ["voyage","scout","fix_heading","enter","advance","skip","option","shop_enter","shop_leave","buy","sell","fight","leave_encounter","play","battle_action","claim_boost","boost_device","battle_end","retreat","craft","salvage","transmute","install","fuel","repair_cell","heal","expand","upgrade","action_card","dismantle","end_voyage","discard","new","meta_buy","tech"]
const ORDER := ["starting_cards","nav1","salvage1","craft1","install1","enter1","read1","choose1","finish1","end1","discard1","survival2","nav2","enter2","read2","fight2","attack2a","enchant_attack2","enchant_block2","endturn2","attack2b","finish2","end2","discard2","survival3","nav3","repair3","enter3","read3","shop3","buy3","sell3","leave3","finish3","end3","done"]
const TOTAL_STEPS := 35 # ORDER entries except terminal done.

static func start_args() -> Dictionary:
	return {"difficulty":"tutorial","mode":"challenge","origin":ORIGIN,"seed":SEED,"starting_resources":STARTING.duplicate()}

static func new_state() -> Dictionary:
	return {"supply_voyage":0,"used_water_voyage":0,"used_food_voyage":0,"granted":{}}

static func hand_count(s: Dictionary, id: String) -> int:
	var total := 0
	for card in s.get("hand",[]):
		if card.get("id","") == id and not card.get("temporary",false): total += 1
	return total

static func hand_uid(s: Dictionary, id: String) -> String:
	for card in s.get("hand",[]):
		if card.get("id","") == id: return str(card.get("uid",""))
	return ""

static func installed(s: Dictionary, id: String) -> bool:
	for cell in s.get("cells",[]):
		if cell.get("status","") == "intact" and cell.get("equipment",{}).get("id","") == id: return true
	return false

static func damaged_cells(s: Dictionary) -> Array:
	var result: Array = []
	for cell in s.get("cells",[]):
		if cell.get("status","") == "damaged": result.append(str(cell.get("id","")))
	return result

static func saved(s: Dictionary, key: String) -> int:
	return int(s.get("tutorial",{}).get(key,0))

static func used_survival(s: Dictionary) -> bool:
	return saved(s,"used_water_voyage") == int(s.get("voyage",0)) and saved(s,"used_food_voyage") == int(s.get("voyage",0))

static func active(s: Dictionary) -> bool:
	return not s.is_empty() and s.get("mode","") == "tutorial" and s.get("phase","") not in ["finished","chapterComplete"]

## Derived steps keep saves small and make a restored tutorial continue exactly
## where the state says it is, without trusting a separately stored index.
static func current_step(s: Dictionary) -> String:
	if s.is_empty() or s.get("mode","") != "tutorial": return ""
	if s.get("phase","") in ["finished","chapterComplete"]: return "done"
	match int(s.get("voyage",1)):
		1: return step_one(s)
		2: return step_two(s)
		3: return step_three(s)
	return "done"

static func step_one(s: Dictionary) -> String:
	match str(s.get("phase","")):
		"navigation": return "nav1"
		"preparation":
			if int(s.get("stats",{}).get("counters",{}).get("salvages",0)) < 2: return "salvage1"
			if installed(s,"filter"): return "enter1"
			if hand_count(s,"filter") > 0: return "install1"
			return "craft1"
		"story":
			match str(s.get("story_step","")):
				"intro": return "read1"
				"choice": return "choose1"
				"result": return "finish1"
		"aftermath": return "end1"
		"discard": return "discard1"
	return ""

static func step_two(s: Dictionary) -> String:
	match str(s.get("phase","")):
		"navigation": return "nav2" if used_survival(s) else "survival2"
		"preparation": return "enter2"
		"story":
			match str(s.get("story_step","")):
				"intro": return "read2"
				"choice": return "fight2"
				"result": return "finish2"
		"battle":
			var battle: Dictionary = s.get("battle",{})
			if int(battle.get("turn",1)) >= 2: return "attack2b"
			if int(battle.get("ap",0)) == int(s.get("player",{}).get("battle_ap",3)): return "attack2a"
			if not s.get("tutorial",{}).get("enchant_attack_done",false): return "enchant_attack2"
			if not s.get("tutorial",{}).get("enchant_block_done",false): return "enchant_block2"
			return "endturn2"
		"aftermath": return "end2"
		"discard": return "discard2"
	return ""

static func step_three(s: Dictionary) -> String:
	match str(s.get("phase","")):
		"navigation": return "nav3" if used_survival(s) else "survival3"
		"preparation": return "repair3" if not damaged_cells(s).is_empty() else "enter3"
		"story":
			match str(s.get("story_step","")):
				"intro": return "read3"
				"choice": return "shop3"
				"result": return "finish3"
		"interaction":
			var shop: Dictionary = s.get("shop",{})
			var bought := 0
			for id in shop.get("purchased",{}): bought += int(shop.purchased[id])
			if bought == 0: return "buy3"
			return "leave3" if s.get("tutorial",{}).get("sale_done",false) else "sell3"
		"aftermath": return "end3"
	return ""

const TEXTS := {
	"starting_cards":["选择初始卡牌","点击资源旁的『＋ / −』选择木头2、塑料2、绳索2、废铁1、布条1，共8张。选齐后点『开始航行』。"],
	"nav1":["选择目的地","在右侧选择『漂浮物带』，再点出现的『出发』。出发时一次性消耗 SAN15、饱食30和水分30，并立即结算饥渴伤害。"],
	"salvage1":["打捞补给","点右下角『打捞 · AP1』。打捞消耗 1 点基地 AP，获得 1 张基础资源。需要打捞两次。"],
	"craft1":["制作设备","点右下角『合成/转化』，选择『制造滤水器』。它会消耗塑料2、木头1和 1 点 AP。"],
	"install1":["安装设备","双击手牌中的『滤水器』，把它安装到空筏格。安装不消耗 AP，1级滤水器每经过2个后续航行轮生产1张淡水；筏格破损时暂停生产，修补后恢复。"],
	"enter1":["进入节点","点右侧『进入节点』，阅读这次海上遭遇。"],
	"read1":["阅读事件","读完事件说明后点『继续』。"],
	"choose1":["做出选择","选择『取走浮木捆』：第一次点击预选，再点一次确认。免费获得木头2，不消耗 AP。"],
	"finish1":["完成节点","点『结束节点』，再点『结束航行』。手牌超限时先弃到容量达标；食水已在出发时扣除，轮末不再扣除。"],
	"end1":["结束航行","点『结束航行』。轮末处理老化与临时增益到期，再检查手牌容量；超限时先弃牌，食水不再扣除。"],
	"discard1":["轮末弃牌","手牌超过上限了。点任意一张手牌弃置，直到容量回到上限以内，再进入下一轮。食水已在出发时结算，弃牌不会再次扣除。"],
	"survival2":["使用生存牌","本轮先使用『淡水』和『食用植物』：它们不消耗 AP，分别恢复水分和饱食各40，上限以外的恢复量不保留。然后前往『捕食者水域』。"],
	"nav2":["前往战斗","右侧目的地是『捕食者水域』。点选它，再点『出发』。"],
	"enter2":["进入战斗节点","点右侧『进入节点』，看看水下有什么。"],
	"read2":["准备迎战","读完说明后点『继续』，然后选择『迎战』。"],
	"fight2":["迎战","点『迎战』进入战斗。战斗 AP 与基地 AP 分开计算，每回合刷新；战斗和航行共用手牌。"],
	"attack2a":["第一次攻击","双击手牌『矛击』：消耗 1 战斗 AP，造成 3 点伤害。用后该牌移除。敌人有 6 点生命。"],
	"enchant_attack2":["攻击附魔","资源牌可以对操作牌进行附魔，暂时仅支持战斗中的攻击和防御。先单击『废铁』，再双击『攻击』操作牌打出攻击附魔：消耗废铁1和1战斗AP，本次伤害从1提高到2。选择和预览不会消耗，打出后资源移除。"],
	"enchant_block2":["防御附魔","先单击『木头』，再双击『防御』操作牌打出防御附魔：消耗木头1和1战斗AP，本次护盾从1提高到3。不同资源的附魔效果不同，打出前可查看预览。"],
	"endturn2":["结束回合","点『跳过当前回合』。护盾抵挡敌人本次1点生命伤害，但不会阻止啃咬筏格；敌人仍会咬坏一只外围筏格，破损格上的设备会停用。"],
	"attack2b":["第二次攻击","第二回合战斗 AP 已刷新。再次双击『矛击』击败敌人，领取贝币、尸体和材料；留好贝币，随后学习交易。"],
	"finish2":["完成战斗节点","点『结束节点』，再点『结束航行』。本轮手牌会超限，需要在轮末弃牌。"],
	"end2":["结束航行","点『结束航行』。战斗奖励与涌泉让手牌超限，轮末需要弃到上限。"],
	"discard2":["弃牌回到上限","点手牌弃置，直到容量不高于上限。保留贝币用于购买、尸体用于出售教学；选择其他可弃手牌，弃牌不会返还。"],
	"survival3":["补充状态","先使用『淡水』和『食用植物』：0 AP，分别恢复水分和饱食各40，不超过上限。然后前往『海怪商人』。"],
	"nav3":["前往商店","右侧目的地是『海怪商人』。点选它，再点『出发』。"],
	"repair3":["修补筏格","上一场战斗咬坏了筏格。点击场景中破损的筏格（或右侧木筏详情），选择『修理』：消耗木头1或绳索2，以及1 AP。"],
	"enter3":["进入商店","修补完成后，点右侧『进入节点』。"],
	"read3":["商店说明","读完说明后点『继续』。"],
	"shop3":["进入商店","点『进入商店』查看货架。购买支付贝币；尸体可以出售换取贝币。买卖都不消耗 AP。"],
	"buy3":["购买物资","购买 1 张『木头』，支付 1 贝币。购买会立即把卡牌放进手牌。"],
	"sell3":["出售手牌","点『出售手牌』，选择『尸体』，再点『确认出售』。出售1张尸体获得3贝币，不消耗AP；基础材料不能出售。"],
	"leave3":["离开商店","点『离开商店』保留剩余货币，继续航行。"],
	"finish3":["完成商店节点","点『结束节点』，再点『结束航行』。"],
	"end3":["完成教程","点『结束航行』。整理手牌后，新手教程就完成了；之后可以从难度选择开始正式航程。"],
	"done":["教程完成","你已经走完一次完整航行。返回首页即可选择已解锁的难度开始正式航程。"]
}

static func hint(s: Dictionary) -> Dictionary:
	var id := current_step(s)
	if id == "" or not TEXTS.has(id): return {}
	var row: Array = TEXTS[id]
	var step_id := id
	var detail := ""
	if step_id == "salvage1":
		detail = "已完成 %d/2 次打捞。" % int(s.get("stats",{}).get("counters",{}).get("salvages",0))
	return {"id":step_id,"index":maxi(1,step_index(step_id)),"total":TOTAL_STEPS,"title":str(row[0]),"text":str(row[1]),"detail":detail,"operation":operation_for(step_id)}



static func step_index(id: String) -> int:
	return mini(ORDER.find(id)+1,TOTAL_STEPS)

## The HUD uses this to dim every entry that is not part of the current lesson.
static func operation_for(id: String) -> String:
	match id:
		"nav1","nav2","nav3": return "voyage"
		"salvage1": return "salvage"
		"craft1": return "craft"
		"install1": return "install"
		"survival2","survival3": return "play"
		"attack2a","attack2b": return "play"
		"enchant_attack2","enchant_block2": return "battle_action"
		"repair3": return "repair"
		"buy3": return "buy"
		"sell3": return "sell"
		"leave3": return "leave"
		"discard1","discard2": return "discard"
		"end1","end2","end3": return "end_voyage"
		"enter1","enter2","enter3": return "enter"
		"shop3": return "shop"
		_: return "guide"

static func tutorial_operation(s: Dictionary) -> String:
	if not active(s): return ""
	return operation_for(current_step(s))

static func tutorial_reason(s: Dictionary) -> String:
	var row := hint(s)
	return str(row.get("text","")) if not row.is_empty() else ""

## Called before a command is applied. Returns a non-empty reason to reject it.
static func guard(ctx, command: String, args: Dictionary) -> String:
	var s: Dictionary = ctx.state
	if s.is_empty() or s.get("mode","") != "tutorial": return ""
	if command not in MUTATING: return ""
	var step := current_step(s)
	if step == "" or step == "done": return ""
	if command == "discard" and str(args.get("uid","")) == "coins":
		return "新手教程：请保留贝币用于接下来的交易，选择其他可弃手牌。"
	if command == "discard" and step == "discard2" and str(args.get("uid","")) == hand_uid(s,"corpse"):
		return "新手教程：请保留尸体用于接下来的出售教学，选择其他可弃手牌。"
	if _allowed(s,step,command,args):
		if command == "play": _note_play(s,args)
		return ""
	return "新手教程：请先完成当前提示——" + str(hint(s).get("text",""))

static func _note_play(s: Dictionary, args: Dictionary) -> void:
	if not s.get("tutorial") is Dictionary: s.tutorial = new_state()
	var uid := str(args.get("uid",""))
	for card in s.get("hand",[]):
		if str(card.get("uid","")) != uid: continue
		if card.get("id","") == "water": s.tutorial.used_water_voyage = int(s.voyage)
		if card.get("id","") == "food": s.tutorial.used_food_voyage = int(s.voyage)
		return

static func _allowed(s: Dictionary, step: String, command: String, args: Dictionary) -> bool:
	match step:
		"nav1","nav2","nav3":
			return command == "voyage" and _is_scripted_destination(s,args)
		"salvage1":
			return command == "salvage"
		"craft1":
			return command == "craft" and str(args.get("id","")) == "filter"
		"install1":
			return command == "install" and _installs_filter(s,args)
		"enter1","enter2","enter3":
			return command == "enter"
		"read1","read2","read3":
			return command in ["advance","skip"]
		"choose1":
			return command == "option" and str(args.get("id","")) == "wood"
		"finish1","finish2","finish3":
			return command in ["advance","end_voyage"]
		"discard1","discard2":
			return command == "discard" and str(args.get("uid","")) != "coins"
		"survival2","survival3":
			return command == "play" and _plays_survival(s,args)
		"fight2":
			return command == "fight"
		"attack2a","attack2b":
			return command == "play" and _plays_spear(s,args)
		"enchant_attack2","enchant_block2":
			var resource := "iron" if step == "enchant_attack2" else "wood"
			var action := "attack" if step == "enchant_attack2" else "block"
			return command == "battle_action" and args.get("action","") == action and _card_is(s,str(args.get("resource_uid","")),resource) and not args.has("buff_uid")
		"endturn2":
			return command == "battle_end"
		"repair3":
			return command == "repair_cell"
		"shop3":
			return command == "shop_enter"
		"buy3":
			return command == "buy" and str(args.get("id","")) == "wood"
		"sell3":
			return command == "sell" and _card_is(s,str(args.get("uid","")),"corpse")
		"leave3":
			return command == "shop_leave"
		"end1","end2","end3":
			return command == "end_voyage"
	return false

static func _card_is(s: Dictionary, uid: String, id: String) -> bool:
	if uid.is_empty(): return false
	for card in s.get("hand",[]):
		if str(card.get("uid","")) == uid: return card.get("id","") == id and not card.get("temporary",false)
	return false

static func _is_scripted_destination(s: Dictionary, args: Dictionary) -> bool:
	var candidates: Array = s.get("candidates",[])
	if candidates.is_empty(): return false
	return str(candidates[0].get("visit_id","")) == str(args.get("id",""))

static func _installs_filter(s: Dictionary, args: Dictionary) -> bool:
	var uid := str(args.get("uid",""))
	if uid == "": return false
	for card in s.get("hand",[]):
		if str(card.get("uid","")) == uid: return str(card.get("id","")) == "filter"
	return false

static func _plays_survival(s: Dictionary, args: Dictionary) -> bool:
	var uid := str(args.get("uid",""))
	for card in s.get("hand",[]):
		if str(card.get("uid","")) == uid: return str(card.get("id","")) in ["water","food"]
	return false

static func _plays_spear(s: Dictionary, args: Dictionary) -> bool:
	var uid := str(args.get("uid",""))
	for card in s.get("hand",[]):
		if str(card.get("uid","")) == uid: return str(card.get("id","")) == "spear"
	return false

## Called after a successful dispatch. Records survival-card usage and makes sure
## the next scripted voyage has the one tool the lesson needs.
static func after_dispatch(ctx, command: String, args: Dictionary) -> void:
	var s: Dictionary = ctx.state
	if s.is_empty() or s.get("mode","") != "tutorial": return
	if not s.get("tutorial") is Dictionary: s.tutorial = new_state()
	if command == "battle_action" and args.get("action","") in ["attack","block"]:
		s.tutorial["enchant_"+str(args.action)+"_done"] = true
	if command == "sell": s.tutorial.sale_done = true
	ensure_supplies(ctx)

static func ensure_supplies(ctx) -> void:
	var s: Dictionary = ctx.state
	if s.is_empty() or s.get("mode","") != "tutorial": return
	if not s.get("tutorial") is Dictionary: s.tutorial = new_state()
	var t: Dictionary = s.tutorial
	if not t.get("granted") is Dictionary: t.granted = {}
	var voyage := int(s.get("voyage",1))
	# Supply only missing materials once upon entering battle, after first discard.
	if voyage == 2 and s.get("phase","") == "battle" and not t.granted.get("enchantment",false):
		t.granted.enchantment = true
		for id in ["iron","wood"]:
			if hand_count(s,id) == 0: ctx.give(id,1,false,"tutorial")
	if voyage < 2: return
	# Only top up once per voyage: using a card later must not summon a replacement.
	if int(t.get("supply_voyage",0)) >= voyage: return
	t.supply_voyage = voyage
	# Two scripted spears make the battle lesson two short, deterministic attacks.
	if voyage == 2 and hand_count(s,"spear") == 0:
		ctx.give("spear",2,false,"tutorial")
	# One replacement per resource per voyage, only when the card is missing.
	for id in ["water","food"]:
		if hand_count(s,id) == 0: ctx.give(id,1,false,"tutorial")

## Fixed reward used by every tutorial random draw site.
static func fixed_resource(s: Dictionary) -> String:
	return "wood"

static func fixed_stock() -> Array:
	return ["wood","plastic","rope","lamp","filter","fishingNet"]
