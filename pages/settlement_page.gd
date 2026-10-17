extends "res://pages/flow_base.gd"
## Frozen-report reader. Playback state belongs only to this view.
const SPEED := 24.0
const HOLD_THRESHOLD := 0.35
const LABELS := {
	"resource":"资源","currency":"货币","survival":"生存","combat":"战斗","negative":"负面","equipment":"设备","action":"行动",
	"hp":"生命","hp_max":"生命上限","sanity":"精神","sanity_max":"精神上限","san":"精神","hunger":"饱食","hunger_max":"饱食上限","hydration":"水分","hydration_max":"水分上限",
	"supply":"补给","battle":"战斗","event":"事件","rest":"休息","trade":"交易","exchange":"物资交换","environment":"环境事件","ruin":"遗迹","shop":"商店","story":"剧情","boss":"首领",
	"initial":"起手补给","spring":"涌泉","reward":"节点奖励","production":"设备生产","tutorial":"教学补给","farewell":"离别补给","quest":"委托","night-service":"夜间交换","meta":"局外补给","profile":"局外补给","dismantle":"拆除返还",
	"cost":"物资费用","craft":"制造","fuel":"投入燃料","repair":"修补","heal":"治疗","play":"出牌","discard":"主动弃置","install":"部署设备","upgrade":"升级设备","expand":"扩建","action_card":"使用行动牌","battle_end":"结束战斗回合",
	"voyage":"航行移动","enter":"进入节点","advance":"继续剧情","skip":"跳过已发生对白","option":"选择事件行动","shop_enter":"进入商店","shop_leave":"离开商店","buy":"购买","fight":"开始战斗","leave_encounter":"免费离开遭遇","retreat":"战斗撤退","repair_cell":"修补筏格","salvage":"打捞","transmute":"资源转化","end_voyage":"结束航次","night_actions":"夜间行动","night_action":"夜间调查或休息","night_ack":"确认夜间事件","finish_night":"结束夜间","accept_quest":"接受委托","submit_quest":"提交委托","night_exchange":"夜间交换","abandon":"主动放弃",
	"exploration":"多样探索","device":"设备发挥作用","investigation":"获得调查成果",
	"device_uses":"设备生效次数","produced":"设备产出份数","repairs":"修补次数","salvages":"打捞次数","transmutes":"转化次数","expansions":"新增筏格","installations":"安装设备","upgrades":"升级设备","equipment_removed":"设备移除","dismantles":"拆除设备次数","base_ap_spent":"基地行动点支出","battle_ap_spent":"战斗行动点支出","damage":"有效伤害","damage_dealt":"造成有效伤害","damage_taken":"受到实际伤害","battle_turns":"战斗回合","battle_rounds":"结束战斗回合数","pollution_cleared":"清除负面",
	"won":"胜利","victory":"胜利","unfinished":"未结束","protected":"保护败退","retreated":"战斗撤退","lost":"损失","dead":"沉入深潮","mad":"迷失潮声","withdrawn":"离开潮眼","survived":"灯火未熄","true":"回声归航","A":"成功封闭","B":"付出代价后处理","C":"紧急撤离","SOLO":"独航出口",
	"granted":"实际入账","pending":"尚未入账","bonus":"评分奖励","completed":"完成节点","length":"目标节点","goal":"达成目标","events_entered":"进入事件危机","events_won":"解决事件危机","battles_entered":"实际入战","battles_won":"战斗胜利","tags":"成果标签","cells":"初始筏格保全比例","p":"推进比例","h":"生命比例","s":"精神比例","c":"筏格保全比例",
	"success":"达成目标","resolved":"已处理","turns":"实际战斗回合","outcome":"结果","name":"名称","kind":"类型","obtained":"获得","used":"使用","use_consumed":"使用消耗","cost_consumed":"费用消耗","deployed":"部署转出","cleared":"临时清理","remaining":"留存","sold":"出售","stopped":"主动收手","fallback_visits":"补给回退次数"
}
const EXTRA_LABELS := {"equipment_merge":"设备合并","equipment_dismantle":"主动拆除设备","equipment_loss":"设备非自愿损失","recovery_overflow":"恢复溢出","night":"夜间行动","system":"航次结算","final_plan":"章节方案投入","seal":"封闭潮眼","tow":"拖离装置","evacuate":"紧急撤离","flee":"紧急撤离","exit":"继续独航","solo_exit":"继续独航","solo":"独航路线","scholar":"学者分队路线","active":"进行中","completed":"已完成","restored":"实际恢复","overflow":"溢出","outputs":"实际产物","lamp":"灯","water":"淡水","wood":"木头","rope":"绳索","cloth":"布条","plastic":"塑料","iron":"废铁"}
var report: Dictionary = {}
var page_index := 0
var scroll_position := 0.0
var accelerating := false
var paused := false
var incomplete := false
var _held := false
var _hold_time := 0.0
var _end_time := 0.0
var _review := false
var _tab := 0
var _syncing_scroll := false
var _scroll: ScrollContainer
var _pause_button: Button
var _speed_label: Label
var _content: VBoxContainer

func build() -> void:
	var raw = context.get("settlement", {})
	report = raw.duplicate(true) if raw is Dictionary else {}
	incomplete = not report.get("complete",false) or not report.get("score",{}) is Dictionary or not report.get("score",{}).has("total")
	theme = W.theme()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_draw_page()

func _draw_page() -> void:
	end_hold()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	_content = VBoxContainer.new(); margin.add_child(_content)
	var header := HBoxContainer.new(); _content.add_child(header)
	W.text(header,"DEEP SURGE  /  航行档案",16,W.GOLD)
	W.text(header,"仅可回看最近一次结算  ·  %s" % ("章节报告" if report.get("scope","") == "chapter" else "整局报告"),14,W.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var close:=W.button(header,"X",func(): end_hold(); request("settlement_exit"))
	close.name="CloseX"; close.accessibility_name="关闭"; close.tooltip_text="关闭"
	close.size_flags_horizontal=Control.SIZE_SHRINK_END; close.custom_minimum_size=Vector2(44,44)
	_content.add_child(HSeparator.new())
	if page_index == 0: _draw_logs()
	else: _draw_analysis()

func _draw_logs() -> void:
	W.text(_content,"潮声渐息 · 航海日志",32,W.GOLD)
	W.text(_content,"%s  ·  %s  ·  种子 %s" % [_mode(),_origin(),_value(report,"seed")],16,W.MUTED)
	var panel := W.panel(_content)
	panel.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = false
	panel.add_child(_scroll)
	var entries := VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation",18)
	_scroll.add_child(entries)
	W.text(entries,"——  出发至终点，留下真实发生的每一页  ——",16,W.GOLD)
	var logs = report.get("logs",[])
	if logs is Array and not logs.is_empty():
		for i in range(logs.size()):
			var row := HBoxContainer.new(); entries.add_child(row)
			var number := W.text(row,"%03d" % (i+1),14,W.GOLD)
			number.size_flags_horizontal = 0; number.custom_minimum_size.x = 42
			W.text(row,str(logs[i]),19,W.INK)
	else: W.text(entries,"历史统计不完整 · 没有可用的航海日志",19,W.MUTED)
	W.text(entries,"——  本次航程记录结束  ——",18,W.GOLD)
	_scroll.get_v_scroll_bar().value_changed.connect(func(value):
		if not _syncing_scroll: scroll_position = value; _end_time = 0.0)
	var controls := HBoxContainer.new(); _content.add_child(controls)
	_pause_button = W.button(controls,"继续" if paused else "暂停",toggle_pause)
	W.button(controls,"回到开头",func(): end_hold(); scroll_position = 0; _scroll.scroll_vertical = 0; _end_time = 0)
	W.primary(W.button(controls,"跳过，查看结算",show_analysis))
	_speed_label = W.text(_content,"回看已暂停 · 滚轮 / 拖动回看" if paused else "自动慢速播放 · 长按日志或空格 0.35 秒加速 ×6 · 松开恢复",14,W.MUTED)

func _draw_analysis() -> void:
	_scroll = null
	var top := HBoxContainer.new(); _content.add_child(top)
	var summary := W.panel(top); var score := W.panel(top)
	W.text(summary,"航程结算",30,W.GOLD)
	W.text(summary,"%s · %s · 种子 %s" % [_mode(),_origin(),_value(report,"seed")],16,W.MUTED)
	W.text(summary,"结局：%s  ｜  完成节点 %s / %s" % [_outcome(),_value(report,"completed"),_value(report,"length")],20)
	if report.get("scope","") == "chapter": W.text(summary,"第一层完成；后续章节尚未开放\n整局尚未结束，%s 涌潮点尚未入账" % _value(_dict("points"),"pending"),15,W.GOLD)
	else: W.text(summary,"涌潮点入账 %s  ·  评分奖励 %s" % [_value(_dict("points"),"granted"),_value(_dict("points"),"bonus")],18,W.GOLD)
	var scoring := _dict("score")
	W.text(score,"历史统计不完整" if incomplete else "%s  ·  %s 分" % [_value(scoring,"grade"),_value(scoring,"total")],30,W.GOLD)
	if incomplete:
		var coverage := _dict("stats")
		var notice := "历史统计仅覆盖第%s航次起；最低值与累计量仅属这段记录。" % _value(coverage,"coverage_start") if coverage.has("coverage_start") else "历史统计覆盖起点未知，最低值与累计量不能视作完整航程。"
		W.text(score,notice+"\n终点状态仍为结算时的实际数值。",14,W.MUTED)
	var components = scoring.get("components",{})
	if not components is Dictionary: components = {}
	W.text(score,"航行 %s / 500    危机 %s / 250\n生存 %s / 150    探索 %s（不封顶）" % [_value(components,"voyage"),_value(components,"crisis"),_value(components,"survival"),_value(components,"exploration")],17)
	W.text(score,"评分与评级为试测值；结局保持实际结果",13,W.MUTED)
	var insights := HBoxContainer.new(); _content.add_child(insights)
	var analysis = report.get("analysis",[])
	if analysis is Array:
		for line in analysis.slice(0,3): W.text(insights,"◇  "+str(line),15,W.MUTED)
	var tabs := HBoxContainer.new(); _content.add_child(tabs)
	var names := ["分数明细","卡牌收支","战斗与危机","生存与木筏","航行与剧情"]
	for i in range(names.size()):
		var index := i
		var button := W.button(tabs,names[i],func(): _tab=index; _draw_page())
		if i == _tab: W.primary(button)
	var detail := W.panel(_content)
	detail.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "SettlementDetailScroll"
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(detail_scroll)
	var entries := VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(entries)
	for line in _detail_lines(): W.text(entries,line,16)
	var controls := HBoxContainer.new(); _content.add_child(controls)
	W.button(controls,"回看航海日志",show_logs)

func _detail_lines() -> Array[String]:
	var result: Array[String] = []
	var stats := _dict("stats")
	match _tab:
		0:
			var score := _dict("score")
			var inputs = score.get("inputs",{})
			if not inputs is Dictionary: inputs={}
			var parts = score.get("components",{})
			if not parts is Dictionary: parts={}
			result.append("航行成果 · %s / 500 分" % _value(parts,"voyage"))
			result.append("350 × 推进比例 + 150 × 达成目标；每项四舍五入后相加。")
			result.append("完成节点 %s / %s；达成目标：%s" % [_value(report,"completed"),_value(report,"length"),_display(inputs.get("goal",null))])
			result.append("危机处理 · %s / 250 分" % _value(parts,"crisis"))
			result.append("推进比例 ×（150 × 事件成功数 / 进入数 + 100 × 战斗胜利数 / 入战数）。\n某类没有进入时使用另一类完成率；两类均无时都取1，按推进比例折算。")
			result.append("事件解决 %s / %s；战斗胜利 %s / %s" % [_value(inputs,"events_won"),_value(inputs,"events_entered"),_value(inputs,"battles_won"),_value(inputs,"battles_entered")])
			result.append("生存与维护 · %s / 150 分" % _value(parts,"survival"))
			result.append("推进比例 ×（75 × 生命比例 + 45 × 精神比例 + 30 × 初始筏格保全比例）。")
			result.append("生命比例 %s；精神比例 %s；初始筏格保全比例 %s" % [_ratio(inputs.get("hp",inputs.get("h",null))),_ratio(inputs.get("sanity",inputs.get("s",null))),_ratio(inputs.get("cells",inputs.get("c",null)))])
			result.append("探索与建设 · %s 分（不封顶）" % _value(parts,"exploration"))
			result.append("推进比例 × 25 × 成果标签数（全部计入，不封顶）；耗卡数量不直接计分。")
			result.append("达成成果 %s 项；涌潮点：%s" % [_value(inputs,"tags"),_display(report.get("points",null))])
		1:
			var cards = report.get("cards",[])
			if cards is Array:
				for card in cards:
					if not card is Dictionary: continue
					result.append("%s [%s]  获得 %s · 使用 %s · 使用消耗 %s · 费用 %s\n部署 %s · 弃置 %s · 损失 %s · 清理 %s · 出售 %s · 留存 %s" % [_value(card,"name"),_label(_value(card,"kind")),_value(card,"obtained"),_value(card,"used"),_value(card,"use_consumed"),_value(card,"cost_consumed"),_value(card,"deployed"),_value(card,"discarded"),_value(card,"lost"),_value(card,"cleared"),_value(card,"sold"),_value(card,"remaining")])
					if card.has("remaining_permanent") or card.has("remaining_temporary"): result.append("永久留存 %s · 临时留存 %s" % [_value(card,"remaining_permanent"),_value(card,"remaining_temporary")])
					result.append("来源：%s  ｜  去向原因：%s" % [_display(card.get("sources",null)),_display(card.get("reasons",null))])
		2:
			var battles = stats.get("battles",null)
			if battles is Dictionary:
				for battle in battles.values():
					if battle is Dictionary: result.append("%s · %s · 实际战斗 %s 回合" % [_content_name("enemies",str(battle.get("enemy","")),"遭遇敌人"),_label(str(battle.get("outcome",""))),_value(battle,"turns")])
			else: result.append("真实战斗：历史统计不完整")
			var crises = stats.get("crises",null)
			if crises is Dictionary:
				for crisis in crises.values():
					if crisis is Dictionary:
						var outcome := "未知结果" if not crisis.has("success") else ("达成目标" if crisis.success else "未达成目标")
						result.append("%s · %s" % [_node_name(str(crisis.get("id",""))),outcome])
			else: result.append("事件危机：历史统计不完整")
			_append_records(result,"战斗及其他计数",stats.get("counters",null))
		3:
			_append_records(result,"终点状态",report.get("player",null))
			for pair in [["minimum","最低状态"],["restored","实际恢复"],["lost","实际损失"]]: _append_records(result,pair[1],stats.get(pair[0],null))
			for pair in [["initial_cells","初始逻辑格数"],["detached","曾脱落格数"]]:
				var cells = stats.get(pair[0],null)
				result.append(pair[1]+"："+(str(cells.size()) if cells is Array else "历史统计不完整"))
			var devices = stats.get("devices",{})
			if devices is Dictionary:
				for device in devices.values():
					if not device is Dictionary: continue
					result.append("%s · 实际生效 %s 次 · 产出 %s 份\n实际产物：%s" % [_content_name("equipment",str(device.get("id","")),"已记录设备"),_value(device,"uses"),_value(device,"produced"),_item_amounts(device.get("outputs",{}))])
			var attributes = stats.get("attribute_sources",{})
			if attributes is Dictionary:
				for stat in attributes:
					if not attributes[stat] is Dictionary: continue
					for source in attributes[stat]:
						var fact = attributes[stat][source]
						if not fact is Dictionary: continue
						result.append("%s · %s · 实际恢复 %s · 实际损失 %s · 溢出 %s" % [_label(str(stat)),_label(str(source)),_value(fact,"restored"),_value(fact,"lost"),_value(fact,"overflow")])
		4:
			var visits = stats.get("visits",null)
			if visits is Array:
				for visit in visits:
					if visit is Dictionary: result.append("第%s航次 · %s · %s" % [_value(visit,"voyage"),_value(visit,"name"),_label(str(visit.get("kind",visit.get("type",""))))])
			else: result.append("真实访问：历史统计不完整")
			var crafts = stats.get("crafts",null)
			if crafts is Array:
				for recipe in crafts: result.append("制造配方："+_content_name("recipes",str(recipe),"已记录配方"))
			else: result.append("制造配方：历史统计不完整")
			for pair in [["tags","成果标签"],["commands","成功操作"]]: _append_records(result,pair[1],stats.get(pair[0],null))
			var chapters = report.get("prior_chapters",[])
			if chapters is Array:
				for chapter in chapters:
					if not chapter is Dictionary: continue
					var chapter_score = chapter.get("score",{})
					if not chapter_score is Dictionary: chapter_score={}
					result.append("本局此前章节：%s · %s 级 · %s 分" % [_label(str(chapter.get("outcome",""))),_value(chapter_score,"grade"),_value(chapter_score,"total")])
	if result.is_empty(): result.append("历史统计不完整" if incomplete else "本局无此项记录")
	return result

func _append_records(result: Array[String], title: String, value) -> void:
	if value is Array and not value.is_empty():
		for item in value:
			var name: String = {"craft":"实际制造","quest":"完成委托"}.get(str(item),_display(item)) if title=="成果标签" else _display(item)
			result.append(title+"："+name)
	elif value is Dictionary and not value.is_empty():
		for key in value: result.append(title+" · "+_label(str(key))+"："+_display(value[key]))
	else: result.append(title+"："+_display(value))

func _dict(key: String) -> Dictionary:
	var value = report.get(key,{})
	return value if value is Dictionary else {}
func _value(data: Dictionary, key: String) -> String:
	if not data.has(key) or data[key]==null: return "未知"
	return _number(data[key]) if data[key] is int or data[key] is float else str(data[key])
func _number(value) -> String:
	if value is float and is_finite(value) and value==floor(value): return "%.0f" % value
	return str(value)
func _display(value) -> String:
	if value == null: return "历史统计不完整"
	if value is Dictionary:
		var parts: Array[String] = []
		for key in value:
			if str(key) in ["id","uid","visit_id","run_id","report_id"]: continue
			parts.append(_label(str(key))+" "+_display(value[key]))
		return "；".join(parts) if not parts.is_empty() else "无"
	if value is Array:
		var parts: Array[String] = []
		for item in value: parts.append(_display(item))
		return "、".join(parts) if not parts.is_empty() else "无"
	if value is bool: return "是" if value else "否"
	return _label(value) if value is String else _number(value)

func _ratio(value) -> String:
	return "%0.1f%%" % (float(value)*100.0) if value is float or value is int else "未知"
func _label(key: String) -> String:
	if EXTRA_LABELS.has(key): return EXTRA_LABELS[key]
	if LABELS.has(key): return LABELS[key]
	for i in range(key.length()):
		if key.unicode_at(i)>127: return key
	return "未标注记录"
func _item_amounts(value) -> String:
	if not value is Dictionary: return "历史统计不完整"
	var parts: Array[String] = []
	for id in value:
		var name := _content_name("cards",str(id),_label(str(id)))
		parts.append("%s × %s" % [name,_number(value[id])])
	return "、".join(parts) if not parts.is_empty() else "无"
func _content_name(table: String, id: String, fallback: String) -> String:
	if is_instance_valid(catalog) and catalog.has_method("entry"):
		var entry = catalog.entry(table,id)
		if entry is Dictionary and entry.get("name",null) is String: return entry.name
	return fallback
func _node_name(id: String) -> String:
	var name := _content_name("nodes",id,"")
	return name if name!="" else _content_name("story_nodes",id,"事件危机")
func _origin() -> String:
	var id := str(report.get("origin",""))
	var origins = context.get("origins",{})
	if origins is Dictionary and origins.get(id,{}) is Dictionary and origins.get(id,{}).get("name",null) is String: return origins[id].name
	return {"strong":"强壮之人","fool":"愚者","restless":"多动症","hoarder":"囤积癖","zealot":"战斗狂热","skeptic":"无魔之人"}.get(id,"未知出身")
func _mode() -> String: return {"challenge":"挑战模式","story":"剧情模式","tutorial":"新手教程"}.get(str(report.get("mode","")),_value(report,"mode"))
func _outcome() -> String:
	if report.get("outcome_name",null) is String: return report.outcome_name
	return {"survived":"完成航程","dead":"沉入深潮","death":"沉入深潮","lost":"迷失","abandoned":"主动放弃","retreated":"末站撤离","retreat":"末站撤离","chapterComplete":"章节完成"}.get(str(report.get("outcome","")),_label(str(report.get("outcome",""))))
func show_analysis() -> void:
	page_index=1; _tab=0; _draw_page()
func show_logs() -> void:
	page_index=0; _review=true; paused=true; scroll_position=0; _end_time=0; _draw_page()
func toggle_pause() -> void:
	end_hold(); paused = not paused
	if is_instance_valid(_pause_button): _pause_button.text="继续" if paused else "暂停"
func begin_hold() -> void:
	if page_index != 0: return
	_held=true; _hold_time=0; accelerating=false
func end_hold() -> void:
	_held=false; _hold_time=0; accelerating=false
func max_scroll() -> float:
	if not is_instance_valid(_scroll): return 0
	var bar := _scroll.get_v_scroll_bar()
	return maxf(0,bar.max_value-bar.page)
func _process(delta: float) -> void:
	if page_index != 0 or not is_instance_valid(_scroll): return
	if _held:
		_hold_time += delta; accelerating = _hold_time >= HOLD_THRESHOLD
	if not paused:
		scroll_position=minf(max_scroll(),scroll_position+SPEED*delta*(6.0 if accelerating else 1.0))
		_syncing_scroll=true
		_scroll.scroll_vertical=int(scroll_position)
		_syncing_scroll=false
		if scroll_position >= max_scroll():
			_end_time+=delta
			if not _review and _end_time >= 2.0: show_analysis(); return
	_speed_label.text="回看已暂停 · 滚轮 / 拖动回看" if paused else ("长按加速 ×6 · 松开恢复" if accelerating else "自动慢速播放 · 长按日志或空格 0.35 秒加速 ×6 · 松开恢复")
func _over_button(position: Vector2) -> bool:
	for button in find_children("*","BaseButton",true,false):
		if button.is_visible_in_tree() and button.get_global_rect().has_point(position): return true
	return false
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): end_hold(); return
	if event is InputEventKey and event.keycode == KEY_SPACE:
		if page_index != 0: end_hold(); return
		if event.pressed and not event.echo: begin_hold()
		elif not event.pressed: end_hold()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed: end_hold()
		elif page_index == 0 and not _over_button(event.position): begin_hold()
	elif event is InputEventScreenTouch:
		if not event.pressed: end_hold()
		elif page_index == 0 and not _over_button(event.position): begin_hold()
func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_VISIBILITY_CHANGED: end_hold()
