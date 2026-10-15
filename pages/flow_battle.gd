extends "res://pages/flow_base.gd"
const ItemCard = preload("res://presentation/item_card.gd")
const Battle = preload("res://core/battle_rules.gd")
const RESOURCES := ["wood","iron","rope","plastic","cloth"]

func build() -> void:
	var enemy: Dictionary = catalog.entry("enemies",context.battle.id)
	heading("战斗 · 第%d回合" % context.battle.turn,"生命 %d/%d · 战斗AP %d/%d" % [context.player.hp,context.player.hp_max,context.battle.ap,context.player.battle_ap])
	var status := HBoxContainer.new(); status.name="BattleStatus"; add_child(status)
	var target := W.panel(status,Vector2(300,0)); target.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	W.text(target,enemy.name,25,W.GOLD)
	W.text(target,"敌方生命 %d/%d" % [context.battle.hp,enemy.hp],20)
	var intent: Dictionary=context.battle.get("intent",{})
	var intent_text: String=str(enemy.intent)
	if intent.get("type","")=="biter_bite":
		var cell_id: String=str(context.battle.get("raft_target_cell",intent.get("target_cell","")))
		var cell: Dictionary={}
		for candidate in context.cells:
			if candidate.id==cell_id: cell=candidate
		var location: String="无可攻击的外围筏格" if cell.is_empty() else "筏格 %d,%d" % [int(cell.x)+1,int(cell.y)+1]
		intent_text += "\n预告：咬击 %s" % location
	var intent_label := W.text(target,intent_text,17,W.MUTED); intent_label.name="BattleIntentTarget"
	var shield_panel := W.panel(status,Vector2(300,0)); shield_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var shields: Array=context.battle.get("shields",[])
	var current_total:=0; var next_total:=0
	for shield in shields:
		var amount:=int(shield.get("amount",0))
		if int(shield.get("expires_turn",0))<=int(context.battle.turn): current_total+=amount
		else: next_total+=amount
	var shield_title:=W.text(shield_panel,"护盾总量 %d" % (current_total+next_total),21,W.GOLD)
	shield_title.name="BattleShieldSummary"
	W.text(shield_panel,"本轮到期 %d   ·   下轮到期 %d" % [current_total,next_total],16,W.MUTED)
	var shield_groups: Dictionary={}
	for shield in shields:
		var expiry: String="本轮到期" if int(shield.get("expires_turn",0))<=int(context.battle.turn) else "下轮到期"
		var key:=expiry+"·"+str(shield.get("source","护盾"))
		if not shield_groups.has(key): shield_groups[key]={"amount":0,"layers":0}
		shield_groups[key].amount+=int(shield.get("amount",0)); shield_groups[key].layers+=1
	var shield_keys: Array=shield_groups.keys(); shield_keys.sort()
	for key in shield_keys: W.text(shield_panel,"%s %d点 · %d层" % [key,int(shield_groups[key].amount),int(shield_groups[key].layers)],14,W.MUTED)
	var control_panel := W.panel(self); control_panel.name="BattleActionPanel"
	var action_row:=HBoxContainer.new(); control_panel.add_child(action_row)
	var attack:=W.button(action_row,"攻击 · 1 AP",func(): choose_action("attack")); attack.name="BattleAttack"
	var block:=W.button(action_row,"格挡 · 1 AP",func(): choose_action("block")); block.name="BattleBlock"
	attack.disabled=int(context.battle.get("ap",0))<1; block.disabled=attack.disabled
	var action_reason:=W.text(control_panel,"基础行动可重复使用，不占手牌。",15,W.MUTED)
	action_reason.name="BattleActionHelp"
	var material_row:=HBoxContainer.new(); control_panel.add_child(material_row)
	W.text(material_row,"组合资源",16,W.GOLD)
	var selected:=selection()
	for id in RESOURCES:
		var found: Array=context.hand.filter(func(card):return card.id==id and not card.temporary)
		var selected_type:=found.any(func(card):return str(selected.get("resource_uid",""))==str(card.uid))
		var first_uid: String=str(found[0].uid) if not found.is_empty() else ""
		var resource_button:=W.button(material_row,catalog.entry("cards",id).name+" ×%d" % found.size(),func():select_value("resource_uid",first_uid),found.is_empty())
		resource_button.name="BattleResourceGroup_"+id
		if selected_type: resource_button.add_theme_color_override("font_color",W.GOLD)
	var buff_row:=HBoxContainer.new(); control_panel.add_child(buff_row)
	W.text(buff_row,"独立发电机增益",16,W.GOLD)
	var battle_buffs: Array=context.get("boost_cards",[]).filter(func(buff):return buff.get("id","") in ["power","barrier"])
	if not battle_buffs.is_empty():
		var boost_select:=OptionButton.new(); boost_select.name="BattleBoostSelect"; buff_row.add_child(boost_select)
		for buff in battle_buffs:
			var buff_name: String=str(buff.get("definition",{}).get("name",{"power":"动力强化","barrier":"屏障强化"}.get(buff.id,buff.id)))
			var suffix: String=" · 临时·下轮结算消失" if bool(buff.get("temporary",false)) or int(buff.get("expires_voyage",0))>0 else ""
			boost_select.add_item(buff_name+suffix); boost_select.set_item_metadata(boost_select.item_count-1,str(buff.uid))
			if str(selected.get("buff_uid",""))==str(buff.uid): boost_select.select(boost_select.item_count-1)
		boost_select.item_selected.connect(func(index):select_value("buff_uid",str(boost_select.get_item_metadata(index))))
	else: W.text(buff_row,"暂无动力强化/屏障强化",14,W.MUTED)
	if not selected.is_empty():
		var selected_summary:=W.text(control_panel,selection_text(selected),16,W.MUTED)
		selected_summary.name="BattleSelectionSummary"
	var preview_data: Dictionary=selected.get("preview",{})
	if not preview_data.is_empty():
		var preview_panel:=W.panel(control_panel); preview_panel.name="BattlePreview"
		if preview_data.get("valid",false):
			var battle_after: Dictionary=preview_data.get("battle",{})
			var player_after: Dictionary=preview_data.get("player",{})
			var summary:=W.text(preview_panel,"预览 · 敌方生命 %d · 战斗AP %d · 自身生命 %d\n%s" % [int(battle_after.get("hp",0)),int(battle_after.get("ap",0)),int(player_after.get("hp",0)),preview_effect_summary(battle_after)],16,W.GOLD)
			summary.name="BattlePreviewSummary"
		else:
			W.text(preview_panel,"无法执行：%s" % preview_data.get("error","组合不合法"),17,Color("df968b"))
		var preview_actions:=HBoxContainer.new(); preview_panel.add_child(preview_actions)
		var confirm:=W.button(preview_actions,"确认行动",func(): confirm_selection())
		confirm.name="ConfirmBattleAction"; confirm.disabled=not preview_data.get("valid",false)
		var cancel:=W.button(preview_actions,"取消",func(): clear_selection())
		cancel.name="CancelBattleSelection"
	var bottom:=HBoxContainer.new(); bottom.size_flags_vertical=Control.SIZE_EXPAND_FILL; add_child(bottom)
	var target_panel:=W.panel(bottom,Vector2(260,0)); target_panel.get_parent().size_flags_horizontal=0
	if context.get("scene",{}).get("combat",false): W.text(target_panel,"教学战斗需要胜利后继续。",16,W.MUTED)
	else: action(target_panel,"撤退","retreat",{},context.battle.turn<2,"第二回合起可撤退")
	action(target_panel,"结束战斗回合","battle_end")
	var hand:=VBoxContainer.new(); hand.size_flags_horizontal=Control.SIZE_EXPAND_FILL; bottom.add_child(hand)
	var cards: Array=context.hand.filter(func(card):return card.definition.kind in ["combat","survival","negative","resource"] and card.id!="coin" and card.id!="corpse")
	var fan=load("res://presentation/hand_fan.gd").new(); hand.add_child(fan)
	fan.set_meta("presentation_role","battle"); fan.create(assets,cards,context)
	for i in range(fan.cards.size()):
		if fan.cards[i].definition.kind=="resource": fan.buttons[i].name="BattleFanResource_"+str(fan.cards[i].uid)
	fan.reordered.connect(func():request("hand_reordered"))
	fan.activated.connect(func(card):play_card(card))

func selection() -> Dictionary:
	var raw: String=str(context.get("ui_state",{}).get("battle_selection","{}"))
	if raw.is_empty(): return {}
	var value: Variant=JSON.parse_string(raw)
	return value if value is Dictionary else {}

func selection_text(value: Dictionary) -> String:
	var parts: PackedStringArray=[]
	var uid: String=str(value.get("resource_uid",""))
	if uid!="":
		for card in context.hand:
			if str(card.uid)==uid: parts.append("资源："+catalog.entry("cards",card.id).name); break
	var buff_uid: String=str(value.get("buff_uid",""))
	if buff_uid!="":
		for buff in context.get("boost_cards",[]):
			if str(buff.uid)==buff_uid: parts.append("增益："+str(buff.get("definition",{}).get("name",buff.id))); break
	if value.has("action"): parts.append("行动："+("攻击" if value.action=="attack" else "格挡"))
	if value.has("card_uid"): parts.append("卡牌：已选攻击牌")
	return " · ".join(parts)

func preview_effect_summary(after: Dictionary) -> String:
	var parts: PackedStringArray=[]
	var total:=0; var this_turn:=0; var next_turn:=0
	for shield in after.get("shields",[]):
		var amount:=int(shield.get("amount",0)); total+=amount
		if int(shield.get("expires_turn",0))<=int(after.get("turn",context.battle.turn)): this_turn+=amount
		else: next_turn+=amount
	if total>0: parts.append("%d盾（本轮%d · 下轮%d）" % [total,this_turn,next_turn])
	if after.get("bound_effect",false) and not context.battle.get("bound_effect",false):
		var enemy_id: String=str(context.battle.get("id",""))
		parts.append("取消啃筏" if enemy_id=="biter" else "取消毒刺" if enemy_id=="jelly" else "束缚生效")
	var damage_delta:=int(after.get("enemy_damage_delta",0))-int(context.battle.get("enemy_damage_delta",0))
	if damage_delta<0: parts.append("下次受击减伤%d" % absi(damage_delta))
	if after.get("counter_ready",false) and not context.battle.get("counter_ready",false): parts.append("反击就绪")
	if int(context.battle.get("poison_until",0))>=int(context.battle.turn) and int(after.get("poison_until",0))<int(context.battle.turn): parts.append("清除中毒")
	if int(context.battle.get("bleed_until",0))>=int(context.battle.turn) and int(after.get("bleed_until",0))<int(context.battle.turn): parts.append("清除流血")
	return " · ".join(parts) if not parts.is_empty() else "未产生额外盾、克制或状态效果"

func select_value(key: String, value: String) -> void:
	var next:=selection(); next[key]=value; next.erase("action"); next.erase("preview")
	next.erase("card_uid"); next.erase("play_args")
	request("battle_selection",JSON.stringify(next))

func choose_action(action_id: String) -> void:
	var args: Dictionary={"action":action_id}
	var chosen:=selection()
	chosen.erase("card_uid"); chosen.erase("play_args")
	if chosen.has("resource_uid") or chosen.has("buff_uid"):
		args.merge(chosen,true)
		# The button just pressed is authoritative; stale selection state must not
		# make the preview describe a different basic action.
		args.action=action_id
		args.erase("preview")
		var result:=preview(args)
		chosen.action=action_id; chosen.preview=result
		request("battle_selection",JSON.stringify(chosen))
	else:
		send("battle_action",args)

func play_card(card: Dictionary) -> void:
	var chosen:=selection()
	if card.definition.kind=="resource":
		if card.id in RESOURCES: select_value("resource_uid",str(card.uid))
		return
	var args: Dictionary={"uid":card.uid}
	if chosen.has("buff_uid"):
		args.buff_uid=chosen.buff_uid
		var result:=preview(args)
		chosen={"card_uid":card.uid,"buff_uid":chosen.buff_uid,"play_args":args,"preview":result}
		request("battle_selection",JSON.stringify(chosen))
	else: send("play",args)

func preview(args: Dictionary) -> Dictionary:
	if session==null: return {"valid":false,"error":"战斗预览不可用"}
	return Battle.preview(session,args)

func confirm_selection() -> void:
	var chosen:=selection()
	if not chosen.get("preview",{}).get("valid",false): return
	if chosen.has("action"):
		var args: Dictionary={"action":chosen.action}
		for key in ["resource_uid","buff_uid"]:
			if chosen.has(key): args[key]=chosen[key]
		send("battle_action",args)
	elif chosen.has("play_args"):
		send("play",chosen.play_args)
	request("battle_selection","")

func clear_selection() -> void:
	request("battle_selection","")
