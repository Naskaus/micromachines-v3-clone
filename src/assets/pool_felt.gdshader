shader_type spatial;

// Pool-table felt floor with painted oval racing line.
// White chalk lines marking the inner + outer edges of the racing band.

uniform vec3 felt_color : source_color = vec3(0.18, 0.42, 0.20);
uniform vec3 felt_dark : source_color = vec3(0.12, 0.30, 0.14);
uniform vec3 paint_color : source_color = vec3(0.95, 0.95, 0.92);

uniform float oval_a = 140.0;          // semi-major axis (X)
uniform float oval_b = 80.0;           // semi-minor axis (Z)
uniform float track_half_width = 6.0;  // total track is 12m wide
uniform float paint_thickness = 0.6;   // chalk line thickness in meters
uniform float weave_freq = 12.0;       // felt weave density

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Felt weave — fine warp/weft pattern
	float w1 = sin(world_pos.x * weave_freq) * sin(world_pos.z * weave_freq);
	float w2 = sin((world_pos.x + world_pos.z) * 4.0);
	float felt_mix = clamp(w1 * 0.35 + w2 * 0.10 + 0.5, 0.0, 1.0);
	vec3 base = mix(felt_dark, felt_color, felt_mix);

	// Approximate world-space distance to the ellipse curve
	float a2 = oval_a * oval_a;
	float b2 = oval_b * oval_b;
	float f = (world_pos.x * world_pos.x) / a2 + (world_pos.z * world_pos.z) / b2 - 1.0;
	float gx = 2.0 * world_pos.x / a2;
	float gz = 2.0 * world_pos.z / b2;
	float gmag = sqrt(gx * gx + gz * gz);
	float dist = abs(f) / max(gmag, 0.0001);

	// Two chalk lines: at +/- track_half_width from the centerline
	float paint = step(abs(dist - track_half_width), paint_thickness);

	vec3 final_col = mix(base, paint_color, paint);
	ALBEDO = final_col;
	ROUGHNESS = 0.92;
}
