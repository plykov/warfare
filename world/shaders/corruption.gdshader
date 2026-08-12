shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// M18a — the shared corruption-mask shader the original Phase-1 scope doc
// (S7) called for ("one texture, one uniform, every material reads it") but
// that never actually got built — the ground previously read per-tile
// StandardMaterial3D.albedo_color writes from a CPU loop in main.gd every
// time the corruption field changed. CorruptionDirector now publishes its
// cell grid into corruption_mask once per tick; every ground tile that uses
// this shader reads it directly on the GPU, so growing the grid or adding
// more tiles no longer costs any extra per-object CPU work.
//
// Math mirrors CorruptionDirector.cell_to_world()/world_to_cell() in
// autoload/corruption_director.gd — keep the two in sync if either changes.

global uniform sampler2D corruption_mask : source_color, filter_linear, repeat_disable;
global uniform vec3 corruption_world_origin;
global uniform vec2 corruption_world_size;
global uniform vec3 corruption_pure_color : source_color;
global uniform bool corruption_high_contrast;
global uniform bool corruption_colorblind_safe;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = vec2(
		(world_position.x - corruption_world_origin.x) / corruption_world_size.x + 0.5,
		(world_position.z - corruption_world_origin.z) / corruption_world_size.y + 0.5
	);
	float corruption = texture(corruption_mask, uv).r;

	vec3 corrupt_color = corruption_high_contrast ? vec3(0.42, 0.0, 0.52) : vec3(0.006, 0.002, 0.009);
	vec3 pure_color = corruption_pure_color;
	vec3 holy_glow = vec3(0.035, 0.13, 0.028);
	if (corruption_colorblind_safe) {
		// Okabe-Ito color-universal blue/orange, converted from sRGB to linear.
		// This explicit accessibility choice takes priority if both toggles are on.
		corrupt_color = vec3(0.791298, 0.346704, 0.0);
		pure_color = vec3(0.0, 0.168269, 0.445201);
		holy_glow = pure_color * 0.56;
	}

	ALBEDO = mix(pure_color, corrupt_color, smoothstep(0.18, 0.82, corruption));
	EMISSION = holy_glow * max(0.0, 0.48 - corruption) * 1.8;
	ROUGHNESS = 0.88;
}
