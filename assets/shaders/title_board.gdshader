shader_type canvas_item;
// Retain only the supplied grey board; white and reference artwork are not UI.
uniform vec4 board_color : source_color = vec4(0.160784, 0.184314, 0.227451, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.78;
void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float mask = 1.0 - smoothstep(0.012, 0.035, distance(source.rgb, board_color.rgb));
    COLOR = vec4(source.rgb, source.a * mask * opacity);
}
