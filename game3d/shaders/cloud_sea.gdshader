// Cloud sea: a big subdivided plane lifted by two scrolling noises; faceted normals keep the low-poly look.
// Style: docs/design/game3d-style.md. Own work, CC0 like the rest of game3d/.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_b : repeat_enable, filter_linear_mipmap;
uniform float height = 9.0;
uniform vec3 top_color : source_color = vec3(0.96, 0.925, 0.894);
uniform vec3 low_color : source_color = vec3(0.663, 0.706, 0.812);
uniform vec3 warm_color : source_color = vec3(1.0, 0.82, 0.62);

varying float h;
varying vec3 world_pos;

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float a = texture(noise_a, wp * 0.0035 + TIME * vec2(0.0035, 0.0015)).r;
	float b = texture(noise_b, wp * 0.011 - TIME * vec2(0.005, 0.002)).r;
	h = clamp(a * 0.72 + b * 0.38 - 0.05, 0.0, 1.0);
	VERTEX.y += h * h * height;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	vec3 base = mix(low_color, top_color, smoothstep(0.15, 0.75, h));
	base = mix(base, warm_color, smoothstep(0.7, 1.0, h) * 0.25);
	ALBEDO = base;
	ROUGHNESS = 1.0;
	RIM = 0.6;
	RIM_TINT = 0.6;
	BACKLIGHT = vec3(0.35, 0.3, 0.28);
}
