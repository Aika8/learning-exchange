// Floating-island terrain: world triplanar PBR, grass on flat tops, rock on the sides.
shader_type spatial;
render_mode cull_back;

uniform sampler2D grass_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grass_scale = 0.35;
uniform float rock_scale = 0.12;
uniform vec3 grass_tint : source_color = vec3(1.0);
uniform vec3 rock_tint : source_color = vec3(1.0);

varying vec3 wpos;
varying vec3 wnor;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
}

void fragment() {
	vec3 w = pow(abs(wnor), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 gp = wpos * grass_scale;
	vec3 rp = wpos * rock_scale;
	float g = smoothstep(0.55, 0.8, wnor.y);
	vec3 ga = texture(grass_diff, gp.xz).rgb * grass_tint;
	vec3 garm = texture(grass_arm, gp.xz).rgb;
	vec3 gn = texture(grass_nor, gp.xz).rgb;
	vec3 ra = tri(rock_diff, rp, w).rgb * rock_tint;
	vec3 rarm = tri(rock_arm, rp, w).rgb;
	vec3 rn = tri(rock_nor, rp, w).rgb;
	ALBEDO = mix(ra, ga, g);
	vec3 arm = mix(rarm, garm, g);
	AO = arm.r;
	ROUGHNESS = arm.g;
	METALLIC = 0.0;
	NORMAL_MAP = mix(rn, gn, g);
	NORMAL_MAP_DEPTH = 1.0;
}
