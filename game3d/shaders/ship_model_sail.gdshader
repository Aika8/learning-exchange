// The sails of the pinnace model (ADR-0036, amended): their own texture and cut-out shape, physically lit, with a
// light ripple along the cloth's normal. Drawn in the transparent pass, opaque and writing depth, so no island's
// technique redraws them. The model: Poly Haven `ship_pinnace`, CC0. This shader: own work, CC0.
shader_type spatial;
render_mode cull_disabled, depth_draw_always, blend_mix;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform float ripple = 0.1;  // metres of the model, before it is scaled down

void vertex() {
	float wave = sin(TIME * 1.6 + VERTEX.y * 0.55 + VERTEX.x * 0.35) * 0.6 + sin(TIME * 2.3 + VERTEX.y * 1.3) * 0.4;
	VERTEX += NORMAL * wave * ripple;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
	vec3 orm = texture(orm_tex, UV).rgb;
	ROUGHNESS = max(orm.g, 0.6);
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	BACKLIGHT = vec3(0.3, 0.28, 0.22);
	ALPHA = 1.0;
}
