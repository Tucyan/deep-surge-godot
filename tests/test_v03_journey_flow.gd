extends SceneTree
var failures := 0
const Session=preload("res://core/game_session.gd")
func check(ok: bool,why: String) -> void:
	if not ok: failures+=1;printerr("FAIL: "+why)
func act(s,command: String,args: Dictionary={}) -> bool:
	var ok: bool=s.dispatch(command,args)
	check(ok,command+" "+s.error)
	return ok
func _init() -> void:
	var catalog=load("res://content/catalog.gd").new(); check(catalog.load_catalog(),"catalog")
	var s=Session.new(catalog); act(s,"new",{"mode":"challenge","origin":"fool","seed":22})
	s._auto_advancing=true
	# Isolate progression from strategy quality. All movement/events use real dispatch;
	# an ample test character ensures Boss gates and lifecycle can be inspected alive.
	s.state.player.hp_max=100;s.state.player.hp=100;s.state.player.damage=100
	var transitions: Array=[]; var checked_stages: Array=[]
	for step in range(500):
		if s.phase()=="finished":break
		var stage: String=s.phase()
		if stage not in checked_stages:
			var saved: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()))
			var other=Session.new(catalog)
			check(other.restore(saved),"JSON restore at"+stage+" "+other.error)
			checked_stages.append(stage)
		if stage=="navigation":
			s.state.player.hunger=100;s.state.player.hydration=100;s.state.player.sanity=100
			var before: int=s.state.voyage
			if before in [6,16]:
				transitions.append(before)
				check(s.state.journey.layer_voyage==1,"layer local reset")
				check(s.state.journey.cleared.size()==(1 if before==6 else 2),"previous Boss cleared once")
				check(not s.state.boss_defeated and s.profile.points==0,"no early clear or metareward")
			if before in [5,15,25]: check(s.state.candidates.size()==1 and s.state.candidates[0].boss,"layer Boss gate")
			if not act(s,"voyage",{"id":s.state.candidates[0].visit_id}):break
		elif stage=="preparation":
			if not act(s,"enter"):break
		elif stage=="story":
			if s.state.story_step=="result" and s.state.node.get("boss",false):
				check(s.view().journey.completed_layers.size()==int(s.state.journey.layer_index),"Boss win does not complete layer before survival settlement")
			if s.state.story_step!="choice":
				if not act(s,"advance"):break
			elif s.state.node.has("monster"):
				if not act(s,"fight"):break
			elif s.state.node.kind=="shop":
				if not act(s,"shop_enter"):break
			else:
				var selected: Dictionary={}
				for option in s.Encounter.options(s):
					for args in s.Encounter.arguments(s,option):
						if s.Encounter.reason(s,option,args)=="":selected=args;break
					if not selected.is_empty():break
				if selected.is_empty():check(false,"event has legal choice");break
				if not act(s,"option",selected):break
		elif stage=="battle":
			if not act(s,"battle_action",{"action":"attack"}):break
		elif stage=="interaction":
			if not act(s,"shop_leave"):break
		elif stage=="aftermath":
			if not act(s,"end_voyage"):break
		elif stage=="discard":
			var card: Dictionary=s.state.hand[0]
			if not act(s,"discard",{"uid":card.uid}):break
	check(transitions==[6,16],"both layer boundaries execute")
	check(s.phase()=="finished" and s.state.result=="survived" and s.state.completed==25,"full25-voyage progression")
	check(s.state.journey.cleared.size()==3 and s.profile.points==25,"final reward granted exactly once")
	var terminal: Dictionary=s.snapshot();var restored=Session.new(catalog)
	check(restored.restore(JSON.parse_string(JSON.stringify(terminal))),"terminal save restores")
	check(restored.profile.points==25,"restore does not grant reward twice")
	print("V03 JOURNEY FLOW: %s" % ("PASS" if failures==0 else "FAIL"));quit(failures)
