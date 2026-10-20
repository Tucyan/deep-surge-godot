extends RefCounted
## Read-only guide. Camera bindings come from local preferences, not rule state.
const W = preload("res://presentation/widgets.gd")

static func build(parent: Node, settings: RefCounted, story_mode_visible: bool = false) -> void:
	W.text(parent,"游戏说明",28,W.GOLD)
	W.text(parent,"选择页签查看操作与流程；内容可上下滚动。右上角 X 返回游戏。",16,W.MUTED)
	var tabs := TabContainer.new()
	tabs.name="GameHelpTabs"
	tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	tabs.use_hidden_tabs_for_min_size=false
	tabs.add_theme_font_size_override("font_size",18)
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color=Color("203d49")
	tab_style.content_margin_left=16; tab_style.content_margin_right=16
	tab_style.content_margin_top=16 if settings.mobile else 10
	tab_style.content_margin_bottom=tab_style.content_margin_top
	tabs.add_theme_stylebox_override("tab_selected",tab_style)
	var idle: StyleBoxFlat=tab_style.duplicate()
	idle.bg_color=Color("0c1d26")
	tabs.add_theme_stylebox_override("tab_unselected",idle)
	parent.add_child(tabs)
	_add_tab(tabs,"手机操作",[
		["轻点与查看","轻点按钮或目的地进行选择；轻点手牌查看说明，战斗中轻点资源牌可选择附魔材料。轻点生存牌不会直接消耗。"],
		["使用与弃牌","按住手牌 0.05 秒，再向上拖出手牌区边缘后松开：生存牌用于恢复，战斗牌用于出牌，轮末整理时用于弃置。滑回手牌区可取消；在手牌区内横向拖动可排序。"],
		["安装与加燃料","在导航、准备或收尾阶段，按住设备牌拖到完好空格安装；拖到同类Ⅰ级设备上可升级。木头或尸体可拖到已安装的灯上加燃料。请对准实际筏格；无效落点不会消耗。"],
		["战斗操作","轻点资源牌，再拖出攻击或防御操作牌打出附魔；也可用战斗区的按钮选择行动、查看预览，再点“确认行动”。选择与预览不消耗，确认后按费用扣除。"],
		["木筏与镜头","轻点筏格查看可用操作，轻点扩建虚影后再点“确认新建”。在场景中单指拖动旋转，双指捏合缩放；左侧按钮可切换俯视 / 斜俯视或复位。设置中锁定视角后不能拖动镜头。"],
		["阅读长说明","在说明正文区域上下滑动阅读；切换页签可查看电脑操作和完整游戏流程。"]
	])
	_add_tab(tabs,"电脑操作",[
		["点击与查看","鼠标悬停手牌可看详情。左键点击生存牌可使用，轮末整理时点击可弃置；战斗中点击资源牌选择附魔材料，点击攻击或防御选择行动并查看预览。请先确认当前阶段和费用。"],
		["长按与拖动","按住左键 0.2 秒后拖动手牌可调整顺序。导航、准备或收尾时，把设备牌拖到完好空格安装，或同类Ⅰ级设备上升级；木头、尸体可拖到灯上加燃料。双击设备牌可自动安装到可用空格。"],
		["战斗操作","选择资源后，可双击攻击或防御操作牌快速确认附魔；也可通过战斗区的行动按钮查看预览，再点“确认行动”。取消预览不消耗资源或 AP。"],
		["当前镜头按键","在场景区域按住%s拖动旋转，按住%s拖动水平平移；滚轮缩放，%s 键平滑复位。可在设置中修改绑定或锁定视角；左侧按钮也能切换视角和复位。" % [settings.mouse_button_name(settings.camera_orbit_button),settings.mouse_button_name(settings.camera_pan_button),OS.get_keycode_string(settings.camera_reset_key)]],
		["木筏与面板","点击筏格打开安装、升级或修补等操作；点击扩建虚影查看费用后确认新建。点右上角问号查看本说明，齿轮打开设置，X 关闭面板。正文可用鼠标滚轮或右侧滚动条阅读。"]
	])
	_add_tab(tabs,"游戏流程",[
		["1 · 开局与目标","初次游玩可先体验新手教程。正式航程选择难度、出身和起手资源；挑战模式航行次数随机，末站为 Boss，击败后还需完成轮末结算。" + ("剧情模式按固定航线推进并穿插剧情。" if story_mode_visible else "") + "生命或精神归零会失败。"],
		["2 · 导航与出发","查看候选目的地及环境，选择后出发。出发支付精神（SAN）航耗，有燃料的灯可恢复精神；抵达后先进入准备阶段，再进入节点事件。出发前也可打捞、制造、使用补给或经营木筏。"],
		["3 · 准备与经营","导航、准备、收尾共享本航次的基地 AP，出发与战后不会刷新。打捞获取资源，制造将材料变成卡牌；制造通常花 1 AP，设备还需安装，安装为 0 AP。设备生产在后续航次开始时按周期推进。"],
		["4 · 处理事件","先阅读事件，再选择探索、领取、交易、迎战或离开等当前可用选项。商店可买卖，结束交易需离店；事件、战斗或商店完成后确认节点结果，进入收尾。收起说明或面板不会跳过事件。"],
		["5 · 战斗回合","战斗 AP 与基地 AP 独立，每回合刷新。留意敌人意图，选择攻击、格挡、战术牌或恢复牌；资源可附魔攻击 / 格挡，以预览显示的费用和效果为准。结束回合后敌人行动；战斗 AP 耗尽且无有效免费牌时自动结束回合。"],
		["6 · 收尾与结束航行","收尾可用剩余基地 AP 补给、制造、修补或扩建。准备妥当后点“结束航行”；设置中的“自动结束航程”默认开启，无有效基地操作时会自动结束。关闭后需手动结束，不影响战斗自动结束回合。"],
		["7 · 轮末整理与生存","先处理筏格老化和临时增益到期；手牌超容量时必须弃到达标，然后才扣食水。整理阶段不能靠使用补给或制造腾位置，请在收尾提前使用。普通资源叠牌只合并显示；弃贝币会丢掉全部余额，污染牌不能直接弃置。"],
		["8 · 下一航次与终点","轮末扣除饱食、水分后，降到 0 的项目会各扣生命。存活才进入下一轮：基地 AP 刷新、完好设备推进生产、领取涌泉，再选择新目的地。末站也要完成生存结算，之后查看航程结果。"],
		["生存提醒","随时关注生命、饱食、水分与精神。食物、淡水、灯火余温和包扎包可按允许阶段恢复；破损筏格上的设备停用，应及时修补。按钮不可用时查看提示，先核对阶段、材料和 AP。"]
	])
	tabs.current_tab=0 if settings.mobile else 1

static func _add_tab(tabs: TabContainer, title: String, sections: Array) -> void:
	var scroll := ScrollContainer.new()
	scroll.name=title
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",12)
	scroll.add_child(body)
	for section in sections:
		W.text(body,section[0],20,W.GOLD)
		W.text(body,section[1],18,W.INK)
