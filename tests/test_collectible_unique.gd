extends SceneTree
const Session=preload("res://core/game_session.gd")
const Collectibles=preload("res://core/collectible_rules.gd")
var failures:=0
var checks:=0
var catalog
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)

func _init() -> void:
	catalog=load("res://content/catalog.gd").new()
	check(catalog.load_catalog(),"加载藏品定义")
	var run_ids=["crimsonVial","sealedFishTin","tideTablet","copperStill","rescueBadge","redCoral"]
	var held_ids=["emberFuse","tideBoneBlade","sunkenCoin","hunterSpear","crackedCarapace","scavengerSatchel","homeCompass","sailorsKnot","foldingRule","kelpRation","barbedBundle","drifterQuiver"]
	for id in run_ids: check(catalog.entry("relics",id).get("unique","")=="run","run唯一标记："+id)
	for id in held_ids: check(catalog.entry("relics",id).get("unique","")=="held","持有唯一标记："+id)
	for id in ["glowConch","drifterMedkit"]: check(not catalog.entry("relics",id).has("unique"),"不唯一遗物无唯一标记："+id)
	var s=Session.new(catalog)
	check(s.dispatch("new",{"mode":"challenge","origin":"strong","seed":77}),"新开局")
	var before=JSON.stringify(s.snapshot())
	check(Collectibles.acquire(s,"crimsonVial"),"获得run唯一遗物")
	var vial_uid: String=s.state.collectibles.items[0].uid
	check(not Collectibles.acquire(s,"crimsonVial"),"仍持有時拒绝重复run唯一遗物")
	check(Collectibles.discard(s,vial_uid),"丢弃run唯一遗物")
	before=JSON.stringify(s.snapshot())
	check(not Collectibles.acquire(s,"crimsonVial"),"丢弃后仍按历史拒绝run唯一遗物")
	check(JSON.stringify(s.snapshot())==before,"拒绝重复前不改状态")
	check(Collectibles.acquire(s,"sealedFishTin"),"run唯一限制不同ID")
	check(Collectibles.acquire(s,"emberFuse"),"获得held唯一遗物")
	var fuse_uid: String=s.state.collectibles.items[-1].uid
	check(not Collectibles.acquire(s,"emberFuse"),"持有时拒绝重复held唯一遗物")
	check(Collectibles.acquire(s,"tideBoneBlade"),"held唯一允许不同ID")
	check(Collectibles.discard(s,fuse_uid),"丢弃held唯一遗物")
	check(Collectibles.acquire(s,"emberFuse"),"丢弃后held唯一遗物可重新获得")
	check(Collectibles.acquire(s,"glowConch") and Collectibles.acquire(s,"glowConch"),"无唯一遗物允许重复")
	var saved=JSON.parse_string(JSON.stringify(s.snapshot()))
	var copy=Session.new(catalog)
	check(copy.restore(saved),"唯一藏品历史可JSON保存并恢复")
	var duplicate=saved.duplicate(true)
	duplicate.state.collectibles.history[-1].id="crimsonVial"
	check(not copy.restore(duplicate),"校验历史中的run唯一重复")
	duplicate=saved.duplicate(true)
	duplicate.state.collectibles.items[1].id="crimsonVial"
	duplicate.state.collectibles.items[1].effects=duplicate.state.collectibles.items[0].effects.duplicate(true)
	duplicate.state.collectibles.history[1].id="crimsonVial"
	check(not Collectibles.valid(copy,duplicate.state),"状态校验拒绝重复run唯一实例")
	duplicate=saved.duplicate(true)
	var first_fuse=-1
	for index in range(duplicate.state.collectibles.items.size()):
		if duplicate.state.collectibles.items[index].id=="emberFuse":
			if first_fuse<0: first_fuse=index
	duplicate.state.collectibles.items[first_fuse].held=true
	check(not Collectibles.valid(copy,duplicate.state),"状态校验拒绝同时持有重复held唯一实例")
	var production=Session.new(catalog)
	check(production.dispatch("new",{"mode":"challenge","origin":"strong","seed":91}),"生产藏品回溯测试开局")
	var max_before: int=production.state.player.hp_max
	check(Collectibles.acquire(production,"crimsonVial"),"获得生产赤潮血酿")
	var production_item: Dictionary=production.state.collectibles.items[0]
	var production_uid: String=production_item.uid
	var history_before: Array=production.state.collectibles.history.duplicate(true)
	var effects_before: Dictionary=production_item.effects.duplicate(true)
	var grown_max: int=production.state.player.hp_max
	check(grown_max==max_before+3,"赤潮血酿获得时立即成长生命上限")
	check(Collectibles.discard(production,production_uid),"丢弃生产赤潮血酿")
	check(Collectibles.acquire(production,"crimsonVial",production_uid),"可重新持有原run唯一实例")
	check(production.state.player.hp_max==grown_max and production.state.collectibles.history==history_before,"同UID回持不重复成长且不追加历史")
	check(production.state.collectibles.items[0].effects==effects_before,"同UID回持保留效果剩余次数")
	var held_test=Session.new(catalog)
	check(held_test.dispatch("new",{"mode":"challenge","origin":"strong","seed":92}),"held唯一回持测试开局")
	check(Collectibles.acquire(held_test,"emberFuse"),"获得held唯一熔火引信")
	var old_uid: String=held_test.state.collectibles.items[0].uid
	check(Collectibles.discard(held_test,old_uid) and Collectibles.acquire(held_test,"emberFuse"),"丢弃后建立新的held唯一实例")
	check(not Collectibles.acquire(held_test,"emberFuse",old_uid),"同种另一个实例持有时拒绝回持旧实例")
	var bad_catalog=catalog.get_script().new()
	bad_catalog._tables=catalog._tables.duplicate(true)
	bad_catalog._tables.relics.glowConch.unique="sometimes"
	check(not Collectibles.valid_definitions({"glowConch":bad_catalog._tables.relics.glowConch}),"定义拒绝未知唯一策略")
	print("COLLECTIBLE UNIQUE: %s (%d checks)" % ["PASS" if failures==0 else "FAIL",checks])
	quit(failures)
