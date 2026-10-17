extends SceneTree
const Content = preload("res://narrative/narrative_content.gd")
const Narrative = preload("res://narrative/narrative_session.gd")
const Player = preload("res://story/story_player.gd")
var failures := 0
var total := 0
func check(ok: bool, reason: String) -> void:
 total += 1
 if not ok:
  failures += 1
  printerr("FAIL: " + reason)
func play(narrative, number: int, picks: Array = []) -> Dictionary:
 var beat: Dictionary = narrative.next_beat(number, "navigation")
 check(not beat.is_empty(), "mandatory beat %d" % number)
 if beat.is_empty(): return {}
 narrative.begin(str(beat.id))
 var player := Player.new()
 var result := {}
 player.completed.connect(func(value): result.merge(value, true))
 check(player.load_story(narrative.prepare_scene()).ok, "scene validates %d" % number)
 var guard := 0
 while player.get_view().status == "playing" and guard < 1500:
  guard += 1
  var node: Dictionary = player.get_view().node
  var choices: Array = node.get("choices", [])
  if choices.is_empty(): player.advance()
  else:
   var selected: String = str(choices[0].id)
   for c in choices:
    if picks.has(str(c.id)): selected = str(c.id)
   check(player.choose(selected).ok, "valid selected choice " + selected)
 var changes: Dictionary = narrative.finish(result)
 check(narrative.error.is_empty(), "complete valid path %d: %s" % [number,narrative.error])
 return changes
func _init() -> void:
 call_deferred("run")
func run() -> void:
 var content := Content.new()
 check(content.load_content(), "content loads")
 check(content.length == 11, "story has eleven nodes")
 check(content.beats.size() == 11, "every node has a mandatory scene")
 var narrative := Narrative.new(content)
 narrative.new_save("chapter1")
 check(not narrative.next_beat(1,"navigation").is_empty(), "node one before departure")
 if content.length != 11:
  quit(1); return
 for number in range(1,12):
  play(narrative, number, ["n04_join","n05_reason","n06_investigate","n06_hack","n06_ned_b", "n07_investigate","n07_storage", "n08_investigate","n08_kohl", "n09_investigate","n09_ryan","n09_watch", "n10_investigate","n10_report", "n11_investigate","n11_core"])
  check(narrative.next_beat(number,"navigation").is_empty(), "completed node cannot replay")
 check(narrative.applied_count() == 11, "normal route visits eleven scenes")
 check(narrative.affinity().get("celine",0) == 9, "exclusive reason/report trust")
 check(narrative.affinity().get("ned",0) == 3, "exclusive Ned B trust")
 check(narrative.data.state.clues.has("C-5"), "compass route gets C5")
 check(narrative.data.state.items.has("学者骨质罗盘"), "story item acquired")
 var before := narrative.export_data()
 narrative.finish({"choices":[]})
 check(narrative.export_data() == before, "duplicate callback is idempotent")
 var restored := Narrative.new(content)
 check(restored.load_data(before), "narrative round trip")
 check(restored.export_data().state == before.state, "all story state survives reload")
 # All bad endings and absence of fallback deadlocks.
 for ending in [1,2,3,4]:
  var branch := Narrative.new(content)
  branch.new_save("BE")
  if ending == 1:
   play(branch,4,["n04_refuse"])
  elif ending == 2:
   play(branch,5,["n05_fight"])
  elif ending == 3:
   for n in [6,7,8]: play(branch,n,["n%02d_rest" % n])
  else:
   play(branch,9,["n09_investigate","n09_ryan","n09_confront"])
  check(branch.data.state.ending == "BAD_END_%d" % ending,"ending %d exclusive" % ending)
 var missing := Narrative.new(content)
 missing.new_save("missing")
 missing.begin("C1-N10")
 var scene: Dictionary = missing.prepare_scene()
 var gated := 0
 for node in scene.nodes:
  for c in node.get("choices",[]):
   if c.get("disabled",false): gated += 1
 check(gated == 2,"both unavailable investigations disabled")
 var rejected := missing.export_data()
 missing.finish({"choices":[{"node_id":"forged","choice_id":"n10_report"}]})
 check(not missing.error.is_empty() and missing.export_data() == rejected,"forged result has no effects")
 missing.current_beat = {}; missing.current_scene = {}
 play(missing,10,["n10_investigate","return_to_rest"])
 check(missing.data.state.rest_count == 1,"fallback consumes one narrative action")
 # App saves story and gameplay together, with guarded mode entry.
 var app = load("res://scenes/main.tscn").instantiate()
 app.persistence = false
 root.add_child(app)
 await process_frame
 app.narrative_store = load("res://adapters/narrative_store.gd").new("user://chapter1-test-"+str(Time.get_ticks_usec()))
 app.pending_narrative = {"mode":"new","label":"paired"}
 app.handle_command("new",{"mode":"story","origin":"strong","seed":22,"difficulty":"standard"})
 check(app.session.state.length == 11,"story core length is eleven")
 check(app.narrative_playing,"first node opens immediately")
 var id: String = app.narrative_store.active_id()
 var saved: Dictionary = app.narrative_store.read(id)
 check(saved.get("gameplay",{}).get("state",{}).get("length",0) == 11,"slot owns gameplay snapshot")
 var game_before: Dictionary = app.session.snapshot()
 app.handle_command("voyage",{})
 check(game_before == app.session.snapshot(),"mandatory story locks gameplay")
 app._close_narrative()
 app.narrative.current_beat = {}; app.narrative.current_scene = {}
 app.session.screen = "home"
 app.pick_narrative(id)
 check(app.session.screen == "game" and app.narrative_playing,"load restores paired run and pending story")
 app._close_narrative()
 app.narrative.current_beat = {}; app.narrative.current_scene = {}
 app.session.state = {}; app.session.screen = "home"
 app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22,"difficulty":"standard"})
 check(not app.narrative_playing,"challenge has no story")
 check(not app.narrative.has_save(),"challenge has no attached story slot")
 app.local_panel = "settings"; app.settings_tab = "narrative"; app.render()
 check(app.layout.find_child("NarrativeName",true,false) == null,"challenge settings cannot create story")
 app.queue_free()
 await process_frame
 print("CHAPTER1: %d checks, %d failures" % [total,failures])
 quit(0 if failures == 0 else 1)
