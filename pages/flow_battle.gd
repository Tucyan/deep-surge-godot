extends "res://pages/flow_base.gd"
const ItemCard = preload("res://presentation/item_card.gd")
func build() -> void:
	var enemy: Dictionary = catalog.entry("enemies",context.battle.id)
	heading("战斗 · 第%d回合" % context.battle.turn,"生命 %d/%d · 战斗AP %d/%d" % [context.player.hp,context.player.hp_max,context.battle.ap,context.player.battle_ap])
	var row := HBoxContainer.new(); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(row)
	var target := W.panel(row,Vector2(310,0)); target.get_parent().size_flags_horizontal = 0
	W.art(target,assets,"enemy."+context.battle.id,125)
	W.text(target,enemy.name,26,W.GOLD)
	W.text(target,"生命 %d/%d" % [context.battle.hp,enemy.hp],23)
	W.text(target,enemy.intent,18,W.MUTED)
	action(target,"结束战斗回合","battle_end")
	if context.get("scene",{}).get("combat",false): W.text(target,"教学战斗需要胜利后继续。",16,W.MUTED)
	else: action(target,"撤退","retreat",{},context.battle.turn < 2,"第二回合起可撤退")
	var hand := VBoxContainer.new(); hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(hand)
	var cards: Array = context.hand.filter(func(card): return card.definition.kind in ["combat","survival","negative"])
	var fan = load("res://presentation/hand_fan.gd").new(); hand.add_child(fan)
	fan.set_meta("presentation_role","battle"); fan.create(assets,cards,context)
	fan.reordered.connect(func(): request("hand_reordered"))
	fan.activated.connect(func(card): send("play",{"uid":card.uid}))

func compact_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = Color("142d38"); style.border_color = W.GOLD; style.set_border_width_all(1)
	style.content_margin_left = 10; style.content_margin_right = 10; style.content_margin_top = 10; style.content_margin_bottom = 10
	return style
