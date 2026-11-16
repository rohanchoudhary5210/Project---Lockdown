shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Procedural Wall Material with Grime Gradient
// Designed for Mobile renderer: triplanar procedural noise without UV coordinates or image files.

uniform vec4 base_color : source_color = vec4(0.35, 0.36, 0.38, 1.0);
uniform vec4 grime_color : source_color = vec4(0.10, 0.09, 0.08, 1.0);
uniform sampler2D noise_tex : hint_default_white, repeat_enable;
uniform float uv_scale : hint_range(0.05, 2.0) = 0.4;
uniform float grime_height : hint_range(0.2, 2.5) = 0.9;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.75;

varying vec3 world_pos;
varying vec3 world_norm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_norm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 blending = abs(world_norm);
	blending = normalize(max(blending, vec3(0.0001)));
	float b_sum = blending.x + blending.y + blending.z;
	blending /= b_sum;

	vec4 x_tex = texture(noise_tex, world_pos.zy * uv_scale);
	vec4 y_tex = texture(noise_tex, world_pos.xz * uv_scale);
	vec4 z_tex = texture(noise_tex, world_pos.xy * uv_scale);
	vec4 noise = x_tex * blending.x + y_tex * blending.y + z_tex * blending.z;

	// Darker grime toward floor (world_pos.y <= grime_height)
	float grime_factor = 1.0 - clamp(world_pos.y / max(grime_height, 0.01), 0.0, 1.0);
	grime_factor = pow(grime_factor, 1.4) * (0.4 + 0.6 * noise.r);

	vec3 col = mix(base_color.rgb * (0.85 + 0.3 * noise.rgb), grime_color.rgb, grime_factor * 0.75);
	ALBEDO = col;
	ROUGHNESS = clamp(roughness_base + (noise.g - 0.5) * 0.15, 0.0, 1.0);
	METALLIC = 0.0;
}
