// The canvas of «Попутчик» (ADR-0036): physically lit cloth that billows, with seams and old stains. It is drawn in
// the transparent pass, fully opaque and writing depth, so no island's technique redraws it. Own work, CC0.
shader_type spatial;
render_mode cull_disabled, depth_draw_always, blend_mix;

uniform vec3 color : source_color = vec3(0.86, 0.80, 0.68);
uniform float billow = 0.5;
uniform float wet = 0.0;  // 0 dry canvas, 1 the wet wing sails
uniform vec2 cloth_scale = vec2(1.0);  // UV units to one sail: built sails have UVs in metres

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	float u = UV.x * 3.14159;
	float v = UV.y * 3.14159;
	VERTEX.z -= sin(u) * sin(v) * billow * (0.88 + 0.12 * sin(TIME * 1.7 + UV.y * 4.0));
}

void fragment() {
	vec2 uv = UV * cloth_scale;
	float seams = smoothstep(0.035, 0.0, abs(fract(uv.x * 5.0) - 0.5) - 0.46);  // the cloths of the sail
	float stain = noise(uv * vec2(3.0, 5.0)) * 0.6 + noise(uv * 13.0) * 0.4;
	vec3 c = color * mix(0.78, 1.04, stain);
	c = mix(c, c * 0.72, seams * 0.6);
	c = mix(c, c * vec3(0.62, 0.66, 0.7), wet);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.45, wet);
	BACKLIGHT = vec3(0.35, 0.32, 0.26) * (1.0 - wet * 0.6);
	ALPHA = 1.0;
}
