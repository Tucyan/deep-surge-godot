extends SceneTree
## Preview-only decorations. No production page loads this script.
var failures := 0
func _init():
    call_deferred("run"); call_deferred("watchdog")
func watchdog():
    await create_timer(30).timeout
    printerr("STACK EXPERIMENT: timeout"); quit(2)
func check(ok: bool, text: String):
    if not ok: failures+=1; printerr("FAIL: "+text)
func settle():
    for i in range(5): await process_frame
func add_seam(frame: Control, before: Control, depth: int, angle: float):
    var seam=Panel.new(); seam.name="ExperimentalSeam%d" % depth
    seam.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var style=StyleBoxFlat.new(); style.bg_color=Color.TRANSPARENT
    style.border_color=Color(.02,.035,.05,.28); style.set_border_width_all(1)
    style.set_corner_radius_all(6)
    style.shadow_color=Color(.01,.02,.03,.25); style.shadow_size=2; style.shadow_offset=Vector2(1,1)
    seam.add_theme_stylebox_override("panel",style)
    frame.add_child(seam); frame.move_child(seam,before.get_index())
    seam.anchor_left=.08; seam.anchor_top=.04; seam.anchor_right=.92; seam.anchor_bottom=.96
    seam.offset_left=depth*7; seam.offset_right=depth*7
    seam.offset_top=-depth; seam.offset_bottom=-depth
    # The pivot remains the original card center after applying the inset.
    seam.pivot_offset=frame.size*.5-Vector2(frame.size.x*.08+depth*7,frame.size.y*.04-depth)
    seam.rotation_degrees=angle
func add_stack_layers(fan: Control, fanned: bool):
    for i in range(fan.tiles.size()):
        var card: Dictionary=fan.cards[i]
        if int(card.get("stack_count",1))<=1 or card.definition.kind!="resource": continue
        var frame=fan.tiles[i].get_child(0)
        var front: TextureRect=null
        for child in frame.get_children():
            if child is TextureRect: front=child; break
        for depth in [2,1]:
            var rear=TextureRect.new(); rear.name="ExperimentalRearCard%d" % depth
            rear.texture=front.texture; rear.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
            rear.stretch_mode=TextureRect.STRETCH_SCALE; rear.mouse_filter=Control.MOUSE_FILTER_IGNORE
            rear.modulate=Color(.84,.88,.92) if depth==2 else Color(.94,.96,.98)
            frame.add_child(rear); frame.move_child(rear,front.get_index())
            rear.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            rear.offset_left=depth*7; rear.offset_right=depth*7
            rear.offset_top=-depth; rear.offset_bottom=-depth
            if fanned:
                rear.pivot_offset=frame.size*.5
                rear.rotation_degrees=-2.3 if depth==1 else 2.3
            add_seam(frame,rear,depth,rear.rotation_degrees)
        add_seam(frame,front,0,0)
        check(frame.find_children("ExperimentalRearCard*","TextureRect",false,false).size()==2,"only two visual rear layers")
func run():
    root.size=Vector2i(1600,760)
    root.content_scale_size=Vector2i(1600,760)
    root.content_scale_factor=1.0
    var host=Control.new(); root.add_child(host); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    host.theme=preload("res://presentation/widgets.gd").theme()
    var bg=ColorRect.new(); bg.color=Color("102b3a"); host.add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var catalog=preload("res://content/catalog.gd").new(); catalog.load_catalog()
    var session=preload("res://core/game_session.gd").new(catalog)
    session.dispatch("new",{"mode":"challenge","origin":"strong","seed":22})
    var original=session.snapshot()
    var entries=[]
    for pair in [["wood",8],["iron",4],["rope",6],["plastic",5],["cloth",4],["water",1]]:
        for j in range(pair[1]):
            entries.append({"uid":"visual-%s-%d" % [pair[0],j],"id":pair[0],"definition":catalog.entry("cards",pair[0]),"temporary":false})
    var fans=[]
    for index in range(2):
        var label=Label.new(); label.text="方案 A · 整齐错层" if index==0 else "方案 B · 轻微扇开"
        label.position=Vector2(36,16+index*370); label.add_theme_font_size_override("font_size",22); host.add_child(label)
        var fan=preload("res://presentation/hand_fan.gd").new(); host.add_child(fan)
        fan.position=Vector2(36,60+index*370); fan.size=Vector2(1528,300)
        var view=session.view(); view.hand_layout=preload("res://presentation/hand_layout.gd").new()
        fan.create(preload("res://presentation/asset_catalog.gd").new(),entries,view)
        fan.mouse_filter=Control.MOUSE_FILTER_IGNORE; fans.append(fan)
    await settle()
    for i in range(2):
        fans[i].focus_card(-1); fans[i].arrange()
        # Reserve enough space between groups for the exposed rear edges.
        var step=fans[i].card_width+30.0
        var start=(fans[i].size.x-(fans[i].card_width+step*(fans[i].tiles.size()-1)))*.5
        for j in range(fans[i].tiles.size()):
            var x=start+j*step
            fans[i].base_x[j]=x; fans[i].target_positions[j].x=x; fans[i].tiles[j].position.x=x
        add_stack_layers(fans[i],i==1)
        check(absf(fans[i].card_height/fans[i].size.y-.97)<.001,"97 percent card height")
    await settle(); await RenderingServer.frame_post_draw
    check(session.snapshot()==original,"visual duplicates do not enter rules or RNG")
    check(root.get_texture().get_image().save_png("res://evidence/card-stack-experiment-larger-quantity.png")==OK,"save experiment preview")
    print("STACK EXPERIMENT: "+("PASS" if failures==0 else "FAIL"))
    host.queue_free(); await process_frame; quit(0 if failures==0 else 1)
