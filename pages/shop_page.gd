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

func build() -> void:
	heading(context.get("node",{}).get("name","漂流商店"),"贝币 %d  ·  尸体 %d  ·  资源共用翻倍价，各限2张；设备各限1张" % [context.get("coins",0),amount("corpse")])
	var tabs := HBoxContainer.new(); add_child(tabs)
	var buy_tab := W.button(tabs,"购买货物",func(): switch_mode(false)); buy_tab.name="ShopBuyTab"
	var sell_tab := W.button(tabs,"出售手牌 · 尸体3贝币",func(): switch_mode(true)); sell_tab.name="ShopSellTab"
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
	action(self,"离开商店","shop_leave",{},context.get("mode","")=="tutorial" and context.get("tutorial_operation","")!="leave",context.get("tutorial_reason",""))

func switch_mode(value: bool) -> void:
	cancel_selection()
	selling=value
	_render()

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
	var pager := HBoxContainer.new(); body.add_child(pager)
	W.button(pager,"上一页",func():sell_page-=1;_render(),sell_page==0)
	W.counter(pager,"%d / %d" % [sell_page+1,pages])
	W.button(pager,"下一页",func():sell_page+=1;_render(),sell_page==pages-1)

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
