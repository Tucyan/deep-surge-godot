shader_type canvas_item;
// Trim the white extraction fringe in source texels, preserving interior art.
uniform float trim_texels : hint_range(0.0, 5.0) = 2.5;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
    vec4 source = texture(TEXTURE, UV);
    vec2 d = TEXTURE_PIXEL_SIZE * trim_texels;
    float coverage = source.a;
    coverage = min(coverage, texture(TEXTURE, UV + vec2(d.x, 0.0)).a);
    coverage = min(coverage, texture(TEXTURE, UV - vec2(d.x, 0.0)).a);
    coverage = min(coverage, texture(TEXTURE, UV + vec2(0.0, d.y)).a);
    coverage = min(coverage, texture(TEXTURE, UV - vec2(0.0, d.y)).a);
    coverage = min(coverage, texture(TEXTURE, UV + d * 0.7071).a);
    coverage = min(coverage, texture(TEXTURE, UV - d * 0.7071).a);
    coverage = min(coverage, texture(TEXTURE, UV + vec2(d.x, -d.y) * 0.7071).a);
    coverage = min(coverage, texture(TEXTURE, UV + vec2(-d.x, d.y) * 0.7071).a);
    COLOR = vec4(source.rgb, smoothstep(0.15, 0.85, coverage)) * tint;
}
