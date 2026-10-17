extends SceneTree
var app
var failures := 0
func _init():
    call_deferred("run"); call_deferred("watchdog")
func watchdog():
    await create_timer(40).timeout
    printerr("HAND STACK HOVER: timeout"); quit(2)
func check(ok: bool, text: String):
    if not ok: failures+=1; printerr("FAIL: "+text)
func settle():
    for i in range(4): await process_frame
func has_property(object: Object, key: String) -> bool:
    return object.get_property_list().any(func(p):return p.name==key)
func fan(): return app.find_child("hand_fan",true,false)
func run():
    root.size=Vector2i(1280,720)
    app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
    app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22}); await settle()
    check(has_property(app.hand_layout,"hover_mode"),"local hover preference exists")
    check(ResourceLoader.exists("res://presentation/card_stack.gd"),"formal independent stack backplates exist")
    if failures>0:
        app.queue_free(); await process_frame; quit(1); return
    var fixture=app.session.snapshot(); fixture.state.hand.clear(); fixture.state.coins=0
    for id in ["wood","iron","rope"]: app.session.I.give(fixture.state,id,6,false,"stack-hover-fixture")
    for i in range(12): app.session.I.give(fixture.state,"food",1,false,"stack-hover-fixture")
    check(app.session.restore(fixture),"restore display fixture")
    app.hand_layout.auto_sort=false; app.hand_layout.stack_resources=true
    app.handle_command("resume"); await settle()
    var before=app.session.snapshot()
    for mode in ["spread","raise"]:
        app.hand_layout.hover_mode=mode; app.render(); await settle()
        var hand=fan(); hand.focus_card(-1); hand._process(.7)
        var index=hand.cards.find_custom(func(c):return c.id=="wood")
        check(index>=0,"resource stack present")
        var backing=hand.stack_bases[index]
        check(backing!=null and backing.get_parent()==hand,"rear cards are siblings, outside floating front")
        check(backing.layer_count==2,"bounded decorative layers")
        var rest=backing.position
        hand.focus_card(index); hand._process(.7)
        check(hand.tiles[index].position.y<backing.position.y,"only front card rises")
        check(is_equal_approx(backing.position.y,rest.y),"rear cards stay on the table")
        check(backing.offset_direction==-1,"rear layers expose on the left")
        var quantity=hand.tiles[index].find_child("StackQuantity",true,false)
        check(quantity.anchor_left>=.4 and quantity.horizontal_alignment==HORIZONTAL_ALIGNMENT_RIGHT and not quantity.has_theme_stylebox_override("normal"),"readable right quantity without backing")
        if mode=="raise":
            for j in range(hand.tiles.size()):
                check(is_equal_approx(hand.target_positions[j].x,hand.base_x[j]),"layer hover does not spread neighbours")
            check(hand.tiles[index].z_index>hand.tiles[index+1].z_index and backing.z_index==1,"only front raises drawing layer")
        else:
            check(hand.target_positions[index+1].x>hand.base_x[index+1],"spread mode clears occluding neighbour")
            var neighbour=hand.stack_bases[index+1]
            var rear_extent=neighbour.OFFSET*neighbour.layer_count*neighbour.scale.x
            check(hand.target_positions[index+1].x-rear_extent+0.01>=hand.target_positions[index].x+hand.card_face_width,"spread also clears next stack's exposed left layers")
            check(hand.tiles[index].z_index==1,"spread mode retains right-on-top ordering")
        var saved=[]; var rear_saved={}
        for j in range(hand.stack_bases.size()):
            if hand.stack_bases[j]!=null:
                rear_saved[j]=hand.stack_bases[j].position
                hand.stack_bases[j].position=Vector2(10000,0)
        for tile in hand.tiles: saved.append(tile.position); tile.position=Vector2(10000,0)
        hand.tiles[index].position=Vector2(100,20); hand.tiles[index+1].position=Vector2(130,20)
        check(hand.hit_card(Vector2(170,80))==(index if mode=="raise" else index+1),"hit follows actual draw order")
        for j in range(hand.tiles.size()): hand.tiles[j].position=saved[j]
        for j in rear_saved: hand.stack_bases[j].position=rear_saved[j]
        var visual=hand.capture_visual(); var uid=hand.cards[index].uid
        app.render(); await settle()
        check(fan().cards[fan().hovered].uid==uid,"rebuild preserves hover identity")
        check(fan().stack_bases[index].position.distance_to(visual.stack_positions[uid])<.2,"rebuild preserves rear position")
        hand=fan()
        var point=hand.global_position+hand.tiles[index].position+Vector2(20,60)
        var motion=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
        root.push_input(motion,true); await process_frame
        check(hand.hovered==index,"native pointer focuses the stack front")
        for down in [true,false]:
            var click=InputEventMouseButton.new(); click.position=point; click.global_position=point
            click.button_index=MOUSE_BUTTON_LEFT; click.pressed=down; root.push_input(click,true); await process_frame
        await settle()
        check(app.ui_state.get("card","")==uid,"native click inspects the representative stack UID")
    var hand=fan(); hand.focus_card(-1); hand._process(.7)
    var start=hand.tiles[0].position+Vector2(20,60)
    hand._begin_press(0,start); hand._process(.21)
    var drag=InputEventMouseMotion.new(); drag.global_position=hand.global_position+Vector2(hand.base_x[2]+20,start.y)
    hand._input(drag)
    for j in range(1,hand.tiles.size()):
        if hand.stack_bases[j]!=null:
            check(is_equal_approx(hand.stack_targets[j].x,hand.target_positions[j].x),"drag preview moves front and rear to same slot")
    hand.cancel_gesture(); hand._process(.7)
    var path="user://hand-stack-hover-test.cfg"
    app.hand_layout.path=path; app.hand_layout.hover_mode="raise"
    check(app.hand_layout.save_preferences()==OK,"save local preference")
    var reloaded=load("res://presentation/hand_layout.gd").new(); reloaded.path=path; reloaded.load_preferences()
    check(reloaded.hover_mode=="raise","hover preference survives reload")
    var config=ConfigFile.new(); config.set_value("hand","hover_mode","invalid"); config.save(path)
    reloaded.load_preferences(); check(reloaded.hover_mode=="spread","invalid preference falls back")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    app.settings_tab="game"; app.handle_ui("local_panel","settings"); await settle()
    var picker=app.find_child("HandHoverMode",true,false)
    check(picker is OptionButton and picker.item_count==2,"settings exposes two hover choices")
    if picker!=null:
        picker.select(0); picker.item_selected.emit(0); await settle()
        check(app.hand_layout.hover_mode=="spread","settings changes active hover mode")
    check(app.session.snapshot()==before,"decorations/hover/settings leave game and RNG unchanged")
    app.queue_free(); await process_frame
    print("HAND STACK HOVER: "+("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
