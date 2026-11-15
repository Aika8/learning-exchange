// Sail canvas that billows in the wind (vertex wave), two-sided. Own work, CC0.
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform vec3 color : source_color = vec3(0.953, 0.914, 0.824);
uniform vec3 stripe : source_color = vec3(0.851, 0.643, 0.255);
uniform float billow = 0.6;

void vertex() {
	float u = UV.x * 3.14159;
	float v = UV.y * 3.14159;
	VERTEX.z += sin(u) * sin(v) * billow * (0.85 + 0.15 * sin(TIME * 2.3 + UV.y * 4.0));
}

void fragment() {
	float s = step(0.42, UV.x) * step(UV.x, 0.58);
	ALBEDO = mix(color, stripe, s);
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.5, 0.45, 0.35);
}
