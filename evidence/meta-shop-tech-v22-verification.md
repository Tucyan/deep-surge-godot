# 全屏局外商店与两层科技 v22 验证

日期：2026-10-18。内容版本 `godot-flow-v02-22`，schema 2，随机算法 `xorshift32-godot-v1`。

用户要求沿用全屏图鉴效果重设计局外商店，并把科技改成消耗涌潮点点亮、达到数量门槛开放下一层的两层结构。当前试测：每层3点，第一层任意2点开放第二层；费用第一层3/4/6，第二层9/10/12。节点效果、实现决策和存档边界见[机制说明](../docs/meta-shop-and-tech.md)。

## 核心与接口

`test_tech_tiers.gd` 从旧内容“Six nodes in two tiers”失败开始，新增数据与规则后为 `tech_tiers: 0 failures`。验证：任选第一层节点、0/1节点时第二层拒绝、2节点时开放、独立扣费、绕过UI直接命令仍受限、重复点亮不扣费、活动局禁止点亮、HP/精神/战斗AP增益在新局生效、同版本档案与活动局恢复、旧v21拒绝、重复及越层科技档案拒绝。ActionQuery和view反复查询完整快照不变。

同次执行以下命令（均在工程目录，退出码0）：

```powershell
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_tech_tiers.gd
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_action_query.gd
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_agent_session.gd
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_save.gd
node --test tests/content.test.mjs tests/node_content.test.mjs
python -m unittest discover -s tests -p test_agent_stdio.py -v
```

结果：科技0失败、ACTION QUERY / AGENT SESSION / SAVE RECOVERY均PASS、Node 15/15、Python 3/3。

## GPU与布局

```powershell
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/verify_meta_shop.gd
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path . --script res://tests/verify_encyclopedia.gd
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_clean_ui.gd
```

结果：`meta_shop GPU: 0 failures`、`encyclopedia GPU: 0 failures`、`CLEAN HUD: PASS`。GPU使用 NVIDIA RTX4060 Laptop / OpenGL Compatibility。

- 商店从旧布局“Shop has preview grid”失败开始；科技从缺少TechTree失败开始。最终验证全屏、左宽右窄、三列两行、上图下标题、价格与文字边界、分页和末页空位；四组尺寸：1600×900/100%、1280×720/100%、1280×720/125%、1920×820/125%。
- 实际鼠标点击图片与标题选择商品，实际点击购买扣费、限购封锁、可重复成长商品继续可买、余额不足与活动航程禁买、X关闭。浏览前后完整session快照一致。
- 科技六个圆形节点；实际鼠标选择和点亮第一层两个节点，第二层立即开放，再点亮长矛工艺，余额依次40→37→33→24；已点亮节点按钮禁用。
- 两个SVG图标实际解析，无纯色占位；未开放祝福不显示。
- 人工检查了1280×720/125%的商品和科技截图，以及点亮第二层后的宽屏截图。

截图：`meta-shop-1280x720-125.png`、`meta-shop-tech-1280x720-125.png`、`meta-shop-tech-tier-two-unlocked.png`、`meta-shop-tech-lit.png`，其余尺寸同名前缀。图鉴旧行为回归通过。

## 完整路线

```powershell
python tools/validate_survival_discard.py --trace-prefix tech-v22
& 'C:/Program Files/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/test_routes.gd
```

均退出码0；13条新版本轨迹共1998步，生成时跨JSON边界重放一致，`test_routes.gd`再次重放为 `ROUTES: PASS`，终局保存恢复与卡牌守恒通过。标准挑战种子22/39/9/73/1000/7919/20261016/4294967295、标准剧情22、困难与噩梦各挑战/剧情22。三档剧情均完成15站；挑战既含成功也含死亡路线。明细为 `tech-v22-runs.json`，逐步轨迹为 `tech-v22-*.trace.json`。旧v21轨迹保留为历史，没有修改其版本或hash以伪造重放。

资产登记、依赖引用、7项新增或直接相关资源SHA-256校验通过；Git diff whitespace检查采用CRLF规则通过。未下载依赖，未提交、推送或改玩家存档。未验证移动端独立导出、任意极端窗口比例及长期平衡性；节点数、费用和门槛仍为试测参数。
