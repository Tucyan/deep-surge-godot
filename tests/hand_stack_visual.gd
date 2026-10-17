extends SceneTree
var app
var failures := 0
func _init():
    call_deferred("run"); call_deferred("watchdog")
func watchdog():
    await create_timer(40).timeout
    printerr("HAND STACK GPU: timeout"); quit(2)
func check(ok: bool, why: String):
    if not ok: failures+=1; printerr("FAIL: "+why)
func settle():
    for i in range(5): await process_frame
func shot(path: String):
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png("res://evidence/"+path+".png")==OK,"save "+path)
func run():
    root.size=Vector2i(1600,900)
    app=load("res://scenes/main.tscn").instantiate(); app.persistence=false; root.add_child(app); await settle()
    app.handle_command("new",{"mode":"challenge","origin":"strong","seed":22})
    var fixture=app.session.snapshot(); fixture.state.hand.clear(); fixture.state.coins=0
    for id in ["wood","iron","rope"]: app.session.I.give(fixture.state,id,6,false,"stack-gpu-fixture")
    for id in ["food","water"]: app.session.I.give(fixture.state,id,3,false,"stack-gpu-fixture")
    check(app.session.restore(fixture),"valid dense display fixture")
    app.hand_layout.stack_resources=true; app.hand_layout.auto_sort=true
    app.handle_command("resume"); app.world_view.motion=false; await settle()
    var before=app.session.snapshot()
    for cfg in [Vector3(1600,900,1),Vector3(1280,720,1.25)]:
        root.size=Vector2i(cfg.x,cfg.y); app.display_settings.ui_scale=cfg.z; app.apply_display_settings(false); await settle()
        for mode in ["spread","raise"]:
            app.hand_layout.hover_mode=mode; app.render(); await settle()
            var hand=app.find_child("hand_fan",true,false); hand.mouse_filter=Control.MOUSE_FILTER_IGNORE
            hand.focus_card(-1); hand._process(.7)
            var index=hand.cards.find_custom(func(c):return c.id=="iron")
            var backing=hand.stack_bases[index]; var rest=backing.position
            await shot("hand-stack-rest-%d-%s" % [cfg.x,mode])
            hand.focus_card(index); hand._process(.7); hand.tip.hide(); hand.dwell=-10
            check(backing.position.distance_to(rest)<.1,"only the top card floats")
            for tile in hand.tiles: check(app.get_global_rect().grow(2).encloses(tile.get_global_rect()),"front inside screen")
            var base_global=Rect2(hand.global_position+backing.hit_rect().position,backing.hit_rect().size)
            check(app.get_global_rect().encloses(base_global),"exposed left layers inside screen")
            await shot("hand-stack-hover-%d-%s" % [cfg.x,mode])
        app.settings_tab="game"; app.handle_ui("local_panel","settings"); await settle()
        var picker=app.find_child("HandHoverMode",true,false)
        check(picker!=null and picker.is_visible_in_tree(),"visible hover preference")
        var surface=app.find_child("ModalSurface",true,false)
        check(app.get_global_rect().grow(2).encloses(surface.get_global_rect()),"whole settings surface inside viewport: "+str(surface.get_global_rect()))
        for control in surface.find_children("*","Control",true,false):
            if control is BaseButton and control.is_visible_in_tree():
                check(app.get_global_rect().grow(2).encloses(control.get_global_rect()),"settings button inside viewport: "+str(control.name))
        await shot("hand-stack-settings-%d" % cfg.x)
        app.handle_ui("local_panel",""); await settle()
    check(app.session.snapshot()==before,"GPU display and preference switching preserve rules/RNG")
    app.queue_free(); await process_frame
    print("HAND STACK GPU: "+("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
