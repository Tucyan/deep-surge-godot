shader_type spatial;
// R flow, G pores/grain, BA micro slopes. Two samples, no extra draw layer.
uniform sampler2D detail_texture : repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_noise_texture : repeat_enable, filter_linear_mipmap;
uniform bool detail_enabled = true;
uniform bool lantern_enabled = true;
uniform float detail_scale = 0.22;
uniform float detail_flow_strength = 0.42;
uniform float detail_water_contrast = 0.12;
uniform float detail_pore_strength = 0.88;
uniform float detail_thread_strength = 0.35;
uniform float detail_normal_strength = 0.08;
uniform float detail_distortion = 0.08;
uniform vec2 detail_fade_distance = vec2(12.0,36.0);
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
// Stylized night ocean. Gerstner math must stay identical to presentation/toon_ocean.gd.

const int WAVES = 4;
const int MAX_CELLS = 48;

uniform vec4 wave_dk[4];
uniform vec4 wave_aq[4];
uniform float amplitude_sum = 0.5;
uniform float visual_time = 0.0;
uniform bool wave_noise_enabled = true;
uniform float wave_noise_seed = 73.0;
uniform float wave_noise_scale = 0.18;
uniform vec2 wave_noise_drift = vec2(0.027,-0.019);
uniform float wave_noise_phase_strength = 1.25;
uniform float wave_noise_amplitude_strength = 0.24;
uniform vec2 ocean_center = vec2(0.0);
uniform vec2 amplitude_fade = vec2(20.0, 30.0);
uniform bool far_mode = false;
uniform float near_half = 32.0;

uniform vec4 raft_bounds = vec4(0.0, 0.0, 2.35, 2.1);
uniform float contact_margin = 1.2;
uniform float contact_transition = 2.4;
uniform float plane_height = 0.0;
uniform vec2 plane_slope = vec2(0.0);
uniform vec2 cell_centers[48];
uniform int cell_count = 0;
uniform vec2 cell_half = vec2(1.175, 1.05);

uniform vec3 trough_color : source_color = vec3(0.012, 0.027, 0.059);
uniform vec3 deep_color : source_color = vec3(0.027, 0.075, 0.157);
uniform vec3 body_color : source_color = vec3(0.047, 0.122, 0.239);
uniform vec3 lit_color : source_color = vec3(0.086, 0.192, 0.353);
uniform vec3 rim_color : source_color = vec3(0.157, 0.286, 0.478);
uniform vec3 sky_reflect_color : source_color = vec3(0.075, 0.165, 0.298);
uniform vec3 foam_color : source_color = vec3(0.498, 0.592, 0.722);
uniform vec3 foam_core_color : source_color = vec3(0.706, 0.776, 0.871);
uniform vec3 glint_color : source_color = vec3(0.824, 0.878, 0.957);
uniform vec3 lantern_color : source_color = vec3(0.788, 0.541, 0.275);

uniform vec3 key_direction = vec3(-0.35, 0.62, -0.70);
uniform float light_weight = 0.62;
uniform float height_weight = 0.38;
uniform vec4 band_thresholds = vec4(0.30, 0.52, 0.70, 0.86);
uniform float fresnel_power = 4.0;
uniform float fresnel_strength = 0.45;

uniform float fold_gain = 1.25;
uniform float height_gain = 0.30;
uniform float noise_scale = 0.55;
uniform float erosion = 0.42;
uniform float foam_threshold = 0.36;
uniform float core_threshold = 0.52;
uniform vec2 foam_drift = vec2(0.035, 0.05);
uniform float streak_scale = 0.42;
uniform float streak_width = 0.07;
uniform float streak_strength = 0.55;
uniform vec2 foam_fade_distance = vec2(26.0, 55.0);
uniform float contact_width = 1.35;
uniform float contact_frequency = 1.6;
uniform float contact_speed = 0.32;

uniform vec3 moon_direction = vec3(-0.10, 0.28, -0.95);
uniform float glint_threshold = 0.9965;
uniform float glint_noise = 0.004;
uniform float sheen_power = 70.0;
uniform float sheen_strength = 0.22;

uniform vec3 lantern_position = vec3(-1.2, 1.5, 0.7);
uniform float lantern_radius = 4.2;
uniform float lantern_strength = 0.55;

// Same depth fog as the Environment, applied here so unshaded water fogs identically.
uniform vec3 fog_color : source_color = vec3(0.039, 0.082, 0.157);
uniform vec3 fog_depth = vec3(16.0, 72.0, 1.4);
uniform float streak_crest = 0.25;
uniform float contact_threshold = 0.8;
uniform float contact_strength = 0.7;
uniform float contact_noise = 0.6;
uniform float crest_sharpness = 8.0;
uniform float crest_gain = 1.0;
uniform float lantern_glint_threshold = 0.985;

varying vec3 world_pos;
varying vec2 grid_pos;
varying float contact_b;
varying float wave_fade;

float fade_at(vec2 g) {
	vec2 d = abs(g - ocean_center);
	return 1.0 - smoothstep(amplitude_fade.x, amplitude_fade.y, max(d.x, d.y));
}

float contact_at(vec2 g) {
	vec2 q = max(abs(g - raft_bounds.xy) - raft_bounds.zw, vec2(0.0));
	return 1.0 - smoothstep(contact_margin, contact_margin + contact_transition, length(q));
}

float wave_noise_hash(vec2 p) {
	float r = mod(dot(p,vec2(37.0,73.0))+wave_noise_seed,251.0);
	return mod(r*r*17.0+r*13.0,251.0)/251.0;
}

// Value and spatial gradient: deterministic, continuously drifting lattice noise.
vec3 wave_noise_sample(vec2 g, int index) {
	if (!wave_noise_enabled) return vec3(0.0);
	vec2 p=g*wave_noise_scale+wave_noise_drift*visual_time+vec2(float(index)*19.0,float(index)*31.0);
	vec2 cell=floor(p); vec2 f=fract(p);
	vec2 u=f*f*(3.0-2.0*f); vec2 du=6.0*f*(1.0-f);
	float a=wave_noise_hash(cell); float b=wave_noise_hash(cell+vec2(1.0,0.0));
	float c=wave_noise_hash(cell+vec2(0.0,1.0)); float d=wave_noise_hash(cell+vec2(1.0,1.0));
	float value=mix(mix(a,b,u.x),mix(c,d,u.x),u.y);
	vec2 gradient=vec2(mix(b-a,d-c,u.y)*du.x,mix(c-a,d-b,u.x)*du.y)*wave_noise_scale;
	return vec3(value*2.0-1.0,gradient*2.0);
}

vec3 gerstner(vec2 g) {
	vec3 d = vec3(0.0);
	for (int i = 0; i < WAVES; i++) {
		vec2 dir = wave_dk[i].xy;
		float k = wave_dk[i].z;
		float noise=wave_noise_sample(g,i).x;
		float amplitude=1.0+wave_noise_amplitude_strength*noise;
		float theta = k * dot(dir, g) - wave_dk[i].w * visual_time + wave_aq[i].z+wave_noise_phase_strength*noise;
		d.xz += dir * (wave_aq[i].y / k) * cos(theta)*amplitude;
		d.y += wave_aq[i].x * sin(theta)*amplitude;
	}
	return d;
}

// Analytic normal, Jacobian of the horizontal mapping and height at grid point g.
// crest: sharpened per-wave crest lines; the steepest wave alone reaches 1, so foam follows ridges.
void wave_frame(vec2 g, float f, out vec3 n, out float jac, out float h, out float crest) {
	// Zero amplitude has an exact flat frame, including the entire far ocean.
	// Skip four noise gradients and trigonometric sums whose weights are zero.
	if (f == 0.0) {
		n = vec3(0.0, 1.0, 0.0); jac = 1.0; h = 0.0; crest = 0.0;
		return;
	}
	float nx = 0.0; float nz = 0.0;
	float jxx = 0.0; float jzz = 0.0; float jxz = 0.0; float jzx = 0.0;
	float weight = 0.0;
	h = 0.0; crest = 0.0;
	for (int i = 0; i < WAVES; i++) {
		vec2 dir = wave_dk[i].xy;
		float k = wave_dk[i].z;
		float a = wave_aq[i].x;
		float s = wave_aq[i].y;
		vec3 noise=wave_noise_sample(g,i);
		float amplitude=1.0+wave_noise_amplitude_strength*noise.x;
		vec2 amplitude_gradient=wave_noise_amplitude_strength*noise.yz;
		vec2 phase_gradient=k*dir+wave_noise_phase_strength*noise.yz;
		float theta = k * dot(dir, g) - wave_dk[i].w * visual_time + wave_aq[i].z+wave_noise_phase_strength*noise.x;
		float st = sin(theta);
		float ct = cos(theta);
		vec2 height_gradient=a*(amplitude_gradient*st+amplitude*ct*phase_gradient);
		nx += height_gradient.x; nz += height_gradient.y;
		vec2 fold=(s/k)*(amplitude*st*phase_gradient-amplitude_gradient*ct);
		jxx += dir.x*fold.x; jxz += dir.x*fold.y;
		jzx += dir.y*fold.x; jzz += dir.y*fold.y;
		h += a * st*amplitude;
		crest += s * amplitude*pow(max(st, 0.0), crest_sharpness);
		weight = max(weight, s);
	}
	crest = crest / max(weight, 0.0001) * f;
	vec3 tangent_x=vec3(1.0-jxx*f,nx*f,-jzx*f);
	vec3 tangent_z=vec3(-jxz*f,nz*f,1.0-jzz*f);
	n=normalize(cross(tangent_z,tangent_x));
	jac = (1.0 - jxx * f) * (1.0 - jzz * f) - (jxz * f) * (jzx * f);
	h *= f;
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float aa_step(float edge, float x) {
	float w = fwidth(x) * 0.75 + 0.0001;
	return smoothstep(edge - w, edge + w, x);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	grid_pos = w.xz;
	wave_fade = far_mode ? 0.0 : fade_at(w.xz);
	contact_b = 0.0;
	if (!far_mode) {
		vec3 d = gerstner(w.xz) * wave_fade;
		float b = contact_at(w.xz);
		contact_b = b;
		vec2 xz = w.xz + d.xz * (1.0 - b);
		w = vec3(xz.x, mix(d.y, plane_height + dot(plane_slope, xz), b), xz.y);
	}
	world_pos = w;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}

void fragment() {
	if (far_mode) {
		vec2 c = abs(world_pos.xz - ocean_center);
		if (max(c.x, c.y) < near_half - 0.5) discard;
	}
	vec2 g = grid_pos;
	float b = contact_b;
	vec3 n; float jac; float h; float ridge;
	wave_frame(g, wave_fade, n, jac, h, ridge);
	ridge *= 1.0 - b;
	vec3 flat_n = normalize(vec3(-plane_slope.x, 1.0, -plane_slope.y));
	n = normalize(mix(n, flat_n, b));
	jac = mix(jac, 1.0, b);
	float hn = clamp(mix(h, 0.0, b) / amplitude_sum, -1.0, 1.0);

	vec3 to_camera = CAMERA_POSITION_WORLD - world_pos;
	float dist = length(to_camera);
	vec3 v = to_camera / dist;
	float detail_fade = detail_enabled ? 1.0-smoothstep(detail_fade_distance.x,detail_fade_distance.y,dist) : 0.0;
	vec2 flow_axis = normalize(wave_dk[0].xy);
	vec2 flow_side = vec2(-flow_axis.y,flow_axis.x);
	vec2 detail_uv = vec2(dot(g,flow_axis),dot(g,flow_side))*detail_scale;
	vec2 wave_slope_local = vec2(dot(n.xz,flow_axis),dot(n.xz,flow_side));
	detail_uv += wave_slope_local * (detail_distortion * detail_fade);
	vec4 detail_a = vec4(0.0,0.5,0.5,0.5);
	vec4 detail_b = detail_a;
	if (detail_fade > 0.0) {
		detail_a = texture(detail_texture,detail_uv+vec2(-visual_time*0.014,visual_time*0.003));
		detail_b = texture(detail_texture,detail_uv*4.2+vec2(0.173,0.287)+vec2(-visual_time*0.011,-visual_time*0.009));
	}
	vec2 micro_slope = ((detail_a.ba*2.0-1.0)*0.4+(detail_b.ba*2.0-1.0)*0.6)*detail_normal_strength*detail_fade;
	vec2 micro_xz = flow_axis*micro_slope.x+flow_side*micro_slope.y;
	vec3 detail_n = normalize(n+vec3(micro_xz.x,0.0,micro_xz.y));

	// Banded body colour from key light and wave height.
	float ndl = dot(n, normalize(key_direction)) * 0.5 + 0.5;
	float value = ndl * light_weight + (hn * 0.5 + 0.5) * height_weight;
	vec3 col = trough_color;
	col = mix(col, deep_color, aa_step(band_thresholds.x, value));
	col = mix(col, body_color, aa_step(band_thresholds.y, value));
	col = mix(col, lit_color, aa_step(band_thresholds.z, value));
	col = mix(col, rim_color, aa_step(band_thresholds.w, value));
	float fresnel = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), fresnel_power) * fresnel_strength;
	col = mix(col, sky_reflect_color, fresnel);
	float grain = (detail_a.g+detail_b.g)*0.5-0.5;
	col *= 1.0+grain*detail_water_contrast*detail_fade;
	float flow_lines = detail_a.r*0.7+detail_b.r*0.3;
	col = mix(col,mix(col,rim_color,0.4),flow_lines*detail_flow_strength*detail_fade);

	// Lantern: faint warm pool plus warm glints on facets that reflect the lamp.
	float lantern = lantern_enabled ? 1.0 - smoothstep(0.0, lantern_radius, length(world_pos.xz - lantern_position.xz)) : 0.0;
	col = mix(col, col + lantern_color * 0.12, aa_step(0.5, lantern) * lantern_strength);
	vec3 lantern_half = normalize(normalize(lantern_position - world_pos) + v);
	float lantern_spec = max(dot(detail_n, lantern_half), 0.0);
	col = mix(col, lantern_color, aa_step(lantern_glint_threshold, lantern_spec + (hash21(floor(g * 9.0)) - 0.5) * 0.02) * lantern);

	// Moon path: quantized sheen plus broken hard glints.
	vec3 half_vector = normalize(normalize(moon_direction) + v);
	float spec = max(dot(detail_n, half_vector), 0.0);
	col = mix(col, rim_color * 1.35, pow(spec, sheen_power) * sheen_strength * 3.0);
	vec2 glint_uv = g * 0.31 + vec2(visual_time * 0.06);
	float sparkle_sample = texture(foam_noise_texture, glint_uv).a;
	float sparkle = spec + (sparkle_sample - 0.5) * glint_noise;
	col = mix(col, glint_color, aa_step(glint_threshold, sparkle));

	// Crest foam where the Gerstner surface folds, eroded by drifting noise texture.
	vec2 foam_uv = g * noise_scale + foam_drift * visual_time;
	vec4 foam_noise_sample = texture(foam_noise_texture, foam_uv);
	float noise = foam_noise_sample.g;
	float crest = ridge * crest_gain + (1.0 - jac) * fold_gain + max(hn, 0.0) * height_gain;
	float foam_value = crest - noise * erosion;
	float distance_fade = 1.0 - smoothstep(foam_fade_distance.x, foam_fade_distance.y, dist);
	float foam = aa_step(foam_threshold, foam_value) * distance_fade;
	float core = aa_step(core_threshold, foam_value) * distance_fade;
	vec2 streak_uv = g * streak_scale + wave_dk[0].xy * visual_time * 0.12 + vec2(noise * 0.8);
	float edge = texture(foam_noise_texture, streak_uv).r;
	float streak = (1.0 - aa_step(streak_width, edge)) * smoothstep(streak_crest, streak_crest + 0.25, crest) * streak_strength * distance_fade;
	// Pores affect open-water foam; the raft contact ring is composed afterwards.
	float pores = smoothstep(0.61,0.73,detail_b.g)*detail_pore_strength*detail_fade;
	foam *= 1.0-pores; core *= 1.0-pores;
	float threads = detail_b.r*detail_thread_strength*detail_fade*max(foam,core);

	// Contact rings follow the real cell footprint, with early-out bounding box pruning.
	float ring = 0.0;
	vec2 q_raft = max(abs(world_pos.xz - raft_bounds.xy) - raft_bounds.zw, vec2(0.0));
	if (length(q_raft) <= contact_width + 0.2 && cell_count > 0) {
		float sdf = 1000.0;
		for (int i = 0; i < MAX_CELLS; i++) {
			if (i >= cell_count) break;
			vec2 q = abs(world_pos.xz - cell_centers[i]) - cell_half;
		sdf = min(sdf, length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0));
		}
		float ring_mask = 1.0 - smoothstep(contact_width * 0.45, contact_width, sdf);
		float ring_wave = sin((sdf * contact_frequency - visual_time * contact_speed) * 6.2831853) * 0.5 + 0.5;
		vec2 ring_noise_uv = g * 0.23 - vec2(visual_time * 0.01);
		float ring_noise = texture(foam_noise_texture, ring_noise_uv).b;
		ring = aa_step(contact_threshold, ring_wave * ring_mask + (ring_noise - 0.5) * contact_noise) * ring_mask * contact_strength;
	}
	foam = max(foam, ring);

	col = mix(col, foam_color, max(streak, foam));
	col = mix(col, foam_core_color, max(core,threads));
	float fog = pow(clamp((dist - fog_depth.x) / (fog_depth.y - fog_depth.x), 0.0, 1.0), fog_depth.z);
	ALBEDO = mix(col, fog_color, fog);
}
