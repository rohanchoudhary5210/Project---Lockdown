shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// Procedural Emissive Muzzle Flash Shader
// Generates a multi-pointed starburst with a hot incandescent core and fiery edges.

uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.8, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.4, 0.05, 1.0);
uniform float energy : hint_range(1.0, 10.0) = 4.5;
uniform int spike_count : hint_range(3, 8) = 5;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv) * 2.0;
	float angle = atan(uv.y, uv.x);
	
	// Procedural spikes
	float spikes = 0.5 + 0.5 * cos(angle * float(spike_count));
	spikes = pow(spikes, 2.5);
	
	float threshold = 0.15 + spikes * 0.45;
	float shape = 1.0 - smoothstep(threshold * 0.4, threshold + 0.2, r);
	float core = 1.0 - smoothstep(0.0, 0.25, r);
	
	vec3 col = mix(edge_color.rgb, core_color.rgb, core) * energy;
	ALBEDO = col;
	ALPHA = clamp(shape, 0.0, 1.0);
}
