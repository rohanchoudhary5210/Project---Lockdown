shader_type canvas_item;

// Screen-space damage vignette + low-HP desaturation effect
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.85, 0.08, 0.08, 1.0);
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 screen_col = texture(screen_texture, SCREEN_UV);
	
	// Distance from screen center (0.0 at center, ~1.0 at corners)
	vec2 uv_offset = UV - vec2(0.5);
	float dist = length(uv_offset) * 1.4142;
	
	// Vignette falloff
	float edge = smoothstep(0.35, 1.0, dist);
	
	// Desaturation below 30 HP
	float luma = dot(screen_col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(screen_col.rgb, vec3(luma), desaturation);
	
	// Combine damage pulse + low-HP pulse
	float red_alpha = edge * clamp(vignette_intensity + pulse_intensity * 0.4, 0.0, 1.0);
	vec3 final_color = mix(desat, vignette_color.rgb, red_alpha * 0.85);
	
	COLOR = vec4(final_color, 1.0);
}
