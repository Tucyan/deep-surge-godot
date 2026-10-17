extends Control
## Decorative rear cards are siblings of the interactive front: hover never lifts them.
const OFFSET := 7.0
var layer_count := 2
var offset_direction := -1
var artwork: Texture2D
func setup(texture: Texture2D, count: int):
    artwork=texture; layer_count=mini(2,maxi(0,count-1))
    mouse_filter=MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)
    queue_redraw()
func hit_rect() -> Rect2:
    return Rect2(position+Vector2(offset_direction*OFFSET*layer_count*scale.x,-layer_count*scale.y),size*scale+Vector2(OFFSET*layer_count*scale.x,layer_count*scale.y))
func _draw():
    if artwork==null: return
    var width=size.y*(1024.0/1536.0)
    var frame=Rect2(Vector2((size.x-width)*.5,0),Vector2(width,size.y))
    for depth in range(layer_count,0,-1):
        var r=Rect2(frame.position+Vector2(offset_direction*OFFSET*depth,-depth),frame.size)
        var seam=StyleBoxFlat.new(); seam.bg_color=Color.TRANSPARENT
        seam.border_color=Color(.02,.035,.05,.28); seam.set_border_width_all(1); seam.set_corner_radius_all(6)
        seam.shadow_color=Color(.01,.02,.03,.25); seam.shadow_size=2; seam.shadow_offset=Vector2(-1,1)
        draw_style_box(seam,Rect2(r.position+r.size*Vector2(.08,.04),r.size*Vector2(.84,.92)))
        draw_texture_rect(artwork,r,false,Color(.84,.88,.92) if depth==2 else Color(.94,.96,.98))
