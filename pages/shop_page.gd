extends "res://pages/flow_base.gd"
## Selection and pagination are presentation-only.
const PAGE_SIZE := 6
var selling := false
var sell_page := 0
var body: VBoxContainer
var confirmation: ConfirmationDialog
var payment: OptionButton
var details: Label
var pending: Dictionary = {}
var selected_quote: Dictionary = {}
var buy_tab: Button
var sell_tab: Button

func build() -> void:
	# Mode switch and title share one header row; the corner X is the only exit.
	var header := HBoxContainer.new(); header.name = "ShopHeader"; add_child(header)
	header.add_theme_constant_override("separation", 16)
	var title := W.text(header, str(context.get("node",{}).get("name","漂流商店")), 34, W.GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tab_row := HBoxContainer.new(); header.add_child(tab_row)
	tab_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tab_row.add_theme_constant_override("separation", 8)
	buy_tab = W.button(tab_row, "购买货物", func(): switch_mode(false)); buy_tab.name = "ShopBuyTab"
	sell_tab = W.button(tab_row, "出售手牌 · 尸体3贝币", func(): switch_mode(true)); sell_tab.name = "ShopSellTab"
	for button in [buy_tab, sell_tab]:
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.custom_minimum_size = Vector2(150, 44) if not context.get("mobile",false) else Vector2(170, 56)
	var push := Control.new(); push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(push)
	# Reserve the corner X so the tabs never slide under it.
	var close_space := Control.new(); close_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_space.custom_minimum_size.x = 76 if context.get("mobile",false) else 56
	header.add_child(close_space)
	W.text(self, "贝币 %d  ·  尸体 %d  ·  资源共用翻倍价，各限2张；设备各限1张" % [context.get("coins",0),amount("corpse")], 17, W.MUTED)
	body=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	if context.get("mobile",false):
		var stock_scroll:=ScrollContainer.new(); stock_scroll.name="MobileShopStockScroll"
		stock_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		stock_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		add_child(stock_scroll); stock_scroll.add_child(body)
	else: add_child(body)
	confirmation=ConfirmationDialog.new()
	confirmation.title="确认交易"
	confirmation.min_size=Vector2i(540,260)
	confirmation.ok_button_text="确认购买"
	confirmation.cancel_button_text="取消"
	add_child(confirmation)
	for button in [confirmation.get_ok_button(), confirmation.get_cancel_button()]:
		W.TextButtonArt.apply(button)
	var dialog_body := VBoxContainer.new()
	dialog_body.custom_minimum_size=Vector2(500,190)
	dialog_body.size=Vector2(500,220)
	confirmation.add_child(dialog_body)
	details=W.text(dialog_body,"",18)
	# Wrapped text must know its width before first popup/minimum-size calculation.
	# Otherwise one-character lines can inflate the native window beyond the screen.
	details.custom_minimum_size=Vector2(480,150)
	details.size=Vector2(480,150)
	payment=OptionButton.new(); dialog_body.add_child(payment)
	payment.item_selected.connect(func(_index): _refresh_payment())
	confirmation.confirmed.connect(confirm_selection)
	confirmation.canceled.connect(cancel_selection)
	_render()
	paint_tabs()

## Only the corner X leaves the shop; tutorials can block it for one step.
func can_leave() -> bool:
	return not (context.get("mode","")=="tutorial" and context.get("tutorial_operation","")!="leave")

func leave_reason() -> String:
	if can_leave(): return "离开商店"
	return str(context.get("tutorial_reason","先完成商店教学操作"))

func paint_tabs() -> void:
	for pair in [[buy_tab, not selling], [sell_tab, selling]]:
		var button: Button = pair[0]
		if not is_instance_valid(button): continue
		var active: bool = pair[1]
		button.add_theme_color_override("font_color", W.GOLD if active else W.MUTED)
		button.add_theme_color_override("font_hover_color", W.GOLD if active else W.INK)
		button.set_meta("surge_primary", active)
		button.set_meta("shop_active", active)
		if button.has_node("SurgeTextButtonArt"): button.get_node("SurgeTextButtonArt").queue_redraw()

func switch_mode(value: bool) -> void:
	cancel_selection()
	selling=value
	_render()
	paint_tabs()

func _render() -> void:
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	var shop: Dictionary=context.get("shop",{})
	if not selling:
		var grid := W.grid(body,3)
		for i in range(3):
			var box := _slot(grid)
			var offers: Array=shop.get("relic_stock",[])
			if i>=offers.size():
				W.text(box,"潮汐遗物",20,W.GOLD)
				W.text(box,"本次没有供货",16,W.MUTED)
				continue
			var row: Dictionary=offers[i]
			W.text(box,row.name,20,W.GOLD)
			var description:=W.text(box,"查看效果 · 本店限购1件",14,W.MUTED)
			description.tooltip_text=row.description
			W.button(box,"售罄" if row.remaining==0 else "%d 贝币" % row.price,func():select_buy(row),row.remaining==0)
		for row in shop.get("stock",[]):
			var box := _slot(grid)
			W.text(box,row.name,20,W.GOLD)
			W.text(box,"%s · %d / %d 剩余" % ["基本资源" if row.kind=="resource" else "设备",row.remaining,row.limit],14,W.MUTED)
			var label: String="售罄" if row.remaining==0 else "%d 贝币" % row.price
			var tutorial_locked: bool=context.get("mode","")=="tutorial" and (context.get("tutorial_operation","")!="buy" or row.id!="wood")
			W.button(box,label,func():select_buy(row),row.remaining==0 or tutorial_locked)
		return
	var rows: Array=shop.get("sellable",[])
	var pages: int=maxi(1,ceili(float(rows.size())/PAGE_SIZE))
	sell_page=clampi(sell_page,0,pages-1)
	W.text(body,"尸体每张3贝币，其余可售牌每张1贝币；基础材料、已安装设备、临时牌、战斗牌与污染牌不能出售。",15,W.MUTED)
	var grid := W.grid(body,3)
	for row in rows.slice(sell_page*PAGE_SIZE,(sell_page+1)*PAGE_SIZE):
		var box := _slot(grid)
		W.text(box,row.name,20,W.GOLD)
		W.text(box,"单张 · %d贝币" % int(row.price),16,W.MUTED)
		var sell_button := W.button(box,"选择出售",func():select_sell(row))
		sell_button.name="ShopSell_"+str(row.id)
		if context.get("mode","")=="tutorial" and (context.get("tutorial_operation","")!="sell" or row.id!="corpse"): sell_button.disabled=true
	if rows.is_empty(): W.text(body,"当前没有可出售的手牌。",20,W.MUTED)
	if pages > 1:
		var pager := HBoxContainer.new(); body.add_child(pager)
		pager.alignment = BoxContainer.ALIGNMENT_CENTER
		var previous := W.button(pager,"上一页",func():sell_page-=1;_render(),sell_page==0)
		previous.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		previous.custom_minimum_size.x = 110
		W.counter(pager,"%d / %d" % [sell_page+1,pages])
		var next := W.button(pager,"下一页",func():sell_page+=1;_render(),sell_page==pages-1)
		next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next.custom_minimum_size.x = 110

func _slot(parent: Node) -> VBoxContainer:
	var outer := PanelContainer.new(); parent.add_child(outer)
	outer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	outer.custom_minimum_size=Vector2(210,116)
	var style := StyleBoxFlat.new()
	style.bg_color=Color("102832"); style.border_color=W.GOLD; style.set_border_width_all(1)
	style.content_margin_left=14; style.content_margin_right=14; style.content_margin_top=10; style.content_margin_bottom=10
	outer.add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new(); outer.add_child(box)
	return box

func select_buy(row: Dictionary) -> void:
	if row.remaining<=0: return
	selected_quote=row.duplicate(true)
	pending={"command":"buy_collectible" if row.get("kind","")=="collectible" else "buy","args":{"id":row.id,"payment":"coin"}}
	confirmation.title="购买 · "+row.name
	if row.get("kind","")=="collectible":
		details.text="%s\n\n%s\n\n购买后立即生效，可在潮汐遗物面板查看；不占手牌容量。" % [row.name,row.description]
	else:
		details.text="%s\n\n%s\n\n本店剩余 %d 张。购买后立即进入手牌；购买任一资源会使全店资源原价翻倍。" % [row.name,row.description,row.remaining]
	confirmation.ok_button_text="确认购买"
	payment.clear(); payment.show()
	payment.add_item("支付 %d 贝币%s" % [row.price,"" if row.can_coin else "（不足）"])
	payment.select(0)
	_refresh_payment()
	confirmation.popup_centered(Vector2i(560,320))

func _refresh_payment() -> void:
	if pending.get("command","") not in ["buy","buy_collectible"]: return
	pending.args.payment="coin"
	confirmation.get_ok_button().disabled=not bool(selected_quote.can_coin)

func select_sell(row: Dictionary) -> void:
	pending={"command":"sell","args":{"uid":row.uid}}
	confirmation.title="出售 · "+row.name
	details.text="%s\n\n%s\n\n出售所选单张，获得%d贝币。" % [row.name,row.description,int(row.price)]
	confirmation.ok_button_text="确认出售"
	payment.hide(); confirmation.get_ok_button().disabled=false
	confirmation.popup_centered(Vector2i(560,320))

func cancel_selection() -> void:
	pending.clear(); selected_quote.clear()
	if confirmation!=null: confirmation.hide()

func confirm_selection() -> void:
	if pending.is_empty() or confirmation.get_ok_button().disabled: return
	var transaction: Dictionary=pending.duplicate(true)
	cancel_selection()
	send(transaction.command,transaction.args)
