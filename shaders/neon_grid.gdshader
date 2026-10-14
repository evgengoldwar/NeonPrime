shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 line_color : source_color = vec4(1.0, 0.1, 0.85, 1.0);
uniform float grid_size = 1.2;
uniform float scroll_speed = 0.8;
uniform float energy = 2.2;
uniform float fade_distance = 26.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / grid_size;
	uv.y -= TIME * scroll_speed;
	vec2 g = abs(fract(uv - 0.5) - 0.5) / (fwidth(uv) * 1.4);
	float line = 1.0 - min(min(g.x, g.y), 1.0);
	float fade = clamp(1.0 - length(world_pos.xz) / fade_distance, 0.0, 1.0);
	fade *= fade;
	ALBEDO = line_color.rgb * energy * line * fade;
	ALPHA = line * fade;
}
