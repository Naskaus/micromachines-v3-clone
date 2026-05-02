shader_type spatial;

uniform float tile_size : hint_range(0.5, 5.0) = 2.0;
uniform vec3 color_a : source_color = vec3(0.18, 0.42, 0.18);
uniform vec3 color_b : source_color = vec3(0.30, 0.55, 0.30);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grid = floor(world_pos.xz / tile_size);
	float checker = mod(grid.x + grid.y, 2.0);
	ALBEDO = mix(color_a, color_b, checker);
	ROUGHNESS = 0.9;
}
