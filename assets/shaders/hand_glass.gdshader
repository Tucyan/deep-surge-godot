shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 3.0;
uniform vec4 tint : source_color = vec4(0.035,0.085,0.105,0.64);
void fragment() {
 vec3 blurred = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
 float grain = fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453)-0.5;
 COLOR = vec4(mix(blurred,tint.rgb,tint.a)+grain*0.012,0.96);
}
