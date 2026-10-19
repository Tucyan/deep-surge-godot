extends Control
## Presentation only: no progress percentage and no access to gameplay RNG.
var elapsed:=0.0
var stage: Label
var caption: Label

func _ready() -> void:
	name="LoadingTransition"
	z_index=4000
	mouse_filter=MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stage=Label.new(); stage.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stage.add_theme_font_size_override("font_size",25)
	stage.add_theme_color_override("font_color",Color("e5d5ad"))
	add_child(stage)
	caption=Label.new(); caption.text="D E E P   S U R G E"
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",13)
	caption.add_theme_color_override("font_color",Color("839b9e"))
	add_child(caption)
	resized.connect(_layout_text); _layout_text()

func _layout_text() -> void:
	stage.position=Vector2(0,size.y*.46+92); stage.size=Vector2(size.x,42)
	caption.position=Vector2(0,size.y*.46+137); caption.size=Vector2(size.x,24)

func set_stage(text: String) -> void:
	stage.text=text

func fade(alpha: float) -> void:
	var tween:=create_tween()
	tween.tween_property(self,"modulate:a",alpha,.16).set_trans(Tween.TRANS_SINE)
	await tween.finished

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	elapsed+=delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("081b25"))
	var center:=Vector2(size.x*.5,size.y*.46)
	var gold:=Color("c9b581")
	for layer in range(3):
		var points:=PackedVector2Array()
		for x in range(0,int(size.x)+17,16):
			var y:=size.y*.78+layer*18+sin(x*.009-elapsed*(.65+layer*.12))*12
			points.append(Vector2(x,y))
		draw_polyline(points,Color(.22,.44,.48,.2+layer*.12),1.5,true)
	draw_arc(center,60,0,TAU,96,Color(.5,.62,.62,.25),1,true)
	for i in range(24):
		var angle:=i*TAU/24
		var direction:=Vector2.from_angle(angle)
		draw_line(center+direction*65,center+direction*(72 if i%6==0 else 68),gold,1,true)
	draw_arc(center,80,elapsed*.9,elapsed*.9+PI*.65,40,Color(.8,.71,.5,.75),2,true)
	draw_arc(center,80,elapsed*.9+PI,elapsed*.9+PI*1.65,40,Color(.4,.65,.68,.5),2,true)
	var turn:=elapsed*.3
	for i in range(4):
		var angle:=turn+i*PI*.5-PI*.5
		var tip:=center+Vector2.from_angle(angle)*47
		var side:=Vector2.from_angle(angle+PI*.5)*9
		draw_colored_polygon(PackedVector2Array([tip,center+side,center]),gold if i%2==0 else Color("567d83"))
		draw_colored_polygon(PackedVector2Array([tip,center-side,center]),Color("223e49"))
	draw_circle(center,4,gold,true,-1,true)
