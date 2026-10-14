shader_type spatial;
uniform vec4 wood_color : source_color = vec4(0.35, 0.24, 0.14, 1.0);
uniform float wet_line = 0.06;
uniform float water_height = 0.0;
uniform vec2 water_slope = vec2(0.0);
uniform float grain_strength : hint_range(0.0, 1.0) = 0.40;
uniform float knot_strength : hint_range(0.0, 1.0) = 0.30;
varying float world_height;
varying vec3 timber_pos;
float wood_hash(float n) { return fract(sin(n * 127.1 + 31.7) * 43758.5453); }
void vertex() {
	vec3 world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_height = world.y-water_height-dot(water_slope,world.xz);
	// Object space keeps grain attached while the raft pitches and moves.
	timber_pos = VERTEX;
}
void fragment() {
	float board = floor((timber_pos.x + 0.1625) / 0.325);
	float seed = wood_hash(board + wood_color.r * 91.0);
	vec2 p = timber_pos.xz;
	float knot_z = (wood_hash(board + 8.0) - 0.5) * 1.25;
	vec2 knot = vec2((p.x - board * 0.325 - (seed-.5)*.14)*21.0, (p.y-knot_z)*5.0);
	float radius = length(knot);
	float knot_mask = (1.0-smoothstep(.6,2.2,radius))*step(.32,seed);
	float bend = .038*sin(p.y*3.7+seed*17.0)+.014*sin(p.y*9.0+seed*9.0);
	bend += .048*sin(knot.x*1.7)*exp(-radius*radius*.55)*step(.32,seed);
	float phase = (p.x + bend) * 220.0 + seed * 41.0;
	// Derivative filtering suppresses thin-line shimmer at the gameplay camera distance.
	float aa = 1.0-smoothstep(.7,2.8,fwidth(phase));
	float fibre = pow(.5+.5*sin(phase + .35*sin(phase*.47)),8.0)*aa;
	float broad = sin((p.x+bend)*57.0+seed*19.0)*.055;
	float rings = (.5+.5*sin(radius*16.0))*knot_mask;
	float knots = knot_mask*.25 + rings*.26 + (1.0-smoothstep(.05,.30,radius))*.32*step(.32,seed);
	float end_zone = smoothstep(.62,.96,abs(p.y));
	float split_dist = abs(p.x-board*.325-(seed-.5)*.19-.008*sin(p.y*18.0));
	float split_aa = max(fwidth(p.x),.001);
	float split = (1.0-smoothstep(.001,.002+split_aa,split_dist))*end_zone;
	float grain = 1.0 + broad - grain_strength*(fibre*.48+split*.58) - knots*knot_strength;
	float wetness = 1.0 - smoothstep(wet_line - 0.04, wet_line + 0.025, world_height);
	ALBEDO = wood_color.rgb * grain * mix(1.0, 0.47, wetness);
	ROUGHNESS = mix(clamp(.78 + fibre*.10 - broad, .66, .93), 0.35, wetness);
}
