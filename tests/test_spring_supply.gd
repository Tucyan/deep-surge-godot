extends SceneTree
const Session=preload("res://core/game_session.gd")
var catalog
var failures:=0
var saw_random_wood:=false
var saw_weather_bonus:=false
func check(ok: bool, why: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+why)
func normalized(value):
	return JSON.parse_string(JSON.stringify(value))
func _init() -> void:
	catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	for mode in ["challenge","story"]:
		for seed in [0,7,22,42,20261015,987654321,2147483647,4294967295]:
			var s=Session.new(catalog)
			check(s.dispatch("new",{"mode":mode,"origin":"fool","seed":seed}),"new run")
			check(s.state.hand.size()==7 and s.state.hand.all(func(c):return c.source!="spring"),"first voyage retains random seven with no spring")
			# Isolated round transition fixture; no change to production or capacity.
			s.state.hand=[]; s.state.phase="aftermath"; s.state.ap=0
			s.state.node=catalog.entry("nodes","camp"); s.state.node.visit_id="spring-fixture"
			var before: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()))
			# Resolve the real next-round weather on a restored copy before deriving
			# the supply expectation. Harvest precedes the fixed wood card and uses
			# one extra initial-stream draw; it must not mask base production checks.
			var weather=Session.new(catalog)
			check(weather.restore(before),"weather fixture restores")
			weather.EnvironmentRules.end_round(weather)
			weather.Campaign.advance(weather)
			weather.EnvironmentRules.start_round(weather)
			var bonus: int=1 if weather.EnvironmentRules.active(weather.state,"spring") else 0
			if bonus==1: saw_weather_bonus=true
			var expected: Array=[]
			var rng: Dictionary=before.state.rng.duplicate(true)
			if bonus==1: expected.append(s.R.pick(rng,"initial",s.I.RESOURCES))
			expected.append("wood")
			expected.append(s.R.pick(rng,"initial",s.I.RESOURCES))
			var restored=Session.new(catalog)
			check(restored.restore(before),"save before supply")
			check(s.dispatch("end_voyage") and restored.dispatch("end_voyage"),"settle first voyage")
			var cards: Array=s.state.hand.filter(func(c):return c.source=="spring")
			check(s.state.voyage==2 and cards.size()==2+bonus,"base two cards plus actual harvest bonus before second navigation")
			check(cards[bonus].id=="wood","fixed production guarantees wood after any harvest bonus")
			check(cards.map(func(c):return c.id)==expected,"ordinary supply and harvest draw from the full equal-weight resource pool")
			check(not s.EnvironmentRules.active(s.state,"spring"),"harvest effect is consumed by supply exactly once")
			var wood_count: int=cards.filter(func(c):return c.id=="wood").size()
			if wood_count>1: saw_random_wood=true
			check(normalized(s.state.hand)==normalized(restored.state.hand) and normalized(s.state.rng)==normalized(restored.state.rng),"restore before supply yields identical cards and RNG")
			check(int(s.state.rng.initial.cursor)-int(before.state.rng.initial.cursor)==1+bonus,"fixed wood consumes no draw; random supply and harvest each consume one")
			var after: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()))
			check(restored.restore(after) and restored.dispatch("resume") and restored.dispatch("close"),"save after supply and reopen")
			check(restored.state.hand==after.state.hand and restored.state.rng==after.state.rng,"load and UI cannot duplicate or reroll supply")
			check(s.state.stats.cards.get("wood",{}).get("sources",{}).get("spring",0)==wood_count,"guaranteed and random wood counted in statistics")
			var old: Dictionary=after.duplicate(true); old.content_version="godot-flow-v02-8"
			check(not restored.restore(old),"previous supply version rejected")
	check(saw_random_wood,"fixed seeds demonstrate that random cards can also contain wood")
	check(saw_weather_bonus,"fixed seeds exercise a real second-round harvest bonus")
	print("SPRING SUPPLY: %s" % ("PASS" if failures==0 else "FAIL")); quit(1 if failures>0 else 0)
