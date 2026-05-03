shader_type spatial;

// Pool-table felt floor with painted FIGURE-8 racing line.
// Two tangent ovals — one centered at z=-oval_h, one at z=+oval_h.
// They touch at z=0 forming a lemniscate-like figure-8.

uniform vec3 felt_color : source_color = vec3(0.18, 0.42, 0.20);
uniform vec3 felt_dark : source_color = vec3(0.12, 0.30, 0.14);
uniform vec3 paint_color : source_color = vec3(0.95, 0.95, 0.92);

uniform float oval_a = 100.0;          // semi-major axis (X) of each loop
uniform float oval_b = 50.0;           // semi-minor axis (Z) of each loop
uniform float oval_h = 50.0;           // top oval at z=-oval_h, bottom at z=+oval_h (tangent at z=0 when h=b)

uniform float track_half_width = 6.0;
uniform float paint_thickness = 0.6;
uniform float weave_freq = 12.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float dist_to_ellipse(vec3 p, float cz, float a, float b) {
	float fx = p.x;
	float fz = p.z - cz;
	float a2 = a * a;
	float b2 = b * b;
	float f = (fx * fx) / a2 + (fz * fz) / b2 - 1.0;
	float gx = 2.0 * fx / a2;
	float gz = 2.0 * fz / b2;
	float gmag = sqrt(gx * gx + gz * gz);
	return abs(f) / max(gmag, 0.0001);
}

void fragment() {
	// Felt weave pattern
	float w1 = sin(world_pos.x * weave_freq) * sin(world_pos.z * weave_freq);
	float w2 = sin((world_pos.x + world_pos.z) * 4.0);
	float felt_mix = clamp(w1 * 0.35 + w2 * 0.10 + 0.5, 0.0, 1.0);
	vec3 base = mix(felt_dark, felt_color, felt_mix);

	// Distance to closest of the two ovals (figure-8)
	float d_top = dist_to_ellipse(world_pos, -oval_h, oval_a, oval_b);
	float d_bot = dist_to_ellipse(world_pos, +oval_h, oval_a, oval_b);
	float d = min(d_top, d_bot);

	// Two chalk lines: at +/- track_half_width from each oval centerline
	float paint = step(abs(d - track_half_width), paint_thickness);

	vec3 final_col = mix(base, paint_color, paint);
	ALBEDO = final_col;
	ROUGHNESS = 0.92;
}
